extends SceneTree
func _initialize() -> void:run.call_deferred()
func snap(camera: Camera3D,at: Vector3,aim: Vector3,label: String) -> void:
	camera.global_position=at
	camera.look_at(aim)
	for i in 24:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/"+label+".png"))
func run() -> void:
	Engine.max_fps=30
	root.size=Vector2i(1280,720)
	var main: Node3D=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	main.get_node("KitchenRadio").source.stop()
	var player: Node=main.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	for weapon: Node3D in player.weapons:weapon.hide();weapon.set_physics_process(false)
	for child: Node in main.get_children():
		if child is CanvasLayer:child.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	main.hatch.next_vehicle="rugged_truck"
	main.hatch.next_order="red"
	var car: Node3D=main.hatch.spawn_customer(2)
	car._process(5.0)
	car.set_process(false)
	car._bubble.visible=false
	var driver: Node3D=car._body.get_node("CubeDriver")
	var camera: Camera3D=player.camera
	camera.fov=65
	await snap(camera,Vector3(-3,1.65,-4.20),driver.global_position,"rugged_truck_hatch")
	await snap(camera,driver.global_position+Vector3(-0.65,0.03,1.20),driver.global_position,"rugged_driver_left")
	await snap(camera,driver.global_position+Vector3(0.65,0.03,1.20),driver.global_position,"rugged_driver_right")
	await snap(camera,Vector3(2.5,3.0,-2.8),car.global_position+Vector3(0,1,0),"rugged_truck_customer")
	main.free()
	for i in 3:await process_frame
	print("PASS rugged truck customer and tracked driver renders")
	quit()
