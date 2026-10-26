# Both shotgun reloads sampled through insertion and recovery, not just fetch.
extends SceneTree
func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	run.call_deferred()
func run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(1280,720)
	var main: Node3D = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	var player: Node3D = main.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.rotation.y = PI * 0.5
	for layer: Node in main.get_children():
		if layer is CanvasLayer: layer.hide()
	for weapon: Node3D in player.weapons:
		weapon.set_active(false)
		weapon.set_physics_process(false)
	var crop: Node3D = player.camera.get_node("CropDuster")
	var pump: Node3D = load("res://weapons/shotgun/shotgun_weapon.gd").new()
	player.add_weapon(pump, false)
	pump.set_physics_process(false)
	var out := Image.create(1920,720,false,Image.FORMAT_RGBA8)
	for row in 2:
		var weapon: Node3D = crop if row == 0 else pump
		weapon.set_meta("purchased",true)
		weapon.show()
		weapon.set_active(true)
		if row == 0:
			crop.loaded.assign([false,false])
			crop.state = "idle"
			crop.reload()
		else:
			pump._draw_t = 0.0
			pump.mag = 2
			pump.reload()
		for col in 3:
			for i in 8:
				if row == 0:
					crop.clock = [1.75,2.28,3.2][col]
					crop._pose(0.0)
				else:
					pump._shell_t = [0.08,0.22,0.40][col]
					pump._animate(1.0/30.0)
				await process_frame
			await RenderingServer.frame_post_draw
			var frame: Image = root.get_texture().get_image()
			frame.convert(Image.FORMAT_RGBA8)
			frame.resize(640,360)
			out.blit_rect(frame,Rect2i(0,0,640,360),Vector2i(col*640,row*360))
		weapon.set_active(false)
		weapon.hide()
	out.save_png("res://docs/previews/hand_reload_fit.png")
	main.free()
	print("PASS shotgun reload fit capture")
	quit()
