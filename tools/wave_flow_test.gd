# Wave flow and drive-thru QoL (main.gd, game/customer_window.gd):
# groups, one new enemy type per wave, cap retry, break length, wave banners
# and summaries, early multi-burger patience, supply and missing-mushroom warnings.
#   godot --headless --path . --fixed-fps 60 --script res://tools/wave_flow_test.gd
extends SceneTree
var failures := 0
var toasts: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func kinds_in_wave(main: Node, n: int) -> Dictionary:
	var out := {}
	for i in main.wave_size(n):
		var scene: PackedScene = main.enemy_scene_for(n, i + 1 + 40 * n)
		var kind: String = scene.resource_path.get_slice("/", 3)
		if scene == main.SHAMBLER or scene == main.HOLLOWHEAD:
			kind = "common"
		out[kind] = int(out.get(kind, 0)) + 1
	return out

func run() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	await process_frame
	main.hatch.auto = false
	var player: Node = main.player
	player.set_physics_process(false)
	var orig_toast: Callable = main._toast
	# capture toasts by watching the HUD label text after each call
	var hud: Dictionary = main._hud

	# --- group sizes and pacing ---
	check(main.group_size(1) == 1 and main.group_size(3) == 1 and main.group_size(4) == 2 and main.group_size(7) == 3 and main.group_size(10) == 4 and main.group_size(30) == 4, "waves 1-3 single file, 4-6 pairs, 7-9 threes, then fours")
	check(main.break_length(1) == 20.0 and main.break_length(3) == 24.0 and main.break_length(19) == 30.0, "break grows 2 s a wave from 20 s to 30 s")
	# --- staged enemy types ---
	var w1: Dictionary = kinds_in_wave(main, 1)
	check(w1.keys() == ["common"], "wave 1 is Shamblers and Hollowheads only (%s)" % str(w1))
	check(kinds_in_wave(main, 2).has("scuttler") and not kinds_in_wave(main, 2).has("scientist") and not kinds_in_wave(main, 2).has("lancer"), "wave 2 adds Scuttlers only")
	check(kinds_in_wave(main, 3).has("scientist") and not kinds_in_wave(main, 3).has("lancer"), "wave 3 adds Scientists")
	check(kinds_in_wave(main, 4).has("lancer"), "wave 4 adds Lancers")
	check("SCUTTLERS" in main.wave_banner(2) and "SCIENTISTS" in main.wave_banner(3) and "LANCERS" in main.wave_banner(4), "each new type is announced")
	check(main.wave_banner(1) == "WAVE 1" and "IN THREES" in main.wave_banner(7), "plain banner, and groups announced (%s)" % main.wave_banner(7))

	# --- late pressure, bounded stats, exact early rotation ---
	var scaling: Script = load("res://game/wave_scaling.gd")
	check(scaling.health_multiplier(6) == 1.0 and is_equal_approx(scaling.health_multiplier(7), 1.04), "health scaling begins on wave 7")
	check(is_equal_approx(scaling.health_multiplier(100), 1.6) and is_equal_approx(scaling.speed_multiplier(100), 1.25), "health and speed caps hold")
	for n in range(1, 5):
		for slot in range(1, 121):
			var expected: PackedScene = main.HOLLOWHEAD if slot % 2 == 1 else main.SHAMBLER
			if n >= 4 and slot % 5 == 0: expected = main.LANCER
			elif n >= 2 and slot % 3 == 0: expected = main.SCUTTLER
			elif n >= 3 and slot % 4 == 0: expected = main.SCIENTIST
			if main.enemy_scene_for(n, slot) != expected: failures += 1
	check(failures == 0, "waves 1-4 preserve all 120 rotation positions")
	var early_common: int = 0
	var late_common: int = 0
	for slot in range(1, 121):
		if main.enemy_scene_for(6, slot) == main.SHAMBLER: early_common += 1
		if main.enemy_scene_for(15, slot) == main.SHAMBLER: late_common += 1
	check(late_common < early_common, "later composition replaces Shamblers (%d -> %d / 120)" % [early_common, late_common])
	var previous: int = 10000
	for n in [6, 7, 10, 13]:
		var count: int = 0
		for slot in range(1, 481):
			if main.enemy_scene_for(n, slot) == main.SHAMBLER: count += 1
		check(count < previous, "Shambler share steps down at wave %d (%d / 480)" % [n, count])
		previous = count
	check(not main.is_rush_wave(0) and main.is_rush_wave(5) and main.is_rush_wave(15) and not main.is_rush_wave(14), "rush hook every fifth positive wave")
	check(main.wave_interval(10) < main.wave_interval(9) and main.break_length(10) == main.break_length(9) + 10.0 and "DINNER RUSH" in main.wave_banner(5), "rush is denser, announced and followed by recovery")
	main.wave = 15
	var base: Node = main.spawn_zombie()
	var hp: float = base.max_health
	var speed: float = base.hunt_speed
	main._spawn_next()
	var scaled: Node = get_nodes_in_group("zombies")[-1]
	# Pick a known Shambler slot to verify scaling before its _ready initializes health.
	scaled.queue_free(); base.queue_free()
	await process_frame
	scaled = main.spawn_enemy(main.SHAMBLER, null, true)
	check(is_equal_approx(scaled.health, hp * scaling.health_multiplier(15)) and is_equal_approx(scaled.hunt_speed, speed * scaling.speed_multiplier(15)), "spawn-time scaling initializes actual health and motion")
	check(is_equal_approx(scaled.agent.max_speed, scaled.hunt_speed), "avoidance uses the scaled speed")
	scaled.queue_free()
	await process_frame
	for scene: PackedScene in [main.SHAMBLER, main.HOLLOWHEAD, main.SCUTTLER, main.SCIENTIST, main.LANCER]:
		var original: Node = scene.instantiate()
		var expected_hp: float = original.max_health * scaling.health_multiplier(15)
		var expected_speed: float = original.lane_speed * scaling.speed_multiplier(15)
		original.free()
		var z: Node = main.spawn_enemy(scene, null, true)
		check(is_equal_approx(z.health, expected_hp) and is_equal_approx(z.lane_speed, expected_speed), "scaled stats initialize for %s" % scene.resource_path)
		z.queue_free()
		await process_frame
	main.wave = 1

	# --- a wave-4 group arrives together, from different windows ---
	main.auto_spawn = true
	main._start_wave(4)
	main._spawn_t = 0.0
	var before: int = main._spawned
	for i in 40:   # 0.67 s: both members of the pair
		main._physics_process(1.0 / 60.0)
	var fresh: Array = main.get_tree().get_nodes_in_group("zombies")
	check(main._spawned - before == 2, "wave 4: a pair arrives within a second (%d)" % (main._spawned - before))
	var sides := {}
	for z in fresh:
		sides[String(z.window.name)] = true
	check(sides.size() == 2, "the pair comes through two different windows")
	check(main._spawn_t > main.wave_interval(4) * 2 - 1.0, "then a gap of ~2 intervals before the next pair (%.1f s)" % main._spawn_t)
	# --- the cap holds a spawn back but retries soon ---
	main.max_zombies = fresh.size()
	main._spawn_t = 0.0
	var pending: int = main._wave_left
	main._physics_process(1.0 / 60.0)
	check(main._wave_left == pending and absf(main._spawn_t - main.CAP_RETRY) < 0.05, "at the cap: nothing lost, retried in %.1f s" % main.CAP_RETRY)
	for z in fresh:
		z.queue_free()
	await process_frame
	main.auto_spawn = false
	main.max_zombies = 12

	# --- wave-cleared summary ---
	main._wave_left = 0
	main._break_t = -1.0
	main._wave_kills_at_start = main._kills - 5
	main._wave_earned_at_start = main.economy.earned - 42
	main.auto_spawn = true
	main._physics_process(1.0 / 60.0)
	main.auto_spawn = false
	var shown: String = (hud["toast"] as Label).text if hud.has("toast") else ""
	var found := false
	for n in main.find_children("*", "Label", true, false):
		if "CLEARED" in (n as Label).text and "5 KILLS" in (n as Label).text and "+$42" in (n as Label).text:
			found = true
	check(found, "wave cleared toast reports kills and cash for the wave")
	check(absf(main._break_t - main.break_length(4)) < 0.1, "break after wave 4 is %.0f s" % main.break_length(4))

	# --- early two-burger orders get extra patience ---
	main.wave = 1
	main.hatch.next_orders.clear()
	var e: Node = main.economy
	var hatch: Node = main.hatch
	var single := 0.0
	var double := 0.0
	for attempt in 200:
		var c: Node = hatch.spawn_customer(0)
		var p: float = c.patience
		if c.quantity == 1 and single == 0.0:
			single = p
		elif c.quantity == 2 and double == 0.0:
			double = p
		c.queue_free()
		hatch.car = null
		await process_frame
		if single > 0.0 and double > 0.0:
			break
	check(single > 0.0 and double >= single + 5.9, "wave 1: a two-burger order waits longer (%.0f s vs %.0f s)" % [double, single])

	# --- supply warnings ---
	e.buns = 6; e.toppings = 6; main._supply_warned = 99
	e.take_bun_and_topping(); e.take_bun_and_topping()
	var low_seen := false
	e.take_bun_and_topping()   # 3 left
	for n in main.find_children("*", "Label", true, false):
		low_seen = low_seen or "3 BUNS LEFT" in (n as Label).text
	check(low_seen, "warned at 3 buns left")
	e.take_bun_and_topping(); e.take_bun_and_topping(); e.take_bun_and_topping()
	var out_seen := false
	for n in main.find_children("*", "Label", true, false):
		out_seen = out_seen or "OUT OF BUNS" in (n as Label).text
	check(out_seen and main._supply_warned == 0, "warned when they run out")

	# --- missing mushroom warning ---
	e.stock = {"brown": 2, "blue": 0, "red": 0}
	hatch.next_orders.assign(["blue", "brown"])
	var car: Node = hatch.spawn_customer(0)
	check(main.missing_kinds(car) == ["blue"], "a Blue order with no Blue anywhere is flagged (%s)" % str(main.missing_kinds(car)))
	e.stock["blue"] = 1
	check(main.missing_kinds(car).is_empty(), "stocked: no warning")
	e.stock["blue"] = 0
	main.grill._place(0, "blue")
	check(main.missing_kinds(car).is_empty(), "a Blue patty on the grill counts")
	main._warn_missing(car)
	car.queue_free()
	print("\n%d failure(s)" % failures)
	quit(1 if failures else 0)
