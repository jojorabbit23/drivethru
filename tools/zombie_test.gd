# Plays out zombie encounters headlessly and checks the Shambler behaves.
#
#   godot --headless --path . --fixed-fps 60 --script res://tools/zombie_test.gd
#
# Scenarios: each lane x player hiding in each room; repairing against a
# ripping zombie; shooting (body + headshot through the boards and inside);
# a crowd from both lanes. Fails on: stuck zombies, missed stages, no attack,
# zombies leaving the building, or bad damage/kill behaviour.
extends SceneTree

const DT := 1.0 / 60.0
const ROOM_SPOTS := {
	"shop counter": Vector3(-3.0, 0, -3.4),
	"kitchen line": Vector3(2.6, 0, -3.4),
	"office desk": Vector3(-2.8, 0, 3.0),
	"storeroom door": Vector3(3.0, 0, 4.1),
}

var main: Node3D
var player: CharacterBody3D
var shop: Node3D
var failures := 0
var lines := []

var trace := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	seed(int(args[args.find("--seed") + 1]) if "--seed" in args else 1)
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	lines.append(("  PASS  " if ok else "  FAIL  ") + what)
	print(lines[-1])
	if not ok:
		failures += 1

func fresh() -> void:
	if main:
		main.queue_free()
		await process_frame
		for n in root.get_children():
			if n is RigidBody3D or n is MeshInstance3D:
				n.queue_free()
		await process_frame
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	shop = main.get_node("ShopGreybox")
	for i in 20:
		await physics_frame

func place_player(p: Vector3) -> void:
	player.global_position = p + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	await physics_frame

func window(id: String) -> Node3D:
	return shop.get_node("Windows/Window_" + id)

func state_name(z: Node) -> String:
	return ["LANE", "BREACH", "CLIMB", "HUNT", "ATTACK", "STAGGER", "DEAD"][z.state]

# Runs one zombie from a lane to the player. Returns timings per stage.
func encounter(win_id: String, spot_name: String) -> Dictionary:
	await fresh()
	await place_player(ROOM_SPOTS[spot_name])
	player.max_health = 100000.0
	player.health = 100000.0
	var z: Node = main.spawn_zombie(window(win_id))
	var t := 0.0
	var times := {}
	var last := ""
	var still := 0.0
	var prev: Vector3 = z.global_position
	var result := {"stuck": "", "escaped": false}
	var hp_before: float = player.health
	while t < 70.0:
		await physics_frame
		t += DT
		var s := state_name(z)
		if s != last:
			if not times.has(s):
				times[s] = t
			last = s
		if s in ["LANE", "HUNT"]:
			if z.global_position.distance_to(prev) < 0.004:
				still += DT
			else:
				still = 0.0
			if still > 3.0 and result["stuck"] == "":
				result["stuck"] = "%s at %s" % [s, str(z.global_position.snapped(Vector3.ONE * 0.01))]
		prev = z.global_position
		if s in ["HUNT", "ATTACK"]:
			var p: Vector3 = z.global_position
			if absf(p.x) > 5.8 or absf(p.z) > 4.8:
				result["escaped"] = true
		if player.health < hp_before:
			times["HIT_PLAYER"] = t
			break
	result["times"] = times
	result["boards_left"] = window(win_id).boards_left()
	return result

func nearest_other(c: Node, crowd: Array) -> float:
	var d := INF
	for o in crowd:
		if o != c:
			d = minf(d, (o as Node3D).global_position.distance_to(c.global_position))
	return d

func crowd_test(spot: String) -> void:
	var t := 0.0
	await fresh()
	await place_player(ROOM_SPOTS[spot])
	player.max_health = 100000.0
	player.health = 100000.0
	var crowd := []
	for i in 6:
		crowd.append(main.spawn_zombie(window("A" if i % 2 == 0 else "B")))
		for k in 30:
			await physics_frame
	t = 0.0
	var reached := {}
	var stuck_at := {}
	var still := {}
	var prevs := {}
	while t < 120.0 and reached.size() < crowd.size():
		await physics_frame
		t += DT
		for c in crowd:
			var s := state_name(c)
			if fmod(t, 1.0) < DT:
				if not trace.has(c):
					trace[c] = []
				trace[c].append("%d:%s%s" % [int(t), s.substr(0, 2), str(Vector2(c.global_position.x, c.global_position.z).snapped(Vector2.ONE * 0.1))])
			if not reached.has(c) and (s == "ATTACK" or (s == "HUNT" and c.global_position.distance_to(player.global_position) < 2.2)):
				reached[c] = t
			if s in ["LANE", "HUNT"]:
				if prevs.has(c) and c.global_position.distance_to(prevs[c]) < 0.004:
					still[c] = still.get(c, 0.0) + DT
				else:
					still[c] = 0.0
				# "barely moving" counts too: under 0.4 m in the last 6 s while
				# still more than 2.5 m from the player
				if not trace.has(str(c) + "_hist"):
					trace[str(c) + "_hist"] = []
				var h: Array = trace[str(c) + "_hist"]
				h.append(c.global_position)
				if h.size() > 360:
					h.pop_front()
				if h.size() == 360 and (h[0] as Vector3).distance_to(c.global_position) < 0.4 and c.global_position.distance_to(player.global_position) > 2.5:
					still[c] = 99.0
				if still[c] > 6.0 and not stuck_at.has(c):
					stuck_at[c] = "%s %s" % [s, str(c.global_position.snapped(Vector3.ONE * 0.1))]
			prevs[c] = c.global_position
	for c in crowd:
		if not reached.has(c):
			print("    straggler: %s at %s, %.2f m from you, nearest other zombie %.2f m" % [state_name(c), str(c.global_position.snapped(Vector3.ONE * 0.1)),
				c.global_position.distance_to(player.global_position), nearest_other(c, crowd)])
	var slowest: Node = null
	for c in reached:
		if slowest == null or reached[c] > reached[slowest]:
			slowest = c
	if slowest and reached[slowest] > 30.0:
		print("    slowest zombie trace: ", " ".join(trace[slowest]))
	var waits := []
	for c in reached:
		waits.append("%.0f" % reached[c])
	check(reached.size() == crowd.size(), "all %d zombies reach you at the %s (%d did, at %s s)" % [crowd.size(), spot, reached.size(), ", ".join(waits)])
	check(stuck_at.is_empty(), "no zombie stuck or jammed for over 6 s %s" % (str(stuck_at.values()) if not stuck_at.is_empty() else ""))


func _run() -> void:
	print("== lanes x rooms")
	for win_id in ["A", "B"]:
		for spot in ROOM_SPOTS:
			var r := await encounter(win_id, spot)
			var tm: Dictionary = r["times"]
			var label := "window %s -> %s" % [win_id, spot]
			var ok: bool = tm.has("BREACH") and tm.has("CLIMB") and tm.has("HUNT") and tm.has("HIT_PLAYER") and r["stuck"] == "" and not r["escaped"]
			check(ok, "%s: breach %.1fs, climb %.1fs, hunting %.1fs, hits you %.1fs%s%s" % [label,
				tm.get("BREACH", -1.0), tm.get("CLIMB", -1.0), tm.get("HUNT", -1.0), tm.get("HIT_PLAYER", -1.0),
				(" STUCK " + r["stuck"]) if r["stuck"] != "" else "", " ESCAPED" if r["escaped"] else ""])

	print("== repairing while it rips")
	await fresh()
	await place_player(window("A").repair_point())
	player.get_node("Head/Camera3D").look_at(window("A").global_position)
	var z: Node = main.spawn_zombie(window("A"))
	var t := 0.0
	var repairs := 0
	var min_left := 4
	var repaired := [0]  # array: lambdas capture locals by value
	window("A").board_restored.connect(func(_i): repaired[0] += 1)
	while t < 40.0:
		await physics_frame
		t += DT
		min_left = mini(min_left, window("A").boards_left())
		# hold E (the real repair code) once the zombie is at the window
		if state_name(z) == "BREACH":
			Input.action_press("interact")
	Input.action_release("interact")
	repairs = repaired[0]
	check(state_name(z) == "BREACH", "holding E keeps a lone Shambler out (state %s, %d boards repaired, never below %d left)" % [state_name(z), repairs, min_left])
	check(min_left < 4 and repairs > 0, "it still tears boards off between repairs")

	print("== shooting")
	await fresh()
	await place_player(Vector3(4.6, 0, -2.4))
	z = main.spawn_zombie(window("A"))
	t = 0.0
	while state_name(z) != "BREACH" and t < 20.0:
		await physics_frame
		t += DT
	var gun = player.get_node("Head/Camera3D/TestGun")
	var cam: Camera3D = player.get_node("Head/Camera3D")
	# aim through the gap between boards 2 and 3 at body height
	var aim: Vector3 = z.global_position + Vector3(0, 1.48, 0)
	cam.look_at(aim, Vector3.UP)
	await physics_frame
	var hp: float = z.health
	var res: Dictionary = gun.shoot()
	await physics_frame
	var hit_board := not res.is_empty() and (res["collider"] as Node).name.begins_with("Board")
	check(hit_board or z.health < hp, "shots from inside either hit the zombie through a gap or stop on a board (%s)" % ("board" if hit_board else "zombie"))
	# remove boards, aim at the head: one-shot kill
	for b in window("A").boards:
		b.collision_layer = 0
		b.visible = false
	await physics_frame
	var skel: Skeleton3D = z.get_node("Model/Skeleton3D")
	var head_pos := skel.to_global(skel.get_bone_global_pose(skel.find_bone("head")).origin) + Vector3(0, 0.14, 0)
	cam.look_at(head_pos, Vector3.UP)
	await physics_frame
	gun.shoot()
	for i in 5:
		await physics_frame
	check(z.is_dead(), "headshot kills a Shambler in one shot (health %.0f)" % z.health)
	for i in 120:
		await physics_frame
	var body_layer: int = z.collision_layer
	check(body_layer == 0, "corpse stops blocking (collision layer %d)" % body_layer)
	# body shots: three to kill
	await fresh()
	await place_player(Vector3(3.0, 0, -2.4))
	z = main.spawn_zombie(window("A"))
	for b in window("A").boards:
		b.collision_layer = 0
	t = 0.0
	while state_name(z) != "HUNT" and t < 30.0:
		await physics_frame
		t += DT
	cam = player.get_node("Head/Camera3D")
	gun = player.get_node("Head/Camera3D/TestGun")
	var shots := 0
	while not z.is_dead() and shots < 6:
		cam.look_at(z.global_position + Vector3(0, 1.0, 0), Vector3.UP)
		await physics_frame
		gun.shoot()
		shots += 1
		for i in 15:
			await physics_frame
	check(z.is_dead() and shots == 3, "three body shots kill it (took %d)" % shots)

	print("== crowd from both lanes")
	for spot in ["office desk", "kitchen line", "shop counter"]:
		await crowd_test(spot)

	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
