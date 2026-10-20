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
	for view: Array in [["sink",Vector3(4.2,1.40,-1.8),Vector3(4.95,1.03,-.35)],["crate",Vector3(2.1,1.45,2.5),Vector3(.95,.95,4.0)]]:
		camera.global_position=view[1]
		camera.look_at(view[2])
		for i in 12:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/empty_bottle_"+view[0]+".png"))
	camera.global_position=Vector3(4.2,1.40,-1.8)
	camera.look_at(Vector3(4.95,1.03,-.35))
	for bottle: Node3D in get_nodes_in_group("destructible_props"):
		if bottle.global_position.z<0:bottle.take_prop_damage(1.0)
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/empty_bottle_broken.png"))
	await create_timer(1.0).timeout
	main.free()
	for i in 3:await process_frame
	print("PASS owner poster room captures")
	quit()

