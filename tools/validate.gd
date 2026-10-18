# Headless sanity checks for the greybox shop.
#   godot --headless --path . --script res://tools/validate.gd
# Exits with code 1 if any check fails.
extends SceneTree

var failures := 0
var player: CharacterBody3D

func check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

# Sweeps the player's capsule from a to b (feet positions). True = blocked.
func blocked(a: Vector3, b: Vector3) -> bool:
	player.global_position = a
	player.velocity = Vector3.ZERO
	return player.test_move(player.global_transform, b - a)

func _run() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	var shop: Node3D = main.get_node("ShopGreybox")
	for i in 90:
		await physics_frame

	print("Spawn & floor")
	check(player.is_on_floor(), "player lands on the shop floor (y=%.3f)" % player.global_position.y)
	check(absf(player.global_position.y) < 0.05, "player feet at floor height")

	print("Windows & boards")
	var windows := shop.get_node("Windows").get_children()
	check(windows.size() == 2, "two breach windows (found %d)" % windows.size())
	for w in windows:
		var boards: Array = w.get_node("Boards").get_children()
		check(boards.size() == 4, "%s has 4 boards" % w.name)
		var layer_ok := true
		for b in boards:
			layer_ok = layer_ok and (b as StaticBody3D).collision_layer == 2
		check(layer_ok, "%s boards on 'barricades' layer" % w.name)
		for m in ["Breach_Point", "Repair_Point", "Lane_Spawn"]:
			check(w.has_node(m), "%s has %s" % [w.name, m])

	print("Interior doorways are walkable (capsule sweeps)")
	# Shop(-3,-2.4) Kitchen(3,-2.4) Office(-3,2.4) Store(3,2.4)
	check(not blocked(Vector3(-1.5, 0.02, -2.4), Vector3(1.5, 0.02, -2.4)), "shop <-> kitchen")
	check(not blocked(Vector3(-3.0, 0.02, -1.5), Vector3(-3.0, 0.02, 1.5)), "shop <-> back office")
	check(not blocked(Vector3(3.0, 0.02, -1.5), Vector3(3.0, 0.02, 1.5)), "kitchen <-> storeroom")
	check(not blocked(Vector3(-1.5, 0.02, 2.4), Vector3(1.5, 0.02, 2.4)), "back office <-> storeroom")
	check(not blocked(Vector3(-4.5, 0.02, -3.5), Vector3(-1.2, 0.02, -1.0)), "open walk across shop floor")

	print("Furniture leaves the working spots clear")
	check(not blocked(Vector3(3.0, 0.02, -2.4), Vector3(5.0, 0.02, -2.4)), "kitchen: reach window A repair spot")
	check(not blocked(Vector3(-3.0, 0.02, 2.4), Vector3(-5.0, 0.02, 2.4)), "office: reach window B repair spot")
	check(not blocked(Vector3(-3.0, 0.02, -1.6), Vector3(-3.0, 0.02, -3.6)), "shop: walk up to the service counter")
	check(not blocked(Vector3(3.0, 0.02, 2.4), Vector3(3.0, 0.02, 4.2)), "storeroom: reach the delivery door")
	check(not blocked(Vector3(3.0, 0.02, -2.4), Vector3(2.6, 0.02, -3.4)), "kitchen: step up to the griddle")
	check(blocked(Vector3(-3.0, 0.02, -3.6), Vector3(-3.0, 0.02, -4.4)), "counter is solid")
	check(blocked(Vector3(3.0, 0.02, 2.4), Vector3(5.3, 0.02, 2.4)), "storeroom shelving is solid")

	print("Walls block where they should")
	check(blocked(Vector3(-1.5, 0.02, -4.0), Vector3(1.5, 0.02, -4.0)), "partition blocks away from door")
	check(blocked(Vector3(-3.0, 0.02, -3.5), Vector3(-3.0, 0.02, -6.5)), "can't walk out through the service hatch")
	check(blocked(Vector3(4.5, 0.02, -2.4), Vector3(7.5, 0.02, -2.4)), "can't walk out of window A (wall below sill)")
	check(blocked(Vector3(4.5, 1.0, -2.4), Vector3(7.5, 1.0, -2.4)), "window A boards block at sill height")
	check(blocked(Vector3(-4.5, 1.0, 2.4), Vector3(-7.5, 1.0, 2.4)), "window B boards block at sill height")
	check(blocked(Vector3(3.0, 0.02, 3.5), Vector3(3.0, 0.02, 6.5)), "delivery door is closed")

	print("Boards removed -> window becomes a breach")
	var space0 := player.get_world_3d().direct_space_state
	var through := PhysicsRayQueryParameters3D.create(Vector3(4.5, 1.35, -2.4), Vector3(8.0, 1.35, -2.4))
	through.collision_mask = 2
	var before := space0.intersect_ray(through)
	check(not before.is_empty() and (before["collider"] as Node).name == "Board_2", "ray at board height hits Board_2")
	for b in shop.get_node("Windows/Window_A/Boards").get_children():
		(b as StaticBody3D).collision_layer = 0
	await physics_frame
	through.collision_mask = 1 | 2
	check(space0.intersect_ray(through).is_empty(), "window A fully open once its boards are gone")

	print("Sight lines")
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(3.0, 1.6, -2.4), Vector3(14.0, 1.6, -2.4))
	q.collision_mask = 1 | 2
	var res := space.intersect_ray(q)
	check(res.is_empty(), "clear line of fire from kitchen to lane A (boards disabled)")
	q = PhysicsRayQueryParameters3D.create(Vector3(-3.0, 1.8, 2.4), Vector3(-14.0, 1.8, 2.4))
	q.collision_mask = 1 | 2
	res = space.intersect_ray(q)
	check(res.is_empty(), "eye-level gap between window B boards (y=1.8)")

	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
