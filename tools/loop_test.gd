# The first playable loop (docs/GAME_DESIGN.md "vertical slice"), headless:
#   godot --headless --path . --fixed-fps 60 --script res://tools/loop_test.gd
# kill -> collect -> store -> cook -> bag -> serve -> cash -> buy ammo -> waves
extends SceneTree

const DT := 1.0 / 60.0
var main: Node3D
var player: CharacterBody3D
var cam: Camera3D
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1

func fresh(auto := false) -> void:
	if main:
		main.queue_free()
		await process_frame
		for n in root.get_children():
			if n is RigidBody3D or n.name == "OozeFX" or n is AudioStreamPlayer or n is AudioStreamPlayer3D:
				n.queue_free()
		await process_frame
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", auto)
	root.add_child(main)
	player = main.get_node("Player")
	player.max_health = 1e9
	player.health = 1e9
	cam = player.get_node("Head/Camera3D")
	for i in 10:
		await physics_frame

func wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await physics_frame
		t += DT

# stand at `stand`, look at the station's zone; returns the focused station
func look_at_station(station: Node3D, stand: Vector3) -> Node:
	player.global_position = stand + Vector3(0, 0.05, 0)
	await physics_frame
	var zone := station.get_node("Zone") as Node3D
	cam.look_at(zone.global_position, Vector3.UP)
	await physics_frame
	await physics_frame
	return player.focus

func _run() -> void:
	await fresh()
	var econ: Node = main.economy
	var gun: Node = player.get_node("Head/Camera3D/TestGun")
	check(econ.cash == 0 and econ.buns == 12 and econ.mushrooms == 0, "start: $0, 12 buns, empty store")

	print("== kill -> collect")
	var z: Node3D = main.spawn_zombie(main.get_node("ShopGreybox/Windows/Window_A"))
	z.state = 3
	z.global_position = Vector3(1.0, 0.05, -1.4)
	player.global_position = Vector3(-2.8, 0.05, 3.0)
	await physics_frame
	z.take_damage(999.0)
	await wait(1.5)
	check(econ.cash == 2, "a kill pays $2 (cash $%d)" % econ.cash)
	var picks := get_nodes_in_group("pickups")
	check(picks.size() == 1, "and drops a mushroom")
	if not picks.is_empty():
		player.global_position = (picks[0] as Node3D).global_position + Vector3(1.0, -0.4, 0)
		await wait(1.0)
	check(player.mushrooms == 1, "walking over it picks it up (carrying %d)" % player.mushrooms)

	print("== store")
	var f: Node = await look_at_station(main.storage, Vector3(1.5, 0, 1.4))
	check(f == main.storage, "looking at the bin focuses it")
	check("store 1 mushroom" in main.storage.prompt(player), "prompt: '%s'" % main.storage.prompt(player))
	player.use_focus()
	check(player.mushrooms == 0 and econ.mushrooms == 1, "E stores it (carried %d, stored %d)" % [player.mushrooms, econ.mushrooms])

	print("== cook")
	f = await look_at_station(main.grill, Vector3(2.1, 0, -3.2))
	check(f == main.grill, "looking at the grill focuses it")
	player.use_focus()
	check(player.menu_station == main.grill, "E opens the grill menu")
	var labels: Array = player.menu_options.map(func(o): return o["label"])
	check(labels.size() == 1 and "Common patty  x1" in labels[0], "menu shows the patties: %s" % str(labels))
	player.use_focus()
	check(econ.mushrooms == 0 and main.grill.state_of(0) == "raw", "E again puts a raw patty on (store %d, slot 0 %s)" % [econ.mushrooms, main.grill.state_of(0)])
	await wait(2.0)
	check(main.grill.state_of(0) == "cooking", "cooking after a second")
	var rang := [false]
	main.grill.patty_state.connect(func(_i, s): if s == "ready": rang[0] = true)
	await wait(4.2)
	check(main.grill.state_of(0) == "ready" and rang[0], "ready at 6 s")
	# a second patty left to burn
	econ.store_mushrooms(1)
	player.use_focus()
	var opts: Array = player.menu_options.map(func(o): return o["label"])
	check(opts.size() == 2 and "Bag burger" in opts[0], "with a ready patty, bagging comes first: %s" % str(opts))
	player.choose(1)   # key 2: the patty
	check(main.grill.state_of(1) == "raw", "key 2 picks the second option (a second patty)")
	player.use_focus()
	player.use_focus()  # E on the first option: bag it
	check(player.held == "burger" and econ.buns == 11 and main.grill.state_of(0) == "", "bagging takes a bun and the patty (holding '%s', buns %d)" % [player.held, econ.buns])
	await wait(18.5)
	check(main.grill.state_of(1) == "burnt", "a patty left 18 s burns")
	player.use_focus()
	var burnt_opt: Array = player.menu_options.map(func(o): return o["label"])
	check("Scrape burnt patty" in burnt_opt, "the menu offers to scrape it")
	player.choose(burnt_opt.find("Scrape burnt patty"))
	check(main.grill.state_of(1) == "", "scraped off")

	print("== serve")
	var car: Node3D = main.hatch.spawn_customer()
	check(main.hatch.prompt(player).contains("pulling in"), "a car pulls in")
	var a0: float = car.wheel_angle()
	await wait(1.0)
	check(absf(wrapf(car.wheel_angle() - a0, -PI, PI)) > 0.1, "its wheels roll while it drives in")
	await wait(4.5)
	check(car.state == "waiting", "it stops at the hatch and waits")
	var a1: float = car.wheel_angle()
	await wait(0.5)
	check(is_equal_approx(car.wheel_angle(), a1), "and stop turning when it stops")
	f = await look_at_station(main.hatch, Vector3(-3.0, 0, -3.9))
	check(f == main.hatch and "serve burger" in main.hatch.prompt(player), "at the hatch with a burger: '%s'" % main.hatch.prompt(player))
	var before: int = econ.cash
	player.use_focus()
	check(econ.cash - before == 36 and player.held == "", "served quickly: $30 + $6 tip (got $%d)" % (econ.cash - before))
	await wait(4.5)
	check(not is_instance_valid(car), "the car drives off")
	var car2: Node3D = main.hatch.spawn_customer()
	car2.patience = 3.0
	before = econ.cash
	await wait(13.0)
	check(not is_instance_valid(car2) and econ.cash == before, "an unserved car leaves after its patience: no pay, no penalty")
	check(Economy_tip(0.5) == 2 and Economy_tip(0.9) == 0, "tips: $2 served normally, $0 just before leaving")

	print("== buy ammo")
	f = await look_at_station(main.terminal, Vector3(-2.9, 0, 3.2))
	check(f == main.terminal, "looking at the CRT focuses the shop terminal")
	player.use_focus()
	var shop_opts: Array = player.menu_options.map(func(o): return "%s%s" % [o["label"], "" if o["enabled"] else " (off)"])
	check(shop_opts.size() == 2 and not player.menu_options[1]["enabled"], "menu: %s" % str(shop_opts))
	var reserve: int = gun.reserve
	before = econ.cash
	player.use_focus()
	check(econ.cash == before - 12 and gun.reserve == reserve + 24, "24 rounds for $12 (cash $%d, reserve %d)" % [econ.cash, gun.reserve])
	econ.add_cash(40)
	player.use_focus()
	player.choose(1)
	check(econ.buns == 21, "10 buns for $40 (buns %d)" % econ.buns)

	print("== ammo")
	player.switch_weapon(0)
	await wait(0.3)
	var shots := 0
	for i in 14:
		if not gun.shoot().is_empty() or gun.mag >= 0:
			shots += 1
	check(gun.mag == 0 and gun.is_reloading(), "the magazine empties after 12 and reloads (mag %d)" % gun.mag)
	check(gun.shoot().is_empty(), "no shot while reloading")
	await wait(1.3)
	check(gun.mag == 12, "reloaded to 12 from the reserve (reserve %d)" % gun.reserve)

	print("== auto-collect")
	main.auto_collect = true
	main.MushroomPickupScript.auto_collect = true
	player.global_position = Vector3(-2.8, 0.05, 3.0)
	var carried: int = player.mushrooms
	main.drop_pickup(Vector3(3.0, 0.05, -3.0))   # another room
	await wait(4.0)
	check(player.mushrooms == carried + 1, "with auto-collect on, a mushroom in another room flies to you")
	main.MushroomPickupScript.auto_collect = false

	print("== waves")
	await fresh(true)
	var spawned := []
	var killed_at := []
	var wave2 := [false]   # lambdas capture locals by value: box it
	main.wave_started.connect(func(n): if n == 2: wave2[0] = true)
	var t := 0.0
	var wave1_size: int = main.wave_size(1)
	while t < 120.0 and not wave2[0]:
		await physics_frame
		t += DT
		for e in get_nodes_in_group("zombies"):
			if not spawned.has(e):
				spawned.append(e)
				killed_at.append(t)
				e.take_damage(9999.0)
	check(spawned.size() == wave1_size, "wave 1 sends %d enemies (sent %d)" % [wave1_size, spawned.size()])
	var gaps := []
	for i in range(1, killed_at.size()):
		gaps.append(snappedf(killed_at[i] - killed_at[i - 1], 0.1))
	check(gaps.all(func(g): return absf(g - 11.0) < 0.2), "one every 11 s in wave 1: %s" % str(gaps))
	var break_len: float = t - killed_at[-1]
	check(wave2[0] and absf(break_len - 20.0) < 1.5, "wave 2 starts after a %.1f s break" % break_len)
	check(main.wave_size(2) == 8 and main.wave_interval(2) < 11.0, "wave 2 is bigger (%d) and faster (every %.0f s)" % [main.wave_size(2), main.wave_interval(2)])

	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func Economy_tip(frac: float) -> int:
	return (load("res://game/economy.gd") as GDScript).tip_for(frac)
