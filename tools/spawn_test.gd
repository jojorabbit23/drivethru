# Checks the wave spawner (headless):
#   godot --headless --path . --fixed-fps 60 --script res://tools/spawn_test.gd
# Runs the real game for 2 minutes with an invulnerable player and watches
# every spawn.
extends SceneTree

const DT := 1.0 / 60.0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1

func _run() -> void:
	seed(7)
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)   # auto_spawn stays on: this is the real spawner
	var player: CharacterBody3D = main.get_node("Player")
	player.max_health = 1e9
	player.health = 1e9
	var interval: float = main.spawn_interval
	var spawns := []        # [time, window name, zombie]
	var known := {}
	var t := 0.0
	while t < 120.0:
		await physics_frame
		t += DT
		for z in main.get_children():
			if z is CharacterBody3D and z.is_in_group("zombies") and not known.has(z):
				known[z] = true
				spawns.append([t, (z.window as Node).name, z, (z as Node3D).global_position])
	var times := spawns.map(func(s): return "%.1f" % s[0])
	print("  spawns at: ", ", ".join(times))
	# waves: nobody kills them here, so wave 1 never clears and its size caps the count
	var expected := mini(main.wave_size(1), int((120.0 - main.first_zombie_delay) / interval) + 1)
	check(spawns.size() == expected, "%d zombies in 2 minutes: all of wave 1 (expected %d)" % [spawns.size(), expected])
	check(absf(spawns[0][0] - main.first_zombie_delay) < 0.1, "first one at %.1f s" % spawns[0][0])
	var gaps_ok := true
	for i in range(1, spawns.size()):
		if absf(spawns[i][0] - spawns[i - 1][0] - interval) > 0.1:
			gaps_ok = false
	check(gaps_ok, "every gap is %.0f s" % interval)
	var a := spawns.filter(func(s): return s[1] == "Window_A").size()
	var b := spawns.filter(func(s): return s[1] == "Window_B").size()
	check(a > 0 and b > 0, "both sides used (Window A lane %d, Window B lane %d)" % [a, b])
	var streak_ok := true
	for i in range(2, spawns.size()):
		if spawns[i][1] == spawns[i - 1][1] and spawns[i][1] == spawns[i - 2][1]:
			streak_ok = false
	check(streak_ok, "never three in a row from the same side")
	var lane_ok := true
	for s in spawns:
		var w: Node3D = main.get_node("ShopGreybox/Windows/" + s[1])
		if (s[3] as Vector3).distance_to(w.lane_spawn()) > 1.0:
			lane_ok = false
	check(lane_ok, "each zombie starts at the far end of its window's lane")
	# every zombie spawned more than 12 s ago has reached or broken through its own window
	var reached := 0
	var due := 0
	for s in spawns:
		var z: Node = s[2]
		if not is_instance_valid(z) or t - s[0] < 12.0:
			continue
		due += 1
		if z.state >= 1:   # BREACH or later
			reached += 1
	check(reached == due, "every zombie older than 12 s has got to its window (%d of %d)" % [reached, due])
	# the clock stops when the player dies
	player.health = 1.0
	player.take_damage(5.0)
	var count := spawns.size()
	for i in int(interval * 2.0 / DT):
		await physics_frame
		for z in main.get_children():
			if z is CharacterBody3D and z.is_in_group("zombies") and not known.has(z):
				known[z] = true
				count += 1
	check(count == spawns.size(), "no more spawns after you die")
	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
