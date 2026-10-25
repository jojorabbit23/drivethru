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
	# what the rotation would spawn over a whole wave n (no scene spawning)
	var out := {}
	for i in main.wave_size(n):
		var k: int = i + 1 + 40 * n
		var t := "common"
		if main.lancer_every > 0 and n >= main.lancer_from_wave and k % main.lancer_every == 0:
			t = "lancer"
		elif main.scuttler_every > 0 and n >= main.scuttler_from_wave and k % main.scuttler_every == 0:
			t = "scuttler"
		elif main.scientist_every > 0 and n >= main.scientist_from_wave and k % main.scientist_every == 0:
			t = "scientist"
		out[t] = int(out.get(t, 0)) + 1
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
	check(main.break_length(1) == 20.0 and main.break_length(3) == 24.0 and main.break_length(20) == 30.0, "break grows 2 s a wave from 20 s to 30 s")
	# --- staged enemy types ---
	var w1: Dictionary = kinds_in_wave(main, 1)
	check(w1.keys() == ["common"], "wave 1 is Shamblers and Hollowheads only (%s)" % str(w1))
	check(kinds_in_wave(main, 2).has("scuttler") and not kinds_in_wave(main, 2).has("scientist") and not kinds_in_wave(main, 2).has("lancer"), "wave 2 adds Scuttlers only")
	check(kinds_in_wave(main, 3).has("scientist") and not kinds_in_wave(main, 3).has("lancer"), "wave 3 adds Scientists")
	check(kinds_in_wave(main, 4).has("lancer"), "wave 4 adds Lancers")
	check("SCUTTLERS" in main.wave_banner(2) and "SCIENTISTS" in main.wave_banner(3) and "LANCERS" in main.wave_banner(4), "each new type is announced")
	check(main.wave_banner(1) == "WAVE 1" and "IN THREES" in main.wave_banner(7), "plain banner, and groups announced (%s)" % main.wave_banner(7))

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
