# Renders the pistol viewmodel: the in-game view (idle, fire, reload) and two
# close-ups of the hands on the grip. Each shot also prints how much of the
# frame the viewmodel covers, and where, so the composition can be checked from
# the console as well as by eye.
#   godot --path . --fixed-fps 60 --rendering-method gl_compatibility --script res://tools/capture_pistol.gd
extends SceneTree

const OUT := "res://docs/previews/"
const VIEWMODEL := "res://weapons/pistol/pistol_viewmodel.tscn"
const REST_POS := Vector3(0.13, -0.15, -0.26)
const REST_ROT := Vector3(0.0, 0.0, 0.0)

var vm: Node3D
var anim: AnimationPlayer
var slide: Node3D
var mag: Node3D
var flash: MeshInstance3D
var flame: OmniLight3D

func _initialize() -> void:
	_run.call_deferred()

func _wait(frames: int) -> void:
	for i in frames:
		await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var env := Environment.new()
	env.background_color = Color("#39454B")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25.0, 35.0, 0.0)
	light.light_energy = 1.1
	root.add_child(light)
	var camera := Camera3D.new()
	camera.near = 0.01
	camera.fov = 75.0
	root.add_child(camera)
	vm = (load(VIEWMODEL) as PackedScene).instantiate() as Node3D
	camera.add_child(vm)
	vm.position = REST_POS
	vm.rotation_degrees = REST_ROT
	anim = vm.find_child("AnimationPlayer", true, false) as AnimationPlayer
	slide = vm.find_child("pistol_slide", true, false) as Node3D
	mag = vm.find_child("pistol_magazine", true, false) as Node3D
	_build_flash(vm.get_node("Model/MuzzleTip"))
	await _wait(4)
	await _shot("pistol_idle")
	anim.play("fire", 0.0)
	anim.seek(0.08, true)
	flash.visible = true
	flame.visible = true
	await _shot("pistol_fire")
	flash.visible = false
	flame.visible = false
	anim.play("reload", 0.0)
	anim.seek(0.6, true)
	await _shot("pistol_reload")
	# close-ups: park the gun at the origin and look at the grip from outside
	anim.play("fire", 0.0)
	anim.seek(0.0, true)
	vm.reparent(root)
	vm.position = Vector3.ZERO
	vm.rotation_degrees = Vector3.ZERO
	await _wait(2)
	# The fist's wrist now points back down the arm, so these two look at it from
	# outside the arm's line -- the first repeats the framing of the sheet
	# docs/previews/pistol_wrist_sheet.png, where the owner chose the wrist angle.
	await _check("pistol_hands_left", Vector3(-0.66, 0.02, 0.34), Vector3(-0.01, -0.04, -0.02), 30.0)
	await _check("pistol_hands_front", Vector3(-0.22, 0.03, -0.42), Vector3(0.0, -0.01, -0.06), 40.0)
	quit()

func _check(name: String, pos: Vector3, target: Vector3, fov: float) -> void:
	var cam := Camera3D.new()
	cam.near = 0.01
	cam.fov = fov
	root.add_child(cam)
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	cam.current = true
	await _wait(2)
	await _shot(name)
	cam.queue_free()

# The muzzle flash, as the weapon script will build it: an amber star on the
# MuzzleTip marker plus a light.
func _build_flash(muzzle: Node3D) -> void:
	flame = OmniLight3D.new()
	flame.light_color = Color(1.0, 0.72, 0.3)
	flame.omni_range = 4.0
	flame.light_energy = 4.0
	flame.visible = false
	muzzle.add_child(flame)
	flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.72, 0.3)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_texture = _star_texture()
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	q.material = fm
	flash.mesh = q
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	muzzle.add_child(flash)

# a chunky 12 px pixel star for the muzzle flash
static func _star_texture() -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 12:
		for x in 12:
			var dx := absf(x - 5.5)
			var dy := absf(y - 5.5)
			if dx + dy < 4.0 or (dx < 1.0 and dy < 6.0) or (dy < 1.0 and dx < 6.0):
				img.set_pixel(x, y, Color.WHITE if dx + dy < 2.5 else Color(1, 1, 1, 0.85))
	return ImageTexture.create_from_image(img)

func _shot(name: String) -> void:
	# two process frames so a pose set by seek() is certainly drawn
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	# how much of the frame is not the background the corner shows
	var bg := img.get_pixel(2, 2)
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1
	var hits := 0
	var total := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			total += 1
			var c := img.get_pixel(x, y)
			if absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b) > 0.08:
				hits += 1
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	print("%s: drawn %d/%d samples (%.1f%%), x %d..%d of %d, y %d..%d of %d, slide %s mag %s" % [
		name, hits, total, 100.0 * hits / total, min_x, max_x, img.get_width(), min_y, max_y, img.get_height(),
		str(slide.position), str(mag.position)])
