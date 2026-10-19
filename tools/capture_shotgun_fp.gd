# First-person shotgun frames in the shop (needs a display):
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tools/capture_shotgun_fp.gd
# Writes docs/previews/shotgun_fp.png: idle, kick, pump, loading.
extends SceneTree

const Shotgun = preload("res://weapons/shotgun/shotgun_weapon.gd")
var frames: Array[Image] = []

func _initialize() -> void:
	_run.call_deferred()

func wait(n: int) -> void:
	for i in n:
		await process_frame

func grab() -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
	frames.append(img)

func _run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	player.set_process_unhandled_input(false)
	await wait(4)
	var sg: Node3D = Shotgun.new()
	sg.name = "Shotgun"
	player.add_weapon(sg)
	player.global_position = Vector3(-1.0, 0.1, 1.5)
	player.rotation.y = 0.0
	player.get_node("Head").rotation.x = -0.05
	sg.set_physics_process(false)
	for i in 20:
		sg._tick(1.0 / 30.0)
		await wait(1)
	await grab()                     # idle
	sg.shoot()
	for i in 2:
		sg._tick(1.0 / 30.0)
		await wait(1)
	await grab()                     # kick + flash
	for i in 11:
		sg._tick(1.0 / 30.0)
		await wait(1)
	await grab()                     # pump back
	for i in 12:
		sg._tick(1.0 / 30.0)
		await wait(1)
	sg.mag = 2
	sg.reload()
	for i in 6:
		sg._tick(1.0 / 30.0)
		await wait(1)
	await grab()                     # loading a shell
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var out := Image.create(w * 2, h * 2, false, frames[0].get_format())
	for i in frames.size():
		out.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	out.save_png(ProjectSettings.globalize_path("res://docs/previews/shotgun_fp.png"))
	print("saved")
	quit()
