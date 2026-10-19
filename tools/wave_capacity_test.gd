# A full crowd must delay a wave spawn, not erase its pending enemy.
extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1

func run() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	main.set_physics_process(false)
	main.auto_spawn = true
	main.max_zombies = 1
	main._start_wave(8)
	main.spawn_zombie()
	var pending: int = main._wave_left
	var spawned: int = main._spawned
	main._spawn_t = 0.0
	main._physics_process(1.0 / 60.0)
	check(main._wave_left == pending, "full crowd preserves pending wave enemies")
	check(main._spawned == spawned, "full crowd creates no extra enemy")
	for zombie in get_nodes_in_group("zombies"):
		zombie.queue_free()
	await process_frame
	await process_frame
	main._spawn_t = 0.0
	main._physics_process(1.0 / 60.0)
	check(main._wave_left == pending - 1, "free capacity consumes exactly one pending enemy")
	check(main._spawned == spawned + 1, "spawning resumes after capacity frees")
	print("%d failure(s)" % failures)
	quit(1 if failures else 0)
