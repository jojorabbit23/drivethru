extends SceneTree
func _initialize() -> void:run.call_deferred()
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
	var camera: Camera3D=player.camera
	camera.fov=65
	var views: Array=[
		["kitchen_cheese_tomatoes",Vector3(4.02,1.62,-3.40),Vector3(4.02,1.04,-4.43)],
		["kitchen_toppings_detail",Vector3(4.0,1.55,-4.02),Vector3(4.0,0.94,-4.40)],
	]
	for view: Array in views:
		camera.global_position=view[1]
		camera.look_at(view[2])
		for i in 6:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/"+view[0]+".png"))
	main.free()
	for i in 3:await process_frame
	print("PASS kitchen topping close-up renders")
	quit()
