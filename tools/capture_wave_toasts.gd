# The new wave/drive-thru toasts in the HUD: docs/previews/wave_toasts.png
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --script res://tools/capture_wave_toasts.gd
extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	var player: Node3D = main.get_node("Player")
	player.set_process_unhandled_input(false)
	for i in 10:
		await process_frame
	player.global_position = Vector3(-1.0, 0.1, 1.5)
	player.rotation.y = PI * 0.5
	var texts := [main.wave_banner(4), "WAVE 6 CLEARED  ·  16 KILLS  ·  +$212", "NO YELLOW MUSHROOMS FOR THIS ORDER", "3 BUNS LEFT  ·  BUY SUPPLIES SOON"]
	var colours := [main.P.AMBER_GLOW, main.P.ELECTRIC_TEAL, main.P.BURNT_ORANGE, main.P.AMBER_GLOW]
	var out := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	for i in texts.size():
		main._toast(texts[i], colours[i])
		for f in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.resize(640, 360)
		out.blit_rect(img, Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
	out.save_png("res://docs/previews/wave_toasts.png")
	print("saved wave_toasts")
	quit()
