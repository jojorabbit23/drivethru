# Checks the ooze lands where it physically should.
#   godot --headless --path . --fixed-fps 60 --script res://tools/ooze_test.gd
extends SceneTree

var main: Node3D
var player: CharacterBody3D
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1

func wait(frames: int) -> void:
	for i in frames:
		await physics_frame

# Fresh scene with a frozen zombie standing at `zpos`, the player at `ppos`
# aiming at it.
func setup(zpos: Vector3, ppos: Vector3) -> Node:
	if main:
		main.queue_free()
		await process_frame
		var old := root.get_node_or_null("OozeFX")
		if old:
			old.queue_free()
		await process_frame
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	await wait(10)
	var z: Node3D = main.spawn_zombie(main.get_node("ShopGreybox/Windows/Window_A"))
	z.state = 3  # HUNT, then freeze in place
	z.global_position = zpos
	var to_player := ppos - zpos
	z.rotation.y = atan2(-to_player.x, -to_player.z)
	await wait(2)
	z.set_physics_process(false)
	z.velocity = Vector3.ZERO
	player.global_position = ppos + Vector3(0, 0.05, 0)
	player.rotation.y = atan2(to_player.x, to_player.z)
	await wait(5)
	# Reproducible particle trajectories: an unseeded one-shot sample could
	# randomly reverse the small behind/front majority and fail this test.
	var effect: Node = (load("res://core/ooze.gd") as GDScript).get_fx(main)
	effect.rng.seed = 420
	return z

func fx() -> Node:
	return root.get_node_or_null("OozeFX")

func aim_and_fire(at: Vector3) -> Dictionary:
	var cam: Camera3D = player.get_node("Head/Camera3D")
	cam.look_at(at, Vector3.UP)
	await physics_frame
	return player.get_node("Head/Camera3D/TestGun").shoot()

# Each splat should sit on real geometry: a short ray back along its normal
# must hit something within 2 cm.
# Checks the centre and the corners of the splat's visible area (about 60%
# of the quad for the splat art; for drips, the whole run below the pivot).
func on_surface(node: Node3D) -> bool:
	var n := node.global_basis.z.normalized()
	var is_drip: bool = (node as MeshInstance3D).material_override == fx().drip_mat
	var pts := []
	if is_drip:
		for t in [0.0, 0.5, 0.95]:
			pts.append(node.global_position - node.global_basis.y * t)
	else:
		pts.append(node.global_position)
		for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			pts.append(node.global_position + (node.global_basis.x * c.x + node.global_basis.y * c.y) * 0.5 * 0.6)
	var hit_count := 0
	for p in pts:
		var q := PhysicsRayQueryParameters3D.create(p + n * 0.03, p - n * 0.03, 1 | 2)
		if not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			hit_count += 1
	return hit_count == pts.size() if not is_drip else hit_count >= 2

func classify() -> Dictionary:
	var out := {"floor": 0, "wall": 0, "other": 0, "floating": 0, "list": []}
	for s in fx().splats:
		var node: Node3D = s["node"]
		if not is_instance_valid(node):
			continue
		out["list"].append(node)
		var n := node.global_basis.z.normalized()
		if not on_surface(node):
			out["floating"] += 1
			print("     floating: pos %s normal %s scale %s drip %s" % [str(node.global_position.snapped(Vector3.ONE * 0.01)), str(n.snapped(Vector3.ONE * 0.01)), str(node.scale.snapped(Vector3.ONE * 0.01)), (node as MeshInstance3D).material_override == fx().drip_mat])
		elif n.y > 0.8:
			out["floor"] += 1
		elif absf(n.y) < 0.4:
			out["wall"] += 1
		else:
			out["other"] += 1
	return out

func _run() -> void:
	print("== body shot in the kitchen, zombie with its back to the east wall")
	var z: Node3D = await setup(Vector3(4.6, 0, -2.0), Vector3(1.2, 0, -2.0))
	var res: Dictionary = await aim_and_fire(z.global_position + Vector3(0, 1.1, 0))
	check(not res.is_empty() and (res["collider"] as Node).is_in_group("zombies"), "the shot hits the zombie")
	await wait(150)
	var c := classify()
	var behind := 0
	var front := 0
	for node in c["list"]:
		if (node as Node3D).global_position.x > z.global_position.x + 0.2:
			behind += 1
		elif (node as Node3D).global_position.x < z.global_position.x - 0.2:
			front += 1
	check(c["list"].size() >= 8, "splats appear (%d: %d floor, %d wall, %d other)" % [c["list"].size(), c["floor"], c["wall"], c["other"]])
	check(c["floating"] == 0, "every splat sits on a real surface (%d floating)" % c["floating"])
	check(behind > front, "most ooze lands behind the zombie, along the bullet's path (%d behind, %d in front)" % [behind, front])
	check(c["wall"] > 0 and fx().stats["drips"] > 0, "ooze hits the wall behind it and runs (%d wall splats, %d drips)" % [c["wall"], fx().stats["drips"]])
	var drips_on_floor := 0
	for s in fx().splats:
		var node: MeshInstance3D = s["node"]
		if is_instance_valid(node) and node.material_override == fx().drip_mat and node.global_basis.z.normalized().y > 0.6:
			drips_on_floor += 1
	check(drips_on_floor == 0, "drips only on walls, never on the floor")
	var body_count: int = c["list"].size()

	print("== shot from the other side: splatter flips with the bullet")
	z = await setup(Vector3(1.0, 0, -2.0), Vector3(4.4, 0, -2.0))
	res = await aim_and_fire(z.global_position + Vector3(0, 1.1, 0))
	await wait(150)
	c = classify()
	behind = 0
	front = 0
	for node in c["list"]:
		if (node as Node3D).global_position.x < z.global_position.x - 0.2:
			behind += 1
		elif (node as Node3D).global_position.x > z.global_position.x + 0.2:
			front += 1
	check(behind > front, "shot westward: ooze now lands to the west (%d behind, %d in front)" % [behind, front])

	print("== headshot")
	z = await setup(Vector3(4.6, 0, -2.0), Vector3(1.2, 0, -2.0))
	var skel: Skeleton3D = z.get_node("Model/Skeleton3D")
	var head_pos := skel.to_global(skel.get_bone_global_pose(skel.find_bone("head")).origin) + Vector3(0, 0.14, 0)
	res = await aim_and_fire(head_pos)
	check(not res.is_empty() and res["collider"] is Area3D, "the shot hits the head hitbox")
	await wait(150)
	c = classify()
	check(c["list"].size() > body_count, "a headshot makes a bigger mess than a body shot (%d vs %d splats)" % [c["list"].size(), body_count])
	await wait(120)
	var pool_found := false
	for node in classify()["list"]:
		var n: Node3D = node
		if n.global_basis.z.y > 0.8 and n.scale.x > 0.6:
			pool_found = true
	check(pool_found, "a puddle spreads under the corpse")
	check(classify()["floating"] == 0, "still nothing floating")

	print("== through the boards")
	z = await setup(Vector3(6.9, 0, -2.4), Vector3(4.6, 0, -2.4))
	var w: Node3D = main.get_node("ShopGreybox/Windows/Window_A")
	res = await aim_and_fire(Vector3(6.1, 1.33, -2.4))  # dead centre of board 2 (boards sit just outside the wall)
	check(not res.is_empty() and (res["collider"] as Node).name.begins_with("Board"), "a shot into a board hits the board")
	await wait(30)
	check(fx() == null or fx().stats["sprays"] == 0, "no ooze from hitting wood")

	print("== limits")
	z = await setup(Vector3(4.6, 0, -2.0), Vector3(1.2, 0, -2.0))
	var f: Node = (load("res://core/ooze.gd") as GDScript).get_fx(main)
	var t0 := Time.get_ticks_usec()
	for i in 60:
		f.spray(Vector3(3.0, 1.2, -2.0), Vector3(1, 0, 0), Vector3(-1, 0, 0), 2.0, true)
		await physics_frame
	await wait(180)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	check(f.splat_count() <= f.MAX_SPLATS, "splats capped (%d of max %d)" % [f.splat_count(), f.MAX_SPLATS])
	check(f.droplets.size() == 0, "all droplets land or expire (%d in flight)" % f.droplets.size())
	print("     60 headshot sprays + settling: %.0f ms of headless sim (%d droplets simulated)" % [ms, f.stats["droplets"]])

	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
