# Orders-side pressure (game/reputation.gd, game/customer_window.gd rush hour,
# game/customer_car.gd impatience, game/order_hud.gd): reputation tiers scale
# tips and car gaps, misses cost reputation and the streak, streak bonuses pay,
# a second car queues behind the first from rush_from_wave and moves up with no
# gap, its time in line costs patience, and a car honks once at 25% patience.
#   godot --headless --path . --fixed-fps 60 --script res://tools/order_pressure_test.gd
extends SceneTree
var failures := 0
var main: Node3D
var hatch: Node
var rep: Node

func _initialize() -> void:
	create_timer(120).timeout.connect(func() -> void: print("TIMEOUT"); quit(1))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func frames(n: int) -> void:
	for i in n:
		await process_frame

func serve_order(car: Node, quality := "perfect") -> void:
	for line: Dictionary in car.remaining_lines():
		for i in int(line.quantity):
			main.player.add_burger({"kind": String(line.kind), "quality": quality})
			hatch.serve(main.player)

func arrive(car: Node) -> void:
	for i in 400:
		if car.state != "arriving":
			return
		await process_frame

func run() -> void:
	main = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	await process_frame
	hatch = main.hatch
	hatch.auto = false
	main.player.set_physics_process(false)
	main.player.unlock_burger_slots(9)
	rep = main.get_node_or_null("Reputation")
	check(rep != null and main.get_node_or_null("OrderHUD") != null, "main attaches the reputation and its HUD")
	check(is_equal_approx(rep.value, 50.0) and rep.tier_name() == "DECENT" and rep.tip_scale() == 1.0 and rep.gap_scale() == 1.0, "starts DECENT: tips and car gaps unchanged")

	# --- a served order raises reputation and the streak; tips at x1 ---
	hatch.next_orders.assign(["brown"])
	var car: Node = hatch.spawn_customer(0)
	await arrive(car)
	var cash: int = main.economy.cash
	serve_order(car)
	check(main.economy.cash - cash == 36, "perfect Regular pays $30 + $6 tip at DECENT (%d)" % (main.economy.cash - cash))
	check(is_equal_approx(rep.value, 54.0) and rep.streak == 1, "perfect order: +1 perfect +3 order, streak 1 (%.0f)" % rep.value)
	await frames(2)

	# --- a missed car costs reputation and the streak ---
	await frames(300)   # served car drives off
	hatch.car = null
	hatch.next_orders.assign(["brown"])
	car = hatch.spawn_customer(0)
	car.patience = 1.0
	await arrive(car)
	await frames(90)
	check(car.state == "leaving" and is_equal_approx(rep.value, 44.0) and rep.streak == 0, "missed car: -10 and the streak resets (%.0f)" % rep.value)
	check(hatch._next >= 18.0 * 0.5 and hatch._next <= 32.0, "next car after the usual gap at DECENT (%.1f s)" % hatch._next)
	await frames(260)
	hatch.car = null

	# --- tiers: GOOD tips x1.25, gaps shorter; TERRIBLE fewer cars ---
	rep.value = 75.0
	check(rep.tier_name() == "GOOD" and rep.tip_scale() == 1.25 and rep.gap_scale() < 1.0, "GOOD: tips x1.25, cars more often")
	hatch.next_orders.assign(["brown"])
	car = hatch.spawn_customer(0)
	await arrive(car)
	cash = main.economy.cash
	serve_order(car)
	check(main.economy.cash - cash == 38, "perfect Regular tips $8 at GOOD (%d)" % (main.economy.cash - cash))
	rep.value = 5.0
	check(rep.tier_name() == "TERRIBLE" and rep.tip_scale() == 0.5 and rep.gap_scale() > 1.2, "TERRIBLE: half tips, fewer cars")
	await frames(300)
	hatch.car = null

	# --- streak bonus every 3 completed orders ---
	rep.value = 50.0
	rep.streak = 2
	hatch.next_orders.assign(["brown"])
	car = hatch.spawn_customer(0)
	await arrive(car)
	cash = main.economy.cash
	serve_order(car, "standard")
	check(rep.streak == 3 and main.economy.cash - cash == 30 + 10, "3 in a row: +$10 streak bonus (%d)" % (main.economy.cash - cash))
	var toast_ok := false
	for n in main.find_children("*", "Label", true, false):
		toast_ok = toast_ok or "STREAK BONUS" in (n as Label).text
	check(toast_ok, "streak bonus is announced")
	await frames(300)
	hatch.car = null

	# --- rush hour: chance by wave ---
	check(hatch.queue_chance(1) == 0.0 and hatch.queue_chance(4) == 0.0, "no queue before wave 5")
	# (waves 6, 8 and 21 are never dinner-rush waves; 5 may be)
	check(is_equal_approx(hatch.queue_chance(6), 0.4) and is_equal_approx(hatch.queue_chance(8), 0.6) and is_equal_approx(hatch.queue_chance(21), 0.8), "queue chance rises 10% a wave from wave 5, to 80%")
	if main.has_method("is_rush_wave"):
		var all_rush := true
		for n in range(1, 30):
			if main.is_rush_wave(n):
				all_rush = all_rush and hatch.queue_chance(n) == 1.0
		check(all_rush, "dinner-rush waves always send a second car")
	else:
		check(is_equal_approx(hatch.queue_chance(5), 0.3), "without the dinner-rush hook, wave 5 is 30%")
	check(main.delivery.allow_queue == false, "the delivery hatch never queues")

	# --- a second car queues, then moves up with no gap; time in line costs patience ---
	main.wave = 6
	hatch.next_orders.assign(["brown"])
	var front: Node = hatch.spawn_customer(0)
	await arrive(front)
	hatch.next_orders.assign(["blue"])
	var queued_signal := [false]
	hatch.customer_queued.connect(func(_c: Node): queued_signal[0] = true, CONNECT_ONE_SHOT)
	var second: Node = hatch.spawn_queued()
	check(queued_signal[0] and hatch.queued == second and hatch.car == front, "a second car joins the line behind the first")
	await arrive(second)
	check(second.state == "queued" and not second._bubble.visible, "it waits in line without showing an order bubble")
	check(front.position.x - second.position.x > 8.0, "it stops well behind the car at the hatch (%.1f m)" % (front.position.x - second.position.x))
	await frames(2)
	var hud: Node = main.get_node("OrderHUD")
	hud.refresh()
	check(hud.queue_label.visible and "B" in hud.queue_label.text, "HUD shows the next order in line (%s)" % hud.queue_label.text)
	check(hatch.waiting_car() == front and hatch.prompt(main.player).contains("R"), "the hatch still serves the front car")
	await frames(600)   # 10 s in line
	var patience_before: float = second.patience
	serve_order(front)
	check(front.state == "leaving", "front car served")
	await frames(int(hatch.ADVANCE_DELAY * 60.0) + 5)
	check(hatch.car == second and hatch.queued == null and second.state == "arriving", "the queued car moves up straight away")
	var waited_in_line: float = second.queue_waited   # it stops counting once it moves up
	check(waited_in_line > 10.0 and is_equal_approx(second.patience, patience_before - waited_in_line * hatch.QUEUE_PATIENCE_COST), "~11 s in line cost %.1f s of patience" % (patience_before - second.patience))
	var arrived := [false]
	hatch.customer_arrived.connect(func(_c: Node): arrived[0] = true, CONNECT_ONE_SHOT)
	await arrive(second)
	check(arrived[0] and second.state == "waiting" and hatch.waiting_car() == second, "it pulls up to the hatch and orders")
	check(absf(second.position.x - (hatch.lane_stop.x - second.CAB_FROM_CENTRE)) < 0.01, "cab stops at the hatch")

	# --- impatience at a quarter of patience: one warning ---
	var warned := [0]
	hatch.customer_impatient.connect(func(_c: Node): warned[0] += 1)
	second.patience = second.waited + 4.0
	await frames(int(4.0 * 0.75 * 60.0) + 20)
	check(warned[0] == 1 and second._warned, "one warning at 25% patience")
	var said := false
	for n in main.find_children("*", "Label", true, false):
		said = said or "LOSING PATIENCE" in (n as Label).text
	check(said, "the warning is announced")
	await frames(90)
	check(warned[0] == 1, "warns only once")
	print("\n%d failure(s)" % failures)
	quit(1 if failures else 0)
