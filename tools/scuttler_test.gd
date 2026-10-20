# Scuttler scenarios (headless):
#   godot --headless --path . --fixed-fps 60 --script res://tools/scuttler_test.gd
extends SceneTree

const DT := 1.0 / 60.0
const SPOTS := {
	"shop counter": Vector3(-3.0, 0, -3.4),
	"kitchen line": Vector3(2.6, 0, -3.4),
	"office desk": Vector3(-2.8, 0, 3.0),
	"storeroom door": Vector3(3.0, 0, 4.1),
}
var main: Node3D
var player: CharacterBody3D
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1

func st(z: Node) -> String:
	return ["LANE", "BREACH", "CLIMB", "HUNT", "ATTACK", "STAGGER", "DEAD"][z.state]

func fresh(ppos := Vector3(-3.0, 0, 3.0), god := true) -> void:
	if main:
		main.queue_free()
		await process_frame
		for n in root.get_children():
			if n is RigidBody3D or n.name == "OozeFX":
				n.queue_free()
		await process_frame
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	if god:
		player.max_health = 1e9
		player.health = 1e9
	for i in 10:
		await physics_frame
	player.global_position = ppos + Vector3(0, 0.05, 0)
	await physics_frame

func win(id: String) -> Node3D:
	return main.get_node("ShopGreybox/Windows/Window_" + id)

func run_until(z: Node, cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit and not cond.call():
		await physics_frame
		t += DT
	return t

func _run() -> void:
	print("== lanes x rooms")
	for w_id in ["A", "B"]:
		for spot in SPOTS:
			await fresh(SPOTS[spot])
			var z: Node = main.spawn_scuttler(win(w_id))
			var w := win(w_id)
			var times := {}
			var order := []
			w.board_removed.connect(func(i): order.append(i))
			var hp: float = player.health
			var t := 0.0
			var last := ""
			var still := 0.0
			var prev: Vector3 = z.global_position
			var stuck := ""
			var escaped := false
			var min_y := 9.0
			var boards_when_dived := -1
			while t < 40.0 and player.health == hp:
				await physics_frame
				t += DT
				var s := st(z)
				if s != last:
					if not times.has(s):
						times[s] = t
						if s == "CLIMB":
							boards_when_dived = w.boards_left()
					last = s
				if s in ["LANE", "HUNT"]:
					still = still + DT if z.global_position.distance_to(prev) < 0.004 else 0.0
					if still > 2.0 and stuck == "":
						stuck = "%s %s" % [s, str(z.global_position.snapped(Vector3.ONE * 0.1))]
				prev = z.global_position
				if s in ["HUNT", "ATTACK"] and (absf(z.global_position.x) > 5.8 or absf(z.global_position.z) > 4.8):
					escaped = true
			var ok: bool = times.has("BREACH") and times.has("CLIMB") and times.has("HUNT") and player.health < hp and stuck == "" and not escaped
			check(ok, "window %s -> %s: ramming %.1fs, dives %.1fs (boards left %d, knocked out %s), kicks you %.1fs%s%s" % [
				w_id, spot, times.get("BREACH", -1.0), times.get("CLIMB", -1.0), boards_when_dived, str(order), t,
				(" STUCK " + stuck) if stuck != "" else "", " ESCAPED" if escaped else ""])
			if w_id == "A" and spot == "shop counter":
				check(order.slice(0, 2) == [0, 1], "rams the boards out from the bottom (%s)" % str(order))
				check(boards_when_dived == 2, "dives through as soon as the bottom two are gone")
				check(times.get("CLIMB", 99.0) < 8.0, "much faster than a Shambler (inside by %.1f s vs ~17 s)" % times.get("HUNT", -1.0))

	print("== through a gap a Shambler made at the top")
	await fresh(Vector3(3.0, 0, -1.0))
	var w := win("A")
	w.rip_board()
	w.rip_board()   # top two gone
	var z: Node = main.spawn_scuttler(w)
	var seen_breach := [false]
	var t := await run_until(z, func():
		if st(z) == "BREACH":
			seen_breach[0] = true
		return st(z) == "HUNT", 20.0)
	check(st(z) == "HUNT" and not seen_breach[0] and w.boards_left() == 2, "dives straight through the top gap without ramming (%.1f s, %d boards left)" % [t, w.boards_left()])
	check(z.global_position.x < 5.75, "and lands inside")

	print("== repairing")
	await fresh(win("A").repair_point())
	player.get_node("Head/Camera3D").look_at(win("A").global_position)
	z = main.spawn_scuttler(win("A"))
	var held := 0.0
	t = 0.0
	while t < 25.0:
		await physics_frame
		t += DT
		if st(z) == "BREACH":
			Input.action_press("interact")
	Input.action_release("interact")
	check(st(z) == "BREACH", "holding E keeps a Scuttler out (state %s)" % st(z))

	print("== shooting and knifing")
	await fresh(Vector3(1.0, 0, -1.4))
	z = main.spawn_scuttler(win("A"))
	z.state = 3
	z.global_position = Vector3(4.0, 0.05, -1.4)
	await physics_frame
	z.set_physics_process(false)
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var gun: Node = player.get_node("Head/Camera3D/TestGun")
	var cap_hb := z.find_child("CapHitbox", true, false) as Node3D
	cam.look_at(cap_hb.global_position + Vector3(0, 0.15, 0), Vector3.UP)
	await physics_frame
	var r: Dictionary = gun.shoot()
	await physics_frame
	check(r.get("kind", "") == "head" and not z.is_dead() and z.health < 5.0, "a pistol shot to the cap nearly kills it (health %.0f)" % z.health)
	for i in 30:
		await physics_frame
	cam.look_at(cap_hb.global_position + Vector3(0, 0.15, 0), Vector3.UP)
	await physics_frame
	gun.shoot()
	await physics_frame
	check(z.is_dead(), "a second hit finishes it")
	await fresh(Vector3(1.0, 0, -1.4))
	z = main.spawn_scuttler(win("A"))
	z.state = 3
	z.global_position = Vector3(4.0, 0.05, -1.4)
	await physics_frame
	cam = player.get_node("Head/Camera3D")
	gun = player.get_node("Head/Camera3D/TestGun")
	cam.look_at(z.global_position + Vector3(0, 0.3, 0), Vector3.UP)
	await physics_frame
	var x0: float = z.global_position.x
	r = gun.shoot()
	for i in 12:
		await physics_frame
	check(not z.is_dead() and r.get("kind", "") == "body", "a leg shot doesn't kill (health %.0f)" % z.health)
	check(z.global_position.x > x0 + 0.15, "and knocks it back (%.2f m)" % (z.global_position.x - x0))
	for i in 30:
		await physics_frame
	cam.look_at(z.global_position + Vector3(0, 0.3, 0), Vector3.UP)
	await physics_frame
	gun.shoot()
	await physics_frame
	check(z.is_dead(), "two body shots kill")
	var body := z.get_node("Model/Skeleton3D/Body") as MeshInstance3D
	for i in 200:
		await physics_frame
	var m := body.material_override as StandardMaterial3D
	check(m != null and m.emission_energy_multiplier < 0.05, "its glowing spots fade out after death")
	check(z.collision_layer == 0, "the corpse doesn't block")
	# knife
	await fresh(Vector3(1.6, 0, -1.4))
	player.rotation.y = -PI / 2.0
	player.switch_weapon(1)
	for i in 30:
		await physics_frame
	z = main.spawn_scuttler(win("A"))
	z.state = 3
	z.global_position = Vector3(2.6, 0.05, -1.4)
	await physics_frame
	z.set_physics_process(false)
	var knife: Node = player.get_node("Head/Camera3D/Knife")
	cam = player.get_node("Head/Camera3D")
	cam.look_at(z.global_position + Vector3(0, 0.3, 0), Vector3.UP)
	knife.request("slash")
	for i in 36:
		await physics_frame
	check(not z.is_dead() and z.health == 15.0, "a knife slash to the body leaves it on 15 (health %.0f)" % z.health)
	z.health = 55.0
	z.set_physics_process(false)
	cap_hb = z.find_child("CapHitbox", true, false) as Node3D
	cam.look_at(cap_hb.global_position + Vector3(0, 0.1, 0), Vector3.UP)
	knife.request("stab")
	for i in 50:
		await physics_frame
	check(z.is_dead(), "a stab to the cap kills")
	await fresh(Vector3(1.6, 0, -1.4))
	player.rotation.y = -PI / 2.0
	player.switch_weapon(1)
	for i in 30:
		await physics_frame
	z = main.spawn_scuttler(win("A"))
	z.state = 3
	z.global_position = Vector3(2.6, 0.05, -1.4)
	await physics_frame
	z.set_physics_process(false)
	knife = player.get_node("Head/Camera3D/Knife")
	cam = player.get_node("Head/Camera3D")
	cap_hb = z.find_child("CapHitbox", true, false) as Node3D
	cam.look_at(cap_hb.global_position + Vector3(0, 0.1, 0), Vector3.UP)
	knife.request("slash")
	for i in 36:
		await physics_frame
	check(not z.is_dead() and z.health == 15.0, "a slash across the cap is a normal hit, like on the Shambler (health %.0f)" % z.health)

	print("== mixed crowd")
	for spot in ["office desk", "kitchen line"]:
		await fresh(SPOTS[spot])
		var crowd := []
		for i in 6:
			var ww := win("A" if i % 2 == 0 else "B")
			crowd.append(main.spawn_scuttler(ww) if i % 3 == 0 else main.spawn_zombie(ww))
			for k in 30:
				await physics_frame
		var reached := {}
		var stuck := {}
		var hist := {}
		t = 0.0
		while t < 90.0 and reached.size() < crowd.size():
			await physics_frame
			t += DT
			for c in crowd:
				var s := st(c)
				if not reached.has(c) and (s == "ATTACK" or (s == "HUNT" and c.global_position.distance_to(player.global_position) < 2.0)):
					reached[c] = t
				if s in ["LANE", "HUNT"]:
					if not hist.has(c):
						hist[c] = []
					hist[c].append(c.global_position)
					if hist[c].size() > 360:
						hist[c].pop_front()
					if hist[c].size() == 360 and (hist[c][0] as Vector3).distance_to(c.global_position) < 0.4 and c.global_position.distance_to(player.global_position) > 2.5:
						stuck[c] = "%s %s %s" % [c.name, s, str(c.global_position.snapped(Vector3.ONE * 0.1))]
		var ts := reached.values().map(func(x): return "%.0f" % x)
		check(reached.size() == crowd.size() and stuck.is_empty(), "2 Scuttlers + 4 Shamblers all reach you at the %s (%d of %d, at %s s)%s" % [spot, reached.size(), crowd.size(), ", ".join(ts), (" STUCK " + str(stuck.values())) if not stuck.is_empty() else ""])

	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
