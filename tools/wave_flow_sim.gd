# Headless wave-flow simulation: the real main scene with waves on, a player
# who can't die and kills each enemy `KILL_AFTER` seconds after it spawns.
# Logs each wave's start, spawns, cap delays and clear time, enemies that hang
# about too long (stuck), and the customer/order flow alongside.
#   godot --headless --path . --fixed-fps 60 --script res://tools/wave_flow_sim.gd -- [waves] [kill_after]
extends SceneTree
var main: Node3D
var player: Node
var t := 0.0
var born := {}          # enemy instance id -> spawn time
var log_lines: Array[String] = []
var stuck_reported := {}
var cleared: Array[int] = []

func _initialize() -> void:
	run.call_deferred()

func say(s: String) -> void:
	var line := "[%6.1f] %s" % [t, s]
	print(line)
	log_lines.append(line)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var waves := int(args[0]) if args.size() > 0 else 6
	var kill_after := float(args[1]) if args.size() > 1 else 12.0
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	player = main.get_node("Player")
	player.set_process_unhandled_input(false)
	player.set("max_health", 100000)
	player.set("health", 100000)
	main.wave_started.connect(func(n: int): say("%s  (size %d, groups of %d every %.0fs)" % [main.wave_banner(n), main.wave_size(n), main.group_size(n), main.wave_interval(n) * main.group_size(n)]))
	main.wave_cleared.connect(func(n: int):
		cleared.append(n)
		say("WAVE %d CLEARED, break %.0fs" % [n, main.break_length(n)]))
	var hatch: Node = main.hatch
	hatch.customer_arrived.connect(func(c: Node): say("customer arrives: %s  patience %.0fs" % [c.ticket_text(" + ") if c.has_method("ticket_text") else c.order, c.patience]))
	hatch.customer_missed.connect(func(): say("customer left unserved"))
	var spawns := 0
	var capped_frames := 0
	var max_alive := 0
	while main.wave <= waves:
		await physics_frame
		t += 1.0 / 60.0
		player.set("health", 100000)
		var alive: Array = get_nodes_in_group("zombies")
		max_alive = maxi(max_alive, alive.size())
		if alive.size() >= main.max_zombies and main._wave_left > 0:
			capped_frames += 1
		for z in alive:
			var id: int = z.get_instance_id()
			if not born.has(id):
				born[id] = t
				spawns += 1
				if "--spawns" in OS.get_cmdline_user_args():
					say("  spawn %s at %s" % [String(z.get_script().resource_path.get_file().get_basename()), String(z.window.name)])
			elif t - float(born[id]) >= kill_after and z.has_method("take_damage") and not z.is_dead():
				z.take_damage(10000.0, true, {})
			if t - float(born.get(id, t)) > kill_after + 6.0 and not stuck_reported.has(id):
				stuck_reported[id] = true
				say("STILL ALIVE %.0fs after spawn: %s at %s state=%s" % [t - float(born[id]), z.name, (z as Node3D).global_position.snapped(Vector3.ONE * 0.1), str(z.get("state"))])
		if t > 60.0 * 40:
			say("TIMEOUT (40 min)")
			break
	say("done: %d spawns, max alive %d, %.0fs of spawning blocked by the cap, cash $%d, served %d" % [spawns, max_alive, capped_frames / 60.0, main.economy.cash, main.economy.served])
	var expected: int = 0
	for n in range(1, waves + 1): expected += main.wave_size(n)
	var ok: bool = cleared.size() == waves and stuck_reported.is_empty() and spawns == expected and get_nodes_in_group("zombies").is_empty()
	say("%s: %d/%d waves cleared, %d/%d spawns, %d stuck" % ["PASS" if ok else "FAIL", cleared.size(), waves, spawns, expected, stuck_reported.size()])
	quit(0 if ok else 1)
