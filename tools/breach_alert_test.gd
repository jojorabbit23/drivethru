extends SceneTree
var failures: int = 0
func _initialize() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func run() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	await process_frame
	var alert: Node = main.get_node("BreachAlert")
	alert.set_process(false)
	var player: Node3D = main.player
	player.set_physics_process(false)
	var win: Node3D = main.get_node("ShopGreybox/Windows/Window_A")
	var camera: Camera3D = player.camera
	camera.global_position = win.global_position + win.outward() * -2.0
	camera.look_at(win.global_position)
	var enemy: Node = main.spawn_zombie(win)
	enemy.set_physics_process(false)
	enemy.state = 1
	alert.scan()
	check(alert.alerts_emitted == 0, "on-screen rip has no redundant warning")
	enemy.state = 0; alert.scan()
	camera.rotate_y(PI)
	enemy.state = 1; alert.scan()
	check(alert.alerts_emitted == 1 and alert.active.size() == 1, "off-screen attack entry produces one directional pip and audio cue")
	alert.scan(); enemy.state = 0; alert.scan(); enemy.state = 1; alert.scan()
	check(alert.alerts_emitted == 1, "continuous attacks and repeated entries are rate limited per window")
	alert.clock = 7.0
	enemy.state = 0; alert.scan(); enemy.state = 1; alert.scan()
	check(alert.alerts_emitted == 2, "new attack after cooldown can warn again")
	var pos: Vector2 = alert.pip_position(win.global_position)
	check(pos.is_finite() and root.get_visible_rect().has_point(pos), "behind-camera pip stays finite and within viewport")
	enemy.queue_free(); await process_frame; alert.scan()
	check(alert.seen.is_empty(), "freed enemies do not accumulate in observer")
	main.free()
	print("%d failure(s)" % failures)
	quit(1 if failures else 0)
