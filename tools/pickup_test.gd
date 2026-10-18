# Mushroom pickup scenarios (headless):
#   godot --headless --path . --fixed-fps 60 --script res://tools/pickup_test.gd
extends SceneTree

const DT := 1.0 / 60.0
const Palette = preload("res://core/palette.gd")
var main: Node3D
var player: CharacterBody3D
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1

func fresh(ppos: Vector3) -> void:
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
	player.max_health = 1e9
	player.health = 1e9
	for i in 10:
		await physics_frame
	player.global_position = ppos + Vector3(0, 0.05, 0)
	await physics_frame

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func pickups() -> Array:
	return root.get_tree().get_nodes_in_group("pickups")

func floor_y(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1, 0), at - Vector3(0, 2, 0), 1)
	var hit := main.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else -99.0

func _run() -> void:
	for kind in ["Shambler", "Scuttler"]:
		print("== a dead %s drops a mushroom" % kind)
		await fresh(Vector3(-2.8, 0, 3.0))   # back office, well out of reach
		var w: Node3D = main.get_node("ShopGreybox/Windows/Window_A")
		var z: Node3D = main.spawn_zombie(w) if kind == "Shambler" else main.spawn_scuttler(w)
		z.state = 3
		z.global_position = Vector3(1.0, 0.05, -1.4)
		await frames(2)
		var where := z.global_position
		check(pickups().is_empty(), "nothing before it dies")
		z.take_damage(999.0)
		await frames(90)
		var ps := pickups()
		check(ps.size() == 1, "exactly one mushroom drops (%d)" % ps.size())
		if ps.is_empty():
			continue
		var p: Node3D = ps[0]
		var h := p.global_position.y - floor_y(p.global_position)
		check(h > 0.3 and h < 0.55, "it floats above the floor (centre %.2f m up)" % h)
		check(Vector2(p.global_position.x - where.x, p.global_position.z - where.z).length() < 0.9, "next to the body")
		var r0 := p.rotation.y
		var ys := []
		for i in 60:
			await physics_frame
			ys.append(p.global_position.y)
		var turned := absf(wrapf(p.rotation.y - r0, -PI, PI))
		check(turned > 1.0 and turned < 2.5, "it spins (%.1f rad in 1 s)" % turned)
		check(ys.max() - ys.min() > 0.03, "and bobs (%.2f m)" % (ys.max() - ys.min()))
		var light := p.get_node("Glow") as OmniLight3D
		check(light != null and light.light_color.is_equal_approx(Palette.AMBER_GLOW) and light.light_energy > 0.3 and light.light_energy < 1.2, "with a soft orange glow (energy %.2f)" % (light.light_energy if light else 0.0))
		var mi := p.get_node("Mesh") as MeshInstance3D
		var mat := mi.material_override as StandardMaterial3D
		check(mat != null and mat.emission_enabled and mat.next_pass is ShaderMaterial, "glowing spots and an orange halo on the model")
		check(p.global_position.distance_to(p.get("_home")) < 0.1, "it stays put while you're far away")
		# walk up to it
		player.global_position = p.global_position + Vector3(1.6, 0, 0)
		player.global_position.y = floor_y(p.global_position) + 0.05
		var t := 0.0
		while t < 3.0 and is_instance_valid(p) and p.is_collectable():
			await physics_frame
			t += DT
		await frames(30)
		check(player.mushrooms == 1 and not is_instance_valid(p), "walking up collects it (%.1f s, count %d)" % [t, player.mushrooms])
		var hud: Label = main.get("_hud")["health"]
		check("MUSHROOMS 1" in hud.text, "HUD shows it: '%s'" % hud.text)

	print("== dropped outside a window")
	await fresh(Vector3(-2.8, 0, 3.0))
	var win: Node3D = main.get_node("ShopGreybox/Windows/Window_A")
	var z2: Node3D = main.spawn_scuttler(win)
	var t2 := 0.0
	while t2 < 20.0 and z2.state != 1:
		await physics_frame
		t2 += DT
	z2.take_damage(999.0)
	await frames(80)
	var outside := pickups()
	check(outside.size() == 1 and absf((outside[0] as Node3D).global_position.x) > 5.0, "a Scuttler killed while ramming drops its mushroom outside")
	player.global_position = win.repair_point() + Vector3(0, 0.05, 0)
	var t3 := 0.0
	while t3 < 4.0 and player.mushrooms == 0:
		await physics_frame
		t3 += DT
	if player.mushrooms == 0 and not outside.is_empty():
		var pp := (outside[0] as Node3D).global_position
		var chest := player.global_position + Vector3(0, 0.9, 0)
		var hit := main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(pp, chest, 1))
		print("    debug: pickup %s chest %s dist %.2f hit %s" % [pp, chest, pp.distance_to(chest), hit.get("collider", null)])
	check(player.mushrooms == 1, "standing at the window pulls it in through the boards (%.1f s)" % t3)

	print("== several at once")
	await fresh(Vector3(-2.8, 0, 3.0))
	for i in 4:
		main.drop_pickup(Vector3(0.5 + 0.6 * i, 0.05, -1.4))
	await frames(60)
	check(pickups().size() == 4, "four kills, four mushrooms")
	player.global_position = Vector3(1.4, 0.05, -1.4)
	await frames(180)
	check(player.mushrooms == 4 and pickups().is_empty(), "walking through them picks them all up (%d)" % player.mushrooms)

	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
