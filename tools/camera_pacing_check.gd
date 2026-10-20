# Native check: movement must render between physics ticks, without changing bodies.
extends SceneTree
var player: CharacterBody3D
func _initialize() -> void:
	create_timer(20.0).timeout.connect(func() -> void: quit(1))
	run.call_deferred()
func measure(smooth: bool) -> Dictionary:
	Input.action_release("move_right")
	player.position = Vector3(-4.0, 0.05, -1.8)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.set_process(smooth)
	for i in 15: await process_frame
	Input.action_press("move_right")
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var previous_body: Vector3 = player.global_position
	var previous_view: Vector3 = camera.global_position
	var repeated_body: int = 0
	var repeated_view: int = 0
	var max_lag: float = 0.0
	for i in 90:
		await process_frame
		await RenderingServer.frame_post_draw
		if player.global_position.is_equal_approx(previous_body): repeated_body += 1
		if camera.global_position.is_equal_approx(previous_view): repeated_view += 1
		max_lag = maxf(max_lag, absf(camera.global_position.x-player.global_position.x))
		previous_body = player.global_position
		previous_view = camera.global_position
	Input.action_release("move_right")
	return {"smooth":smooth,"body_repeats":repeated_body,"camera_repeats":repeated_view,"max_x_offset":max_lag}
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main: Node3D = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	player = main.get_node("Player")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Engine.max_fps = 165
	var before: Dictionary = await measure(false)
	var after: Dictionary = await measure(true)
	print("CAMERA BEFORE ", JSON.stringify(before))
	print("CAMERA AFTER ", JSON.stringify(after))
	assert(before.camera_repeats > 20, "baseline repeats physics positions")
	assert(after.body_repeats > 20, "collision still moves at physics rate")
	assert(after.camera_repeats < 5, "camera updates between physics ticks")
	assert(after.max_x_offset < 0.12, "interpolation stays within one walking step")
	player.position += Vector3(2,0,0)
	for i in 4: await process_frame
	assert(absf((player.get_node("Head/Camera3D") as Camera3D).global_position.x-player.global_position.x)<0.12,"teleports snap")
	print("PASS native camera pacing")
	main.queue_free()
	for i in 3: await process_frame
	quit()
