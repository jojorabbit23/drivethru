# Movement stress test: drives the real player controller around the shop.
#
#   godot --headless --path . --fixed-fps 60 --script res://tools/movement_test.gd
#
# Checks
#   coverage   every 10 cm floor cell: does the capsule fit, and is it reachable
#              from PlayerStart? Free-but-unreachable cells are "pockets".
#   doorways   walk + sprint through every doorway: centred, hugging each jamb,
#              and at +/-35 degrees, both directions.
#   routes     long tours visiting every room and working spot.
#   slides     slide diagonally along every wall / furniture run in every room.
#   fuzz       random run / sprint / jump bots looking for wedges and escapes.
# Flags
#   STUCK      no progress for 0.6 s while pushing toward a reachable target
#   HITCH      speed collapses mid-stride (catching on an edge or seam)
#   BUMP       player leaves the floor without jumping (seams, lips)
#   PERCH      player can stand on a prop; a problem above 0.55 m or with
#              under 0.15 m headroom (ceiling bonks, cheesy vantage points)
#   PINCH      gap slightly narrower than the player next to walkable floor —
#              where a capsule jams on corners instead of sliding off
#   ESCAPE     player ends up outside the building interior
# Writes docs/movement_map.png (top-down: grey = walkable, orange = pockets,
# red = stuck, amber = hitch, magenta = bump, teal = perch).
extends SceneTree

const MAP_PATH := "res://docs/movement_map.png"
const CELL := 0.1
const X0 := -5.8
const X1 := 5.8
const Z0 := -4.8
const Z1 := 4.8
const DT := 1.0 / 60.0
const RADIUS := 0.35

var player: CharacterBody3D
var space: PhysicsDirectSpaceState3D
var shape_q: PhysicsShapeQueryParameters3D
var thin_q: PhysicsShapeQueryParameters3D
var free_cells := {}      # Vector2i -> true when the capsule fits
var reach := {}           # Vector2i -> true when reachable from start
var events := []          # {type, pos: Vector3, what: String, extra}
var visited := {}         # fuzz coverage
var counts := {"doorway_runs": 0, "route_runs": 0, "slide_runs": 0, "fuzz_seconds": 0.0}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	for i in 30:
		await physics_frame
	space = player.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = 1.8
	shape_q = PhysicsShapeQueryParameters3D.new()
	shape_q.shape = cap
	shape_q.collision_mask = player.collision_mask
	shape_q.exclude = [player.get_rid()]
	var thin := CapsuleShape3D.new()
	thin.radius = 0.25
	thin.height = 1.6
	thin_q = PhysicsShapeQueryParameters3D.new()
	thin_q.shape = thin
	thin_q.collision_mask = player.collision_mask
	thin_q.exclude = [player.get_rid()]

	print("== coverage")
	coverage(main.get_node("ShopGreybox/Markers/PlayerStart").global_position)
	pinches()
	print("== doorways")
	await doorways()
	print("== routes")
	await routes()
	print("== wall slides")
	await slides()
	print("== slot probes")
	await probe_slots()
	print("== windows")
	await window_assault(main.get_node("ShopGreybox/Windows"))
	print("== fuzz")
	await fuzz(24, 60.0)
	release()
	write_map()
	summarise()

# ------------------------------------------------------------ utilities ----
func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi((p.x - X0) / CELL), roundi((p.z - Z0) / CELL))

func pos_of(c: Vector2i, y := 0.0) -> Vector3:
	return Vector3(X0 + c.x * CELL, y, Z0 + c.y * CELL)

func capsule_fits(p: Vector3) -> bool:
	shape_q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.92, 0))
	return space.intersect_shape(shape_q, 1).is_empty()

func coverage(start: Vector3) -> void:
	var nx := int((X1 - X0) / CELL)
	var nz := int((Z1 - Z0) / CELL)
	for ix in nx + 1:
		for iz in nz + 1:
			var c := Vector2i(ix, iz)
			if capsule_fits(pos_of(c)):
				free_cells[c] = true
	var s := cell_of(start)
	var queue := [s]
	reach[s] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if free_cells.has(n) and not reach.has(n):
				reach[n] = true
				queue.append(n)
	# Pockets: free cells the start can't reach (only a problem if the player
	# could ever arrive there, e.g. by jumping or being pushed).
	var pockets := {}
	for c in free_cells:
		if not reach.has(c):
			pockets[c] = true
	var groups := []
	var seen := {}
	for c in pockets:
		if seen.has(c):
			continue
		var g := [c]
		seen[c] = true
		var i := 0
		while i < g.size():
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = g[i] + d
				if pockets.has(n) and not seen.has(n):
					seen[n] = true
					g.append(n)
			i += 1
		groups.append(g)
	for g in groups:
		var mid: Vector2i = g[g.size() / 2]
		events.append({"type": "POCKET", "pos": pos_of(mid), "what": "%d cells (%.2f m2)" % [g.size(), g.size() * CELL * CELL], "cells": g})
	print("  free cells %d, reachable %d, pockets %d" % [free_cells.size(), reach.size(), groups.size()])

# Gaps slightly narrower than the player (0.45-0.72 m) next to walkable floor:
# the capsule can nose in and jam on corners instead of sliding off. Measured
# with horizontal rays at several heights across each candidate cell.
func gap_width(p: Vector3, axis: Vector3) -> float:
	var w := INF
	for h in [0.1, 0.45, 0.8, 1.2, 1.6]:
		var o := p + Vector3(0, h, 0)
		var total := 0.0
		for sgn in [1.0, -1.0]:
			var q := PhysicsRayQueryParameters3D.create(o, o + axis * sgn * 1.2, player.collision_mask, [player.get_rid()])
			var hit := space.intersect_ray(q)
			total += 1.2 if hit.is_empty() else o.distance_to(hit["position"])
		w = minf(w, total)
	return w

func inside_solid(p: Vector3) -> bool:
	for h in [0.3, 0.9, 1.5]:
		var q := PhysicsPointQueryParameters3D.new()
		q.position = p + Vector3(0, h, 0)
		q.collision_mask = player.collision_mask
		q.exclude = [player.get_rid()]
		if not space.intersect_point(q, 1).is_empty():
			return true
	return false

func pinches() -> void:
	var cells := {}
	for c in reach:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			for k in [1, 2, 3, 4, 5, 6]:
				var n: Vector2i = c + d * k
				if free_cells.has(n) or cells.has(n):
					continue
				var p := pos_of(n)
				if inside_solid(p):
					continue
				for axis in [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0.7071, 0, 0.7071), Vector3(0.7071, 0, -0.7071)]:
					var w := gap_width(p, axis)
					if w > 0.45 and w < 0.72:
						cells[n] = w
						break
	var seen := {}
	var n_groups := 0
	for c in cells:
		if seen.has(c):
			continue
		var g := [c]
		seen[c] = true
		var i := 0
		while i < g.size():
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = g[i] + d
				if cells.has(n) and not seen.has(n):
					seen[n] = true
					g.append(n)
			i += 1
		if g.size() >= 2:
			n_groups += 1
			var mid: Vector2i = g[g.size() / 2]
			events.append({"type": "PINCH", "pos": pos_of(mid), "what": "%.2f m wide slot (%d cells)" % [cells[mid], g.size()], "n": 1, "cells": g})
	print("  pinch slots: %d" % n_groups)

# When a bot stops moving, try to walk out in 8 directions (and with a jump).
# Only if nothing works is the player genuinely trapped.
func truly_stuck() -> bool:
	var p0 := player.global_position
	for jump in [false, true]:
		for k in 8:
			player.rotation.y = k * TAU / 8.0
			if jump and player.is_on_floor():
				player.velocity.y = player.jump_velocity
			for f in 24:
				set_input(Vector2(0, -1), false)
				await physics_frame
			if player.global_position.distance_to(p0) > 0.15:
				release()
				return false
	release()
	return true

func nearest_reachable(p: Vector3) -> Vector3:
	var c := cell_of(p)
	if reach.has(c):
		return pos_of(c)
	for r in range(1, 15):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var n := c + Vector2i(dx, dz)
				if reach.has(n):
					return pos_of(n)
	return p

func segment_blocked(a: Vector3, b: Vector3) -> bool:
	var saved := player.global_transform
	player.global_position = a + Vector3(0, 0.02, 0)
	var hit := player.test_move(player.global_transform, b - a)
	player.global_transform = saved
	return hit

func is_reachable(p: Vector3) -> bool:
	return reach.has(cell_of(p))

func release() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(a)

func set_input(v: Vector2, sprint: bool) -> void:
	release()
	if v.y < -0.01: Input.action_press("move_forward", -v.y)
	if v.y > 0.01: Input.action_press("move_back", v.y)
	if v.x < -0.01: Input.action_press("move_left", -v.x)
	if v.x > 0.01: Input.action_press("move_right", v.x)
	if sprint: Input.action_press("sprint")

func teleport(p: Vector3, yaw := 0.0) -> void:
	release()
	player.global_position = p + Vector3(0, 0.02, 0)
	player.rotation = Vector3(0, yaw, 0)
	player.velocity = Vector3.ZERO
	for i in 4:
		await physics_frame

func yaw_to(d: Vector2) -> float:
	return atan2(-d.x, -d.y)

func add_event(type: String, p: Vector3, what: String, extra := {}) -> void:
	if type == "HITCH":
		for dw in DOORWAYS:
			if Vector2(p.x - dw["c"].x, p.z - dw["c"].z).length() < 1.0:
				type = "JAMB"
	# merge with a nearby event of the same type and label
	for e in events:
		if e["type"] == type and (e["pos"] as Vector3).distance_to(p) < 0.3:
			e["n"] = e.get("n", 1) + 1
			return
	var e := {"type": type, "pos": p, "what": what, "n": 1}
	e.merge(extra)
	events.append(e)

func check_escape(what: String) -> bool:
	var p := player.global_position
	if p.x < -5.75 or p.x > 5.75 or p.z < -4.75 or p.z > 4.75 or p.y < -0.3:
		add_event("ESCAPE", p, what)
		return true
	return false

# Steers toward each point in turn. Returns false if it got stuck.
func follow(what: String, pts: Array, sprint: bool, hitch_check := true, loose := false) -> bool:
	await teleport(pts[0], yaw_to(Vector2(pts[1].x - pts[0].x, pts[1].z - pts[0].z)))
	var target_speed: float = player.sprint_speed if sprint else player.walk_speed
	var i := 1
	var t := 0.0
	var best := INF
	var last_improve := 0.0
	var seg_t := 0.0
	var slow_run := 0
	var air_run := 0
	var ok := true
	while i < pts.size():
		var p := player.global_position
		var d := Vector2(pts[i].x - p.x, pts[i].z - p.z)
		var dist := d.length()
		if dist < (0.18 if i == pts.size() - 1 or not loose else 0.35):
			i += 1
			seg_t = 0.0
			best = INF
			last_improve = t
			continue
		player.rotation.y = yaw_to(d)
		set_input(Vector2(0, -clampf(dist / 0.8, 0.4, 1.0)), sprint and dist > 1.2)
		await physics_frame
		t += DT
		seg_t += DT
		if dist < best - 0.01:
			best = dist
			last_improve = t
		if t - last_improve > 0.6:
			var at := player.global_position
			if await truly_stuck():
				add_event("STUCK", at, what)
			else:
				add_event("SNAG", at, what + " (path blocked, player free)")
			ok = false
			break
		var hs := Vector2(player.velocity.x, player.velocity.z).length()
		if hitch_check and seg_t > 0.45 and dist > 0.5:
			if hs < target_speed * 0.55:
				slow_run += 1
				if slow_run == 4:
					add_event("HITCH", player.global_position, what, {"speed": hs})
			else:
				slow_run = 0
		if not player.is_on_floor():
			air_run += 1
			if air_run == 3:
				add_event("BUMP", player.global_position, what)
		else:
			air_run = 0
		if check_escape(what):
			ok = false
			break
		if t > 30.0:
			add_event("STUCK", player.global_position, what + " (timeout)")
			ok = false
			break
	release()
	return ok

# ------------------------------------------------------------- doorways ----
const DOORWAYS := [
	{"name": "shop<->kitchen", "c": Vector3(0, 0, -2.4), "n": Vector3(1, 0, 0)},
	{"name": "office<->storeroom", "c": Vector3(0, 0, 2.4), "n": Vector3(1, 0, 0)},
	{"name": "shop<->office", "c": Vector3(-3, 0, 0), "n": Vector3(0, 0, 1)},
	{"name": "kitchen<->storeroom", "c": Vector3(3, 0, 0), "n": Vector3(0, 0, 1)},
]

func doorways() -> void:
	var fails := 0
	for dw in DOORWAYS:
		var c: Vector3 = dw["c"]
		var n: Vector3 = dw["n"]
		var tng := Vector3(-n.z, 0, n.x)
		for offset in [-0.22, -0.11, 0.0, 0.11, 0.22]:
			for ang in [-35.0, 0.0, 35.0]:
				for dir in [-1.0, 1.0]:
					for sprint in [false, true]:
						var lat := 2.0 * tan(deg_to_rad(ang))
						var a: Vector3 = c - n * dir * 2.0 + tng * (offset + lat)
						var b: Vector3 = c + n * dir * 2.0 + tng * (offset - lat)
						if not is_reachable(a) or not is_reachable(b):
							continue
						var label := "%s off %.2f ang %d %s%s" % [dw["name"], offset, int(ang), "fwd" if dir > 0 else "back", " sprint" if sprint else ""]
						var mid: Vector3 = c + tng * offset
						if segment_blocked(a, mid) or segment_blocked(mid, b):
							continue # straight line clips furniture; not a fair doorway test
						counts["doorway_runs"] += 1
						# Hugging a jamb is expected to slow you a little; only stuck counts there.
						if not await follow(label, [a, mid, b], sprint, absf(offset) < 0.15):
							fails += 1
	print("  runs %d, stuck %d" % [counts["doorway_runs"], fails])

# --------------------------------------------------------------- routes ----
const TOURS := [
	# full loop through all four doorways, both ways round
	[Vector3(-3, 0, -1.6), Vector3(-1.2, 0, -2.4), Vector3(1.2, 0, -2.4), Vector3(3, 0, -1.2), Vector3(3, 0, 1.2),
	 Vector3(1.2, 0, 2.4), Vector3(-1.2, 0, 2.4), Vector3(-3, 0, 1.2), Vector3(-3, 0, -1.2), Vector3(-3, 0, -1.6)],
	[Vector3(-3, 0, -1.6), Vector3(-3, 0, 1.2), Vector3(-1.2, 0, 2.4), Vector3(1.2, 0, 2.4), Vector3(3, 0, 1.2),
	 Vector3(3, 0, -1.2), Vector3(1.2, 0, -2.4), Vector3(-1.2, 0, -2.4), Vector3(-3, 0, -1.6)],
	# working spots: counter, window A, griddle, fridge, delivery door, window B, desk, grow shelf, drinks fridge
	[Vector3(-3, 0, -1.6), Vector3(-3.0, 0, -3.6), Vector3(-1.0, 0, -3.5), Vector3(0, 0, -2.4), Vector3(4.9, 0, -2.4),
	 Vector3(2.6, 0, -3.5), Vector3(4.4, 0, -3.5), Vector3(3.0, 0, -0.9), Vector3(3.0, 0, 1.0), Vector3(3.0, 0, 4.2),
	 Vector3(1.0, 0, 2.4), Vector3(-1.0, 0, 2.4), Vector3(-4.95, 0, 2.4), Vector3(-2.8, 0, 3.15), Vector3(-4.7, 0, 1.05),
	 Vector3(-3.0, 0, 0.9), Vector3(-3.0, 0, -0.9), Vector3(-4.2, 0, -1.3), Vector3(-4.8, 0, -3.5)],
]

func routes() -> void:
	var fails := 0
	for i in TOURS.size():
		for sprint in [false, true]:
			var pts := []
			for p in TOURS[i]:
				pts.append(nearest_reachable(p))
			counts["route_runs"] += 1
			if not await follow("tour %d%s" % [i + 1, " sprint" if sprint else ""], pts, sprint, false, true):
				fails += 1
	print("  runs %d, stuck %d" % [counts["route_runs"], fails])

# ---------------------------------------------------------------- slides ----
const ROOMS := [
	{"name": "shop", "r": Rect2(-5.75, -4.75, 5.675, 4.675)},
	{"name": "kitchen", "r": Rect2(0.075, -4.75, 5.675, 4.675)},
	{"name": "office", "r": Rect2(-5.75, 0.075, 5.675, 4.675)},
	{"name": "storeroom", "r": Rect2(0.075, 0.075, 5.675, 4.675)},
]

# Push diagonally into a wall while travelling along it; measure smoothness.
func slide(what: String, from: Vector3, along: Vector3, into: Vector3, length: float) -> void:
	await teleport(from)
	var dir := (along + into * 0.45).normalized()
	player.rotation.y = yaw_to(Vector2(dir.x, dir.z))
	var t := 0.0
	var speeds := []
	var poss := []
	var stopped := 0.0
	var start := player.global_position
	while t < length / (player.walk_speed * 0.9) + 0.8:
		set_input(Vector2(0, -1), false)
		await physics_frame
		t += DT
		var v := Vector3(player.velocity.x, 0, player.velocity.z)
		speeds.append(v.dot(along))
		poss.append(player.global_position)
		if check_escape(what):
			break
		if not player.is_on_floor():
			add_event("BUMP", player.global_position, what)
		if v.dot(along) < 0.15:
			stopped += DT
			if stopped > 0.4:
				break # reached something we can't slide past
		else:
			stopped = 0.0
	release()
	var travelled := (player.global_position - start).dot(along)
	# Hitches: along-wall speed collapsing after we've got going, then recovering.
	var peak := 0.0
	for i in speeds.size():
		peak = maxf(peak, speeds[i])
		if i > 20 and peak > 1.5 and speeds[i] < peak * 0.4 and i + 6 < speeds.size() and speeds[i + 6] > peak * 0.7:
			add_event("HITCH", poss[i], what, {"speed": speeds[i]})
	counts["slide_runs"] += 1
	# Stopping short is fine at furniture ends; record where for the map.
	if travelled < 0.3:
		add_event("STALL", start, what + " (slid %.2f m)" % travelled)

func slides() -> void:
	for room in ROOMS:
		var r: Rect2 = room["r"]
		var inset := RADIUS + 0.15
		var corners := [
			Vector3(r.position.x + inset, 0, r.position.y + inset), Vector3(r.end.x - inset, 0, r.position.y + inset),
			Vector3(r.end.x - inset, 0, r.end.y - inset), Vector3(r.position.x + inset, 0, r.end.y - inset)]
		var walls := [
			[0, 1, Vector3(1, 0, 0), Vector3(0, 0, -1)], [1, 0, Vector3(-1, 0, 0), Vector3(0, 0, -1)],  # north
			[1, 2, Vector3(0, 0, 1), Vector3(1, 0, 0)], [2, 1, Vector3(0, 0, -1), Vector3(1, 0, 0)],    # east
			[2, 3, Vector3(-1, 0, 0), Vector3(0, 0, 1)], [3, 2, Vector3(1, 0, 0), Vector3(0, 0, 1)],    # south
			[3, 0, Vector3(0, 0, -1), Vector3(-1, 0, 0)], [0, 3, Vector3(0, 0, 1), Vector3(-1, 0, 0)],  # west
		]
		for w in walls:
			var a: Vector3 = nearest_reachable(corners[w[0]])
			var b: Vector3 = corners[w[1]]
			await slide("%s slide %s" % [room["name"], str(w[2])], a, w[2], w[3], absf((b - a).dot(w[2])))
	print("  runs %d" % counts["slide_runs"])

# --------------------------------------------------------- slot probes ----
# Shove into every narrow slot from five angles, jumping half way. A slot is
# only a problem if the player ends up wedged above the floor or trapped.
func probe_slots() -> void:
	var wedges := 0
	var runs := 0
	for e in events.filter(func(x): return x["type"] == "PINCH"):
		var target: Vector3 = e["pos"]
		var from := nearest_reachable(target)
		var to := target - from
		to.y = 0
		if to.length() < 0.05:
			to = Vector3(0, 0, -1) * 0.3
		var base_yaw := yaw_to(Vector2(to.x, to.z))
		for ang in [-60.0, -30.0, 0.0, 30.0, 60.0]:
			await teleport(from - to.normalized() * 0.6, base_yaw + deg_to_rad(ang))
			var t := 0.0
			var lifted := 0.0
			while t < 1.6:
				set_input(Vector2(0, -1), false)
				if absf(t - 0.6) < DT * 0.5 and player.is_on_floor():
					player.velocity.y = player.jump_velocity
				await physics_frame
				t += DT
				var p := player.global_position
				if t > 1.0 and player.is_on_floor() and p.y > 0.05:
					lifted += DT
			release()
			runs += 1
			var at := player.global_position
			if lifted > 0.3:
				add_event("WEDGE", at, "rides up %.2f m in slot near (%.1f, %.1f)" % [at.y, target.x, target.z])
				wedges += 1
			elif await truly_stuck():
				add_event("STUCK", at, "slot near (%.1f, %.1f)" % [target.x, target.z])
				wedges += 1
		e["type"] = "SLOT" if true else e["type"]
	print("  runs %d, wedges/stuck %d" % [runs, wedges])

# ------------------------------------------------------------- windows ----
# Run and jump at every window (boarded and open) from several angles.
func window_assault(windows: Node3D) -> void:
	var n := 0
	for boarded in [true, false]:
		for w in windows.get_children():
			for b in w.get_node("Boards").get_children():
				(b as StaticBody3D).collision_layer = 2 if boarded else 0
			var rp: Vector3 = (w.get_node("Repair_Point") as Node3D).global_position
			var out: Vector3 = (w as Node3D).global_basis.z
			var side := Vector3(-out.z, 0, out.x)
			for lat in [-0.6, 0.0, 0.6]:
				for back in [0.0, 1.0]:
					var from := nearest_reachable(rp - out * back + side * lat)
					await teleport(from, yaw_to(Vector2(out.x, out.z)))
					var t := 0.0
					while t < 2.5:
						set_input(Vector2(0, -1), true)
						if player.is_on_floor() and fmod(t, 0.5) < DT:
							player.velocity.y = player.jump_velocity
						await physics_frame
						t += DT
						if check_escape("window %s %s" % [w.name, "boarded" if boarded else "open"]):
							break
						var p := player.global_position
						if player.is_on_floor() and p.y > 0.05:
							add_event("PERCH", p, "on %s %s sill, %.2f m up" % [w.name, "boarded" if boarded else "open", p.y], {"height": p.y, "head": 0.0})
					release()
					n += 1
					var at := player.global_position
					if at.y > 0.05 and await truly_stuck():
						add_event("STUCK", at, "window %s" % w.name)
	for w in windows.get_children():
		for b in w.get_node("Boards").get_children():
			(b as StaticBody3D).collision_layer = 2
	print("  runs %d" % n)

# ------------------------------------------------------------------ fuzz ----
func fuzz(bots: int, seconds: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var args := OS.get_cmdline_user_args()
	if "--seed" in args:
		rng.seed = int(args[args.find("--seed") + 1])
	var reach_list := reach.keys()
	var stuck := 0
	for bi in bots:
		var start := pos_of(reach_list[rng.randi_range(0, reach_list.size() - 1)])
		await teleport(start, rng.randf() * TAU)
		var t := 0.0
		var next_change := 0.0
		var input := Vector2.ZERO
		var sprint := false
		var hist := []  # [time, pos, input]
		while t < seconds:
			if t >= next_change:
				next_change = t + rng.randf_range(0.2, 1.2)
				var a := rng.randi_range(0, 7) * TAU / 8.0
				input = Vector2(cos(a), sin(a))
				sprint = rng.randf() < 0.5
				player.rotation.y += rng.randf_range(-1.5, 1.5)
				if rng.randf() < 0.3 and player.is_on_floor():
					player.velocity.y = player.jump_velocity
			set_input(input, sprint)
			await physics_frame
			t += DT
			var p := player.global_position
			visited[cell_of(p)] = true
			if check_escape("fuzz bot %d" % bi):
				await teleport(start)
				continue
			if player.is_on_floor() and p.y > 0.05:
				var up := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.8, 0), p + Vector3(0, 2.4, 0), 1 | 2, [player.get_rid()])
				var hit := space.intersect_ray(up)
				var head := 0.6 if hit.is_empty() else (hit["position"] as Vector3).y - (p.y + 1.8)
				add_event("PERCH", p, "standing %.2f m up, headroom %.2f m" % [p.y, head], {"height": p.y, "head": head})
			hist.append([t, p, input])
			while hist.size() > 0 and t - hist[0][0] > 2.5:
				hist.pop_front()
			if t > 3.0 and hist.size() > 100:
				var span := 0.0
				var dirs := {}
				for h in hist:
					span = maxf(span, (h[1] as Vector3).distance_to(p))
					dirs[Vector2i(roundi(h[2].x * 2), roundi(h[2].y * 2))] = true
				if span < 0.12 and dirs.size() >= 3:
					if await truly_stuck():
						add_event("STUCK", p, "fuzz bot %d (can't walk or jump out)" % bi)
						stuck += 1
						await teleport(start)
					hist.clear()
		counts["fuzz_seconds"] += seconds
	print("  bots %d x %ds, stuck %d" % [bots, int(seconds), stuck])

# --------------------------------------------------------------- output ----
func write_map() -> void:
	var px := 40
	var w := int((X1 - X0) * px) + 1
	var h := int((Z1 - Z0) * px) + 1
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("#101C2C"))
	var s := int(CELL * px)
	for e in events:
		if e["type"] in ["PINCH", "SLOT"]:
			for c in e["cells"]:
				img.fill_rect(Rect2i(c.x * s - s / 2, c.y * s - s / 2, s, s), Color("#B04050"))
	for c in free_cells:
		var col := Color("#626D73") if reach.has(c) else Color("#C96B35")
		if visited.has(c) and reach.has(c):
			col = Color("#7d898e")
		img.fill_rect(Rect2i(c.x * s - s / 2, c.y * s - s / 2, s, s), col)
	var colours := {"STUCK": Color.RED, "HITCH": Color("#F3A34D"), "BUMP": Color.MAGENTA, "PERCH": Color("#65C9C2"), "ESCAPE": Color.WHITE, "STALL": Color("#24384B"), "SNAG": Color("#E9E1D1"), "WEDGE": Color.RED, "JAMB": Color("#9a6a3a")}
	for e in events:
		if not colours.has(e["type"]):
			continue
		var p: Vector3 = e["pos"]
		var cx := int((p.x - X0) * px)
		var cz := int((p.z - Z0) * px)
		var r := 5 if e["type"] in ["STUCK", "ESCAPE"] else 3
		if e["type"] == "PERCH" and e.get("head", 1.0) < 0.15:
			r = 5
		img.fill_rect(Rect2i(cx - r, cz - r, r * 2, r * 2), colours[e["type"]])
	img.save_png(ProjectSettings.globalize_path(MAP_PATH))

func summarise() -> void:
	print("\n== summary")
	print("doorway runs %d · tour runs %d · wall slides %d · fuzz %.0f s" % [counts["doorway_runs"], counts["route_runs"], counts["slide_runs"], counts["fuzz_seconds"]])
	var bad := 0
	for type in ["ESCAPE", "STUCK", "WEDGE", "SNAG", "HITCH", "BUMP", "POCKET", "PERCH", "JAMB", "SLOT", "STALL"]:
		var list := events.filter(func(e): return e["type"] == type)
		if list.is_empty():
			continue
		print("%s x%d" % [type, list.size()])
		for e in list:
			var p: Vector3 = e["pos"]
			print("   (%5.2f, %4.2f, %5.2f) %s%s" % [p.x, p.y, p.z, e["what"], (" [x%d]" % e["n"]) if e.get("n", 1) > 1 else ""])
		if type in ["ESCAPE", "STUCK", "WEDGE", "SNAG", "HITCH", "BUMP", "POCKET"]:
			bad += list.size()
		if type == "PERCH":
			bad += list.filter(func(e): return e["head"] < 0.15 or e["height"] > 0.55).size()
	print("\nproblems: %d" % bad)
	quit(1 if bad > 0 else 0)
