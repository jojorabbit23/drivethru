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
	for view: Array in [["kitchen",Vector3(2.8,1.68,-1.25),Vector3(2.85,1.38,-4.6)],["service",Vector3(-.9,1.68,-.7),Vector3(-3.0,1.38,-4.1)],["fridge",Vector3(.6,1.6,2.4),Vector3(5.7,1.6,2.4)]]:
		player.global_position=Vector3(view[1].x,0.1,view[1].z)
		player.get_node("Presentation/ShadowBudget").apply_budget()
		camera.global_position=view[1]
		camera.look_at(view[2])
		for i in 12:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/lighting_"+view[0]+".png"))
	main.free()
	for i in 3:await process_frame
	print("PASS owner poster room captures")
	quit()

