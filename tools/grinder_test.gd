# Grinder deposit wiring: game/grinder_station.gd + game/storage_bin.gd driving
# Codex's cosmetic presentation/kitchen/grinder.gd.
#   godot --headless --path . --fixed-fps 60 --script res://tools/grinder_test.gd
extends SceneTree
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func finish_cycle(g: Node) -> void:
	for i in 40:
		g.advance(0.05)

func run() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	main.hatch.auto = false
	await process_frame
	await process_frame
	var player: Node = main.player
	player.set_physics_process(false)
	var e: Node = main.economy
	e.stock = {"brown": 0, "blue": 0, "red": 0}
	var st: Node = main.grinder_station
	var g: Node3D = get_first_node_in_group("mushroom_grinder") as Node3D
	check(st != null and g != null, "grinder station and Codex grinder both exist")
	check(get_nodes_in_group("mushroom_grinder").size() == 1, "exactly one grinder model (no duplicate)")
	check(st.global_position.distance_to(g.global_position) < 0.01, "station sits on the grinder")
	var zone: Area3D = st.get_node("Zone")
	check(zone.get_meta("station") == st and zone.collision_layer == 32, "look-zone on the interact layer")

	# nothing carried: no stock, no animation
	check("GRINDER" in st.prompt(player), "idle prompt shows stock")
	st.interact(player)
	check(not g.busy and st.deposits == 0, "empty deposit does nothing")

	# a deposit: same stock and yield as the storeroom bin, one cycle
	player.add_mushrooms(2, "blue")
	player.add_mushrooms(1, "red")
	check("grind 3 mushrooms" in st.prompt(player), "carrying prompt counts mushrooms")
	st.interact(player)
	check(int(e.stock["blue"]) == 2 and int(e.stock["red"]) == 1 and player.mushrooms == 0, "deposit stores every carried mushroom, one each")
	check(g.busy and st.deposits == 1, "successful deposit starts the grinder")

	# busy: refused, nothing lost or doubled
	player.add_mushrooms(1, "brown")
	check(st.prompt(player) == "GRINDING...", "busy prompt")
	st.interact(player)
	check(player.mushrooms == 1 and int(e.stock["brown"]) == 0 and st.deposits == 1, "E while grinding keeps the mushroom in hand")
	st.interact(player)
	check(st.deposits == 1, "repeated E while busy never double-deposits")
	finish_cycle(g)
	check(not g.busy, "cycle ends on its own")
	st.interact(player)
	check(int(e.stock["brown"]) == 1 and player.mushrooms == 0 and g.busy, "after the cycle the held mushroom grinds normally")
	finish_cycle(g)

	# the storeroom bin still works and plays the grinder when free
	player.add_mushrooms(2, "brown")
	main.storage.interact(player)
	check(int(e.stock["brown"]) == 3 and g.busy, "storeroom deposit also plays the grinder")
	# ...and never waits on it
	player.add_mushrooms(1, "blue")
	main.storage.interact(player)
	check(int(e.stock["blue"]) == 3 and player.mushrooms == 0, "storeroom deposit stores even while grinder is busy")
	finish_cycle(g)
	print("\n%d failure(s)" % failures)
	quit(1 if failures else 0)
