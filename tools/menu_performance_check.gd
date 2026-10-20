# Bounded native playback check for intro, waiting bun loop and Start cinematic.
extends SceneTree
var menu: Control
var results: Array[Dictionary]=[]
func _initialize() -> void:
	create_timer(20.0).timeout.connect(func() -> void: quit(1))
	run.call_deferred()
func sample(label: String) -> void:
	for i in 12:await process_frame
	var frames: Array[float]=[]
	var last: int=Time.get_ticks_usec()
	for i in 90:
		menu.select(0 if i%2==0 else 2)
		await process_frame
		var now: int=Time.get_ticks_usec()
		frames.append(float(now-last)/1000.0)
		last=now
	frames.sort()
	var texture: Texture2D=menu.video.get_video_texture()
	assert(texture.get_width()==1280 and texture.get_height()==720,"video decode resolution")
	var result: Dictionary={"stage":label,"p95_ms":frames[85],"worst_ms":frames[-1],"video_width":texture.get_width(),"video_height":texture.get_height()}
	results.append(result)
	print("MENU_PROFILE ",JSON.stringify(result))
func run() -> void:
	root.size=Vector2i(1920,1080)
	for i in 3:await process_frame
	assert(root.get_texture().get_size()==Vector2(1280,720),"larger windows retain the 720p render budget")
	root.size=Vector2i(1280,720)
	menu=load("res://ui/menu/menu.tscn").instantiate()
	root.add_child(menu)
	await sample("intro / changing selection")
	menu._loop_bread()
	await sample("waiting bun / changing selection")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/menu_performance.png"))
	menu._start_game()
	await sample("bus cinematic")
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(menu.video.paused,"background video stops decoding")
	menu.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert(not menu.video.paused and Engine.max_fps==int(ProjectSettings.get_setting("application/run/max_fps",0)),"foreground video and input resume")
	var path: String=OS.get_environment("MENU_PROFILE_OUTPUT")
	if not path.is_empty():
		var file:=FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify(results,"\t"))
	menu.free()
	for i in 3:await process_frame
	quit()
