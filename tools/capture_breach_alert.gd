extends SceneTree
func _initialize() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	run.call_deferred()
func run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(1280,720)
	var main: Node3D = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	await process_frame
	main.player.set_physics_process(false)
	var camera: Camera3D = main.player.camera
	camera.global_position = Vector3(2.0,1.6,-3.0)
	camera.look_at(main.grill.global_position)
	var win: Node3D = main.get_node("ShopGreybox/Windows/Window_B")
	var alert: Node = main.get_node("BreachAlert")
	alert.warn(win)
	main._toast(main.wave_banner(10), main.P.AMBER_GLOW)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/wave_breach_alert.png"))
	main.free()
	print("PASS rush banner and directional breach capture")
	quit()
