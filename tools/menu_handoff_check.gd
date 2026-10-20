extends SceneTree
func _initialize() -> void:
	create_timer(25.0).timeout.connect(func() -> void: quit(1))
	run.call_deferred()
func run() -> void:
	var menu: Control = load("res://ui/menu/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	var start: int = Time.get_ticks_msec()
	while menu.game_scene == null: await process_frame
	print("THREADED_GAME_LOAD_MS ", Time.get_ticks_msec()-start)
	menu._start_game()
	start = Time.get_ticks_msec()
	menu._video_finished()
	await process_frame
	await process_frame
	print("GAME_HANDOFF_MS ", Time.get_ticks_msec()-start)
	assert(current_scene != null and current_scene.name == "Main")
	assert(current_scene.get_node("Player").weapons.size() == 4)
	await RenderingServer.frame_post_draw
	print("PASS threaded menu handoff with original weapon slots")
	current_scene.queue_free()
	for i in 3: await process_frame
	quit()
