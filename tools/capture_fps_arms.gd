# First-person views of every weapon in the shared AKS arms (weapons/fps_arms).
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --script res://tools/capture_fps_arms.gd [-- pump pistol ...]
# Writes docs/previews/fps_arms_<weapon>.png (idle | action | reload) and fps_arms_all.png.
# FPS_ARMS_SHOW_OLD=1 also draws the old hands, for fitting.
extends SceneTree
const Shotgun = preload("res://weapons/shotgun/shotgun_weapon.gd")
const DesertEagle = preload("res://weapons/desert_eagle/desert_eagle.gd")
var player: CharacterBody3D
func _initialize() -> void:
	run.call_deferred()
func wait(n: int) -> void:
	for i in n:
		await process_frame
var current: Node3D
func report(tag: String) -> void:
	var arms: Node = current.find_child("FpsArms", true, false) if current else null
	if arms == null:
		return
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var line := "%s:" % tag
	for side in ["r", "l"]:
		var ref: Node3D = arms.right_ref if side == "r" else arms.left_ref
		var off: Transform3D = arms.right_offset if side == "r" else arms.left_offset
		var goal: Vector3 = cam.to_local((ref.global_transform * off).origin)
		var arm: Dictionary = arms._arms[side]
		var sh: Vector3 = cam.to_local(arms.skeleton.global_transform * arms.skeleton.get_bone_global_pose(arm["upper"]).origin)
		line += "  %s goal=%s shoulder=%s dist=%.3f short=%.3f" % [side, goal.snapped(Vector3.ONE * 0.01), sh.snapped(Vector3.ONE * 0.01), goal.distance_to(sh), arms.reach_error[side]]
	print(line)
func grab() -> Image:
	report("frame")
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8) # Vulkan readbacks may be RGB8; contact sheets are RGBA8.
	img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
	return img
func tick(w: Node, n: int) -> void:
	for i in n:
		if w.has_method("_tick"):
			w._tick(1.0 / 30.0)
		else:
			w._physics_process(1.0 / 30.0)
		await wait(1)
func sheet(name: String, imgs: Array[Image]) -> Image:
	var out := Image.create(640 * imgs.size(), 360, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		out.blit_rect(imgs[i], Rect2i(0, 0, 640, 360), Vector2i(640 * i, 0))
	out.save_png("res://docs/previews/fps_arms_%s.png" % name)
	print("saved fps_arms_", name)
	return out
func run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.set_process_unhandled_input(false)
	await wait(4)
	player.global_position = Vector3(-1.0, 0.1, 1.5)
	player.rotation.y = float(OS.get_environment("CAP_YAW")) if OS.get_environment("CAP_YAW") != "" else PI * 0.5
	player.get_node("Head").rotation.x = -0.05
	var want := OS.get_cmdline_user_args()
	var rows: Array[Image] = []
	var plan := ["pistol", "desert_eagle", "knife", "dagger", "crop_duster", "pump"]
	for name in plan:
		if want.size() > 0 and not want.has(name):
			continue
		var w: Node3D = null
		match name:
			"pistol": w = player.get_node("Head/Camera3D/TestGun")
			"knife": w = player.get_node("Head/Camera3D/Knife")
			"dagger": w = player.get_node("Head/Camera3D/Dagger")
			"crop_duster": w = player.get_node("Head/Camera3D/CropDuster")
			"desert_eagle":
				w = DesertEagle.new(); w.name = "DesertEagle"; player.add_weapon(w)
			"pump":
				w = Shotgun.new(); w.name = "Shotgun"; player.add_weapon(w)
		current = w
		w.set_meta("purchased", true)
		player.switch_weapon(player.weapons.find(w))
		await wait(40)
		var imgs: Array[Image] = [await grab()]
		if w.has_method("shoot"):
			w.shoot()
		elif w.has_method("fire"):
			w.fire()
		elif w.has_method("request"):
			w.request("slash")
		await wait(4)
		imgs.append(await grab())
		await wait(30)
		if "mag" in w:
			w.mag = 0 if name != "pump" else 3
		if w.has_method("reload"):
			w.reload()
		await wait(14)
		imgs.append(await grab())
		rows.append(await sheet(name, imgs))
	if rows.size() > 1:
		var all := Image.create(1920, 360 * rows.size(), false, Image.FORMAT_RGBA8)
		for i in rows.size():
			all.blit_rect(rows[i], Rect2i(0, 0, 1920, 360), Vector2i(0, 360 * i))
		all.save_png("res://docs/previews/fps_arms_all.png")
	quit()
