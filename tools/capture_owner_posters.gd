extends SceneTree
func _initialize() -> void:
	create_timer(25.0).timeout.connect(func() -> void:quit(1))
	run.call_deferred()
func run() -> void:
	Engine.max_fps=30
	root.size=Vector2i(1280,720)
	var main: Node3D=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	var player: Node3D=main.player
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	for weapon: Node3D in player.weapons:weapon.hide();weapon.set_physics_process(false)
	for child: Node in main.get_children():
		if child is CanvasLayer:child.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var camera: Camera3D=player.camera
	camera.fov=58
	for view: Array in [["kitchen",Vector3(2.2,1.72,-2.15),Vector3(1.85,1.80,-.14)],["service",Vector3(-1.3,1.7,-2.5),Vector3(-1.3,1.8,-.14)]]:
		camera.global_position=view[1]
		camera.look_at(view[2])
		for i in 12:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/owner_posters_"+view[0]+".png"))
	main.free()
	for i in 3:await process_frame
	print("PASS owner poster room captures")
	quit()
