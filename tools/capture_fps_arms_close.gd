# Close-ups of a weapon's hands from outside (side, top, front-left, below) to check grips.
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --script res://tools/capture_fps_arms_close.gd -- pistol
# Writes docs/previews/fps_arms_close_<weapon>.png. FPS_ARMS_OFF=1 shows the old hands instead.
extends SceneTree
const Shotgun = preload("res://weapons/shotgun/shotgun_weapon.gd")
const DesertEagle = preload("res://weapons/desert_eagle/desert_eagle.gd")
func _initialize() -> void:
	run.call_deferred()
func wait(n: int) -> void:
	for i in n:
		await process_frame
func run() -> void:
	root.size = Vector2i(800, 600)
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	player.set_process_unhandled_input(false)
	await wait(4)
	player.global_position = Vector3(-1.0, 0.1, 1.5)
	player.rotation.y = PI * 0.5
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var name: String = OS.get_cmdline_user_args()[0]
	var w: Node3D
	match name:
		"pistol": w = cam.get_node("TestGun")
		"knife": w = cam.get_node("Knife")
		"dagger": w = cam.get_node("Dagger")
		"crop_duster": w = cam.get_node("CropDuster")
		"desert_eagle":
			w = DesertEagle.new(); w.name = "DesertEagle"; player.add_weapon(w)
		"pump":
			w = Shotgun.new(); w.name = "Shotgun"; player.add_weapon(w)
	w.set_meta("purchased", true)
	player.switch_weapon(player.weapons.find(w))
	await wait(40)
	var muzzle: Node3D = w.find_child("MuzzleTip", true, false)
	var centre: Vector3 = w.find_child("Pivot", true, false).global_position if w.find_child("Pivot", true, false) else w.global_position
	centre = centre.lerp(muzzle.global_position, 0.3) if muzzle else centre
	var eye := Camera3D.new()
	eye.near = 0.01
	eye.fov = 45
	main.add_child(eye)
	var b := cam.global_basis
	var views := [b * Vector3(1, 0.15, 0.1), b * Vector3(0, 1, 0.05), b * Vector3(-0.8, 0.3, -0.6), b * Vector3(0.2, -0.9, -0.4)]
	var out := Image.create(1600, 1200, false, Image.FORMAT_RGBA8)
	for i in views.size():
		eye.global_position = centre + (views[i] as Vector3).normalized() * 0.5
		eye.look_at(centre, b.y if i != 1 else -b.z)
		eye.current = true
		await wait(3)
		await RenderingServer.frame_post_draw
		out.blit_rect(root.get_texture().get_image(), Rect2i(0, 0, 800, 600), Vector2i((i % 2) * 800, (i / 2) * 600))
	out.save_png("res://docs/previews/fps_arms_close_%s.png" % name)
	print("saved close ", name)
	quit()
