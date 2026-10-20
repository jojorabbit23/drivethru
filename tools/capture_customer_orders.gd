extends SceneTree
func _initialize() -> void:
	create_timer(25.0).timeout.connect(func() -> void: quit(1))
	run.call_deferred()
func run() -> void:
	Engine.max_fps=30
	root.size=Vector2i(1280,720)
	var main: Node3D=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	var player: Node=main.player
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	for weapon: Node3D in player.weapons:weapon.hide();weapon.set_physics_process(false)
	for child: Node in main.get_children():
		if child is CanvasLayer:child.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var camera: Camera3D=player.camera
	camera.fov=65
	for kind: String in ["brown","blue","red"]:
		var car: Node3D=load("res://game/customer_car.gd").new()
		car.vehicle="rugged_truck"
		car.order=kind
		car.quantity=3 if kind=="red" else 2
		main.add_child(car)
		car.setup(Vector3(-10,0,-7),Vector3(-3,0,-7),Vector3(15,0,-7))
		car._process(5.0)
		car.set_process(false)
		camera.global_position=Vector3(-3,1.65,-4.20)
		camera.look_at(car._bubble.global_position)
		car._bubble.global_basis=camera.global_basis
		for i in 12:await process_frame
		assert(car._bubble.get_node("BurgerColour").text==("YELLOW" if kind=="red" else kind.to_upper())+" BURGER")
		car.received=1
		car.refresh_order_quantity()
		assert(car._quantity_label.text=="x%d" % (car.quantity-1))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/customer_order_"+kind+".png"))
		car.free()
	main.free()
	for i in 3:await process_frame
	print("PASS coloured customer orders and remaining quantities")
	quit()
