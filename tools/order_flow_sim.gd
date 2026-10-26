# Headless balance run for orders + waves together: the real main scene, an
# immortal stand-in player who kills each enemy `kill_after` s after it spawns
# and works one order at a time, taking `base + per_burger x (n - 1)` seconds,
# at half speed while enemies are alive (fighting). Prints per wave: cars,
# served, missed, rush-hour queues, reputation at the end, cash.
#   godot --headless --path . --fixed-fps 60 --script res://tools/order_flow_sim.gd -- [waves] [kill_after] [base] [per_burger]
extends SceneTree
var main: Node3D
var t := 0.0
var stats := {}
var born := {}

func _initialize() -> void:
	run.call_deferred()

func row(n: int) -> Dictionary:
	if not stats.has(n):
		stats[n] = {"cars": 0, "served": 0, "missed": 0, "queued": 0, "impatient": 0, "slack": []}
	return stats[n]

func run() -> void:
	var a := OS.get_cmdline_user_args()
	var waves := int(a[0]) if a.size() > 0 else 15
	var kill_after := float(a[1]) if a.size() > 1 else 8.0
	var base := float(a[2]) if a.size() > 2 else 16.0
	var per_burger := float(a[3]) if a.size() > 3 else 8.0
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var player: Node = main.player
	player.set_process_unhandled_input(false)
	player.set("max_health", 100000)
	player.unlock_burger_slots(9)
	var hatch: Node = main.hatch
	var rep: Node = main.get_node("Reputation")
	hatch.customer_arrived.connect(func(_c: Node): row(main.wave).cars += 1)
	hatch.customer_missed.connect(func(): row(main.wave).missed += 1)
	hatch.order_completed.connect(func(_c: Node): row(main.wave).served += 1)
	hatch.customer_queued.connect(func(_c: Node): row(main.wave).queued += 1)
	hatch.customer_impatient.connect(func(_c: Node): row(main.wave).impatient += 1)
	main.wave_cleared.connect(func(n: int): row(n)["rep"] = rep.value; row(n)["cash"] = main.economy.earned)
	var working: Node = null
	var work_left := 0.0
	while main.wave <= waves and t < 60.0 * 60.0:
		await physics_frame
		var dt := 1.0 / 60.0
		t += dt
		player.set("health", 100000)
		main.economy.buns = 20
		main.economy.toppings = 20
		var alive: Array = get_nodes_in_group("zombies")
		for z in alive:
			var id: int = z.get_instance_id()
			if not born.has(id):
				born[id] = t
			elif t - float(born[id]) >= kill_after and not z.get("dead"):
				z.take_damage(100000.0, true, {})
		var car: Node = hatch.waiting_car()
		if car != working:
			working = car
			if car:
				work_left = base + per_burger * float(car.quantity - 1)
		if working:
			work_left -= dt * (0.5 if alive.size() > 0 else 1.0)
			if work_left <= 0.0:
				row(main.wave).slack.append(working.patience - working.waited)
				for line: Dictionary in working.remaining_lines():
					for i in int(line.quantity):
						player.add_burger({"kind": String(line.kind), "quality": "good"})
						hatch.serve(player)
				player.burgers.clear()
				working = null
	print("wave  cars served missed queued impatient  rep   earned  avg slack(s)")
	for n in range(1, waves + 1):
		var r: Dictionary = row(n)
		var slack: Array = r.slack
		var avg: float = slack.reduce(func(s, x): return s + x, 0.0) / maxf(1.0, slack.size())
		print("%3d%s %5d %6d %6d %6d %9d  %5.0f  %6d  %6.1f" % [n, "*" if main.is_rush_wave(n) else " ", r.cars, r.served, r.missed, r.queued, r.impatient, float(r.get("rep", rep.value)), int(r.get("cash", main.economy.earned)), avg])
	print("sim time %.0f s, final rep %.0f %s, best streak %d" % [t, rep.value, rep.tier_name(), rep.best_streak])
	quit()
