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
	check(econ.cash == 0 and econ.buns == 8 and econ.toppings == 8 and econ.mushrooms == 0, "start: $0, 8 buns, 8 toppings, empty store")
	check(main.grill.slot_count() == 2, "the starter grill has 2 slots")

	print("== kill -> collect")
	var z: Node3D = main.spawn_zombie(main.get_node("ShopGreybox/Windows/Window_A"))
	z.state = 3
	z.global_position = Vector3(1.0, 0.05, -1.4)
	player.global_position = Vector3(-2.8, 0.05, 3.0)
	await physics_frame
	seed(3)
	z.take_damage(999.0)
	await wait(1.5)
	check(econ.cash == 2, "a kill pays $2 (cash $%d)" % econ.cash)
	var picks := get_nodes_in_group("pickups")
	check(picks.size() == 1, "and drops a mushroom")
	if not picks.is_empty():
		player.global_position = (picks[0] as Node3D).global_position + Vector3(1.0, -0.4, 0)
		await wait(1.0)
	check(player.mushrooms == 1, "walking over it picks it up (carrying %s)" % str(player.carried))
	var kind_got := ""
	for k in player.carried:
		if player.carried[k] > 0:
			kind_got = k

	print("== store")
	var f: Node = await look_at_station(main.storage, Vector3(1.5, 0, 1.4))
	check(f == main.storage, "looking at the bin focuses it")
	check("store 1 mushroom" in main.storage.prompt(player), "prompt: '%s'" % main.storage.prompt(player))
	player.use_focus()
	check(player.mushrooms == 0 and econ.stock[kind_got] == 1, "E stores it by kind (stock %s)" % str(econ.stock))
	# drops by enemy: Shamblers mostly brown, Scuttlers blue or red
	var shambler_kinds := {}
	var scuttler_kinds := {}
	for i in 200:
		var sk: String = main.drop_kind(null)
		shambler_kinds[sk] = shambler_kinds.get(sk, 0) + 1
	var sc: Node = main.spawn_scuttler(main.get_node("ShopGreybox/Windows/Window_B"))
	for i in 200:
		var k: String = main.drop_kind(sc)
		scuttler_kinds[k] = scuttler_kinds.get(k, 0) + 1
	sc.queue_free()
	check(shambler_kinds.get("brown", 0) > 120 and shambler_kinds.has("blue") and not shambler_kinds.has("red"), "Shamblers drop mostly common brown, some blue: %s" % str(shambler_kinds))
	check(not scuttler_kinds.has("brown") and scuttler_kinds.has("red") and scuttler_kinds.get("blue", 0) > scuttler_kinds.get("red", 0), "Scuttlers drop blue, sometimes red: %s" % str(scuttler_kinds))
	econ.stock = {"brown": 0, "blue": 0, "red": 0}
	econ.store_mushrooms(3, "brown")
	econ.store_mushrooms(2, "blue")
	econ.store_mushrooms(1, "red")

	print("== cook")
	f = await look_at_station(main.grill, Vector3(2.1, 0, -3.2))
	check(f == main.grill and "place patty" in main.grill.prompt(player), "at the grill: '%s'" % main.grill.prompt(player))
	player.use_focus()
	var labels: Array = player.menu_options.map(func(o): return o["label"])
	check(labels == ["Common patty  x3", "Blue patty  x2", "Red patty  x1", "Cancel"], "patty menu: %s" % str(labels))
	player.choose(1)     # key 2: blue
	check(main.grill.state_of(0) == "raw" and main.grill.kind_of(0) == "blue" and econ.stock["blue"] == 1, "key 2 puts a blue patty on")
	player.use_focus()
	player.use_focus()   # E: first available (common)
	check(main.grill.state_of(1) == "raw" and main.grill.kind_of(1) == "brown", "E puts the first available (common) on")
	player.use_focus()
	var full: Array = player.menu_options.map(func(o): return "%s%s" % [o["label"], "" if o["enabled"] else " (off)"])
	check(not player.menu_options[0]["enabled"] and "grill full" in full[0], "two slots: now full %s" % str(full))
	player.use_focus()   # only Cancel is enabled
	check(player.menu_station == null, "E on a full grill picks Cancel")
	await wait(2.0)
	check(main.grill.state_of(0) == "cooking", "cooking after a second")
	var rang := [false]
	main.grill.patty_state.connect(func(_i, st): if st == "ready": rang[0] = true)
	await wait(4.2)
	check(main.grill.state_of(0) == "ready" and rang[0], "ready at 6 s (bell)")

	print("== bag at the prep bench")
	var car: Node3D
	main.hatch.next_order = "blue"
	car = main.hatch.spawn_customer()
	check(car.order == "blue", "a customer pulls in wanting a BLUE burger")
	f = await look_at_station(main.bench, Vector3(0.8, 0, -3.3))
	check(f == main.bench and main.bench.prompt(player) == "E  bag burger", "at the prep bench: '%s'" % main.bench.prompt(player))
	player.use_focus()
	check(player.held == "burger" and player.held_burger["kind"] == "blue" and player.held_burger["quality"] == "perfect", "one press bags the ordered blue patty, fresh: %s" % str(player.held_burger))
	check(econ.buns == 7 and econ.toppings == 7 and main.grill.state_of(0) == "", "it used a bun, a topping and that patty")
	await wait(5.5)

	print("== serve")
	check(car.state == "waiting", "the customer is at the hatch")
	f = await look_at_station(main.hatch, Vector3(-3.0, 0, -3.9))
	check(f == main.hatch and "serve BLUE burger" in main.hatch.prompt(player) and "PERFECT" in main.hatch.prompt(player), "at the hatch: '%s'" % main.hatch.prompt(player))
	var before: int = econ.cash
	player.use_focus()
	check(econ.cash - before == 36 and player.held == "", "PERFECT: $30 + $6 tip (got $%d)" % (econ.cash - before))
	await wait(4.5)
	check(not is_instance_valid(car), "the car drives off")
	# the common patty: say it has sat READY for 6 s (GOOD), then bag it
	main.hatch.next_order = "red"
	car = main.hatch.spawn_customer()
	await wait(5.5)
	main.grill.slots[1]["t"] = 6.0 + 6.0
	await wait(0.1)
	main.bench.bag(player)
	check(player.held_burger.get("kind", "") == "brown" and player.held_burger.get("quality", "") == "good", "no red ready: the bench bags the waiting common patty, now GOOD: %s" % str(player.held_burger))
	check(not main.hatch.serve(player) and "WRONG BURGER" in main.hatch.prompt(player), "the red customer won't take a common burger")
	car.leave(false)
	await wait(4.5)
	main.hatch.next_order = "brown"
	car = main.hatch.spawn_customer()
	await wait(5.5)
	before = econ.cash
	main.hatch.serve(player)
	check(econ.cash - before == 33, "GOOD: $30 + $3 tip (got $%d)" % (econ.cash - before))
	await wait(4.5)
	# standard and burnt
	econ.store_mushrooms(2, "brown")
	econ.store_mushrooms(1, "red")
	main.grill.add_patty("brown")
	main.grill.add_patty("red")
	main.grill.slots[1]["t"] = 19.0
	await wait(0.2)
	check(main.grill.state_of(1) == "burnt", "a patty left past 18 s burns")
	main.grill.slots[0]["t"] = 6.0 + 11.5
	await wait(0.1)
	main.bench.bag(player)
	check(player.held_burger.get("quality", "") == "standard", "bagged 11.5 s after it was ready, before it burns: STANDARD, still sellable (%s)" % str(player.held_burger))
	player.set_held("")
	check("salvage" in main.bench.prompt(player), "with only a burnt patty left, the bench offers salvage: '%s'" % main.bench.prompt(player))
	main.bench.bag(player)
	check(player.held_burger.get("quality", "") == "burnt", "bagged as burnt salvage")
	main.hatch.next_order = "blue"
	car = main.hatch.spawn_customer()
	await wait(5.5)
	before = econ.cash
	check(main.hatch.serve(player) and econ.cash - before == 15, "any customer takes salvage for $15")
	await wait(4.5)
	check(Economy_q(3.0, false) == "perfect" and Economy_q(6.0, false) == "good" and Economy_q(10.0, false) == "standard", "quality: perfect <= 4 s ready, good <= 8 s, standard until it burns")
	var car2: Node3D = main.hatch.spawn_customer()
	car2.patience = 3.0
	before = econ.cash
	await wait(13.0)
	check(not is_instance_valid(car2) and econ.cash == before, "an unserved car leaves after its patience: no pay, no penalty")

	print("== burnt alarm")
	var alarms := [0]
	var grill_node: Node = main.grill
	main.grill.add_patty("brown")
	main.grill.slots[0]["t"] = 17.9
	var t0 := 0.0
	var played := false
	while t0 < 1.0:
		await physics_frame
		t0 += DT
		for n in root.get_children():
			if n is AudioStreamPlayer3D and (n as AudioStreamPlayer3D).stream == (load("res://game/sfx.gd") as GDScript).stream("alarm"):
				played = true
	check(played, "a burning patty sounds the alarm")
	main.grill.scrape()

	print("== the shop terminal")
	f = await look_at_station(main.terminal, Vector3(-2.9, 0, 3.2))
	check(f == main.terminal, "looking at the CRT focuses the shop terminal")
	player.use_focus()
	var shop_labels := func() -> Array: return player.menu_options.map(func(o): return "%s%s" % [o["label"], "" if o["enabled"] else " (off)"])
	var top: Array = shop_labels.call()
	check(top == ["Weapons and ammo", "Kitchen supplies", "Upgrades", "Close"], "top menu: %s" % str(top))
	player.use_focus()            # E: the first page
	var weapons_page: Array = shop_labels.call()
	check(main.terminal.page == "weapons" and "pistol rounds" in weapons_page[0] and "Pump shotgun" in weapons_page[1] and weapons_page[2] == "Back", "weapons page: %s" % str(weapons_page))
	var reserve: int = gun.reserve
	before = econ.cash
	player.use_focus()            # E: pistol rounds
	check(econ.cash == before - 12 and gun.reserve == reserve + 24, "24 rounds for $12 (cash $%d, reserve %d)" % [econ.cash, gun.reserve])
	check(player.menu_station == main.terminal and main.terminal.page == "weapons", "the page stays open after buying")
	econ.add_cash(150)
	var n_weapons: int = player.weapons.size()
	player.choose(1)
	var sg: Node = player.weapon_named("SHOTGUN")
	check(sg != null and player.weapons.size() == n_weapons + 1 and player.weapon_index == n_weapons, "the shotgun for $150 goes in slot %d and is drawn" % (n_weapons + 1))
	check(sg != null and sg.mag == 6 and sg.reserve == 6, "it comes loaded: 6 in the tube, 6 spare")
	econ.add_cash(30)
	player.choose(1)
	check(sg != null and sg.reserve == 18, "then the slot sells 12 shells for $30 (spare %d)" % (sg.reserve if sg else -1))
	player.choose(2)              # Back
	check(main.terminal.page == "" and player.menu_options.size() == 4, "Back returns to the top menu")
	econ.add_cash(40 + 110)
	var buns0: int = econ.buns
	player.choose(1)              # supplies
	player.choose(0)
	check(econ.buns == buns0 + 5 and econ.toppings == econ.buns, "5 buns + 5 toppings for $40 (buns %d, toppings %d)" % [econ.buns, econ.toppings])
	player.choose(1)
	check(econ.buns == buns0 + 20, "the big box: 15 + 15 for $110 (buns %d)" % econ.buns)
	player.choose(2)
	print("== upgrades")
	player.choose(2)
	var up: Array = shop_labels.call()
	check(main.terminal.page == "upgrades" and "Reinforced Grill" in up[0] and "Warming tray" in up[1] and "Drive-thru bell" in up[2], "upgrades page: %s" % str(up))
	var slots_seen := [main.grill.slot_count()]
	for i in 3:
		econ.add_cash(300)
		player.choose(0)
		slots_seen.append(main.grill.slot_count())
	check(slots_seen == [2, 3, 4, 4] and main.grill.ready_window() == 20.0, "Reinforced 3 slots, Restaurant 4, Apocalypse 4 with a 20 s ready window: %s" % str(slots_seen))
	var maxed: Array = shop_labels.call()
	check("(maxed)" in maxed[0] and "(off)" in maxed[0], "fully upgraded: no more grills on sale %s" % str(maxed[0]))
	econ.add_cash(220)
	player.choose(1)
	player.choose(2)
	check(econ.has_tray and econ.has_bell and "installed" in shop_labels.call()[1] and "installed" in shop_labels.call()[2], "the warming tray and the bell, once each: %s" % str(shop_labels.call()))
	player.close_menu()
	await wait(0.1)
	check(main.terminal.page == "", "walking off resets the terminal to its top menu")

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

func Economy_q(ready_for: float, burnt: bool) -> String:
	return (load("res://game/economy.gd") as GDScript).quality_for(ready_for, burnt)
