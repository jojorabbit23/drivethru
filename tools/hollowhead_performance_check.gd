extends SceneTree
func _initialize() -> void:
	create_timer(20).timeout.connect(func() -> void:quit(1))
	run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main: Node3D=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	main.player.max_health=100000
	main.player.health=100000
	main.player.position=Vector3(-3,.05,-.7)
	main.player.rotation.y=0
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	AudioServer.set_bus_mute(0,true)
	for i in 12:
		var enemy: Node3D=main.spawn_hollowhead()
		enemy.position=Vector3(-4.5+(i%4)*.9,.05,-3.5+(i/4)*.75)
		enemy.state=enemy.State.HUNT
	for i in 30:
		Engine.max_fps=120
		await process_frame
	var frames: Array[float]=[]
	var last: int=Time.get_ticks_usec()
	for i in 180:
		Engine.max_fps=120
		if i==90:
			for k in 8:
				var puff: Node3D=preload("res://enemies/hollowhead/spore_burst.gd").new()
				puff.position=Vector3(-4+(k%4),1.4,-2.8+(k/4)*.5)
				main.add_child(puff)
		await process_frame
		await RenderingServer.frame_post_draw
		var now: int=Time.get_ticks_usec()
		frames.append(float(now-last)/1000)
		last=now
	frames.sort()
	var total: float=0
	for frame: float in frames:total+=frame
	print("HOLLOWHEAD_PROFILE ",JSON.stringify({"mean_ms":total/frames.size(),"p95_ms":frames[int(frames.size()*.95)],"worst_ms":frames[-1],"zombies":get_nodes_in_group("zombies").size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"vram_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0}))
	main.queue_free()
	for i in 3:await process_frame
	quit()
