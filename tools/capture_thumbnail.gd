# Thumbnail backgrounds (needs a display), written to the work folder given
# after "--" (default /tmp/drivethru_thumb):
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --script res://tools/capture_thumbnail.gd -- <dir>
# A: low angle outside, a Lancer looming, the horde and the lit shop behind.
# B: first person, the shotgun going off at a Lancer in the kitchen.
extends SceneTree

const Shotgun = preload("res://weapons/shotgun/shotgun_weapon.gd")
var main: Node3D
var player: CharacterBody3D
var cam: Camera3D
var out_dir := "/tmp/drivethru_thumb"

func _initialize() -> void:
	_run.call_deferred()

func wait(n: int) -> void:
	for i in n:
		await process_frame

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/" + name + ".png")
	print("saved ", name)

func fresh() -> void:
	if main:
		main.queue_free()
		await wait(3)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.set_process_unhandled_input(false)
	for c in main.get_children():
		if c is CanvasLayer:
			c.visible = false
	cam = Camera3D.new()
	cam.near = 0.03
	main.add_child(cam)
	await wait(3)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	# A ------------------------------------------------------------------
	await fresh()
	player.global_position = Vector3(-3, 0.05, 3)
	var w: Node3D = main.get_node("ShopGreybox/Windows/Window_A")
	var out: Vector3 = w.outward()
	var side := out.cross(Vector3.UP).normalized()
	var bp: Vector3 = w.breach_point()
	var l: Node3D = main.spawn_lancer(w)
	var s: Node3D = main.spawn_zombie(w)
	var c: Node3D = main.spawn_scuttler(w)
	for z in [l, s, c]:
		z.set_physics_process(false)
	l.global_position = bp + out * 2.2 + side * 0.5
	s.global_position = bp + out * 4.2 - side * 0.7
	c.global_position = bp + out * 3.4 + side * 1.3
	for z: Node3D in [l, s, c]:
		var to := bp - z.global_position
		z.rotation.y = atan2(to.x, to.z)
	for z in [l, s, c]:
		var ap: AnimationPlayer = z.find_child("AnimationPlayer", true, false)
		if ap:
			ap.play(ap.get_animation_list()[0] if not ap.has_animation("stalk") else "stalk")
			ap.seek(0.3, true)
			ap.pause()
	cam.fov = 62
	cam.global_position = bp + out * 0.9 + side * 0.2 + Vector3(0, 0.55, 0)
	cam.look_at(l.global_position + Vector3(0, 1.45, 0), Vector3.UP)
	cam.rotate_y(deg_to_rad(25.0))          # the Lancer sits in the right third
	cam.current = true
	var rim := OmniLight3D.new()            # warm light behind it, like the shop's glow
	rim.light_color = Color("#F3A34D")
	rim.light_energy = 2.2
	rim.omni_range = 4.0
	main.add_child(rim)
	rim.global_position = l.global_position + out * 1.0 + Vector3(0, 2.2, 0)
	await wait(6)
	await snap("thumb_a")
	# B ------------------------------------------------------------------
	await fresh()
	var w2: Node3D = main.get_node("ShopGreybox/Windows/Window_A")
	var sg: Node = Shotgun.new()
	sg.name = "Shotgun"
	player.add_weapon(sg)
	var l2: Node3D = main.spawn_lancer(w2)
	l2.global_position = w2.repair_point() + Vector3(-1.6, 0, 0.2)
	l2.state = 3
	player.global_position = w2.repair_point() + Vector3(-3.6, 0.05, 0.4)
	await wait(40)
	l2.set_physics_process(false)
	var e: Vector3 = l2.global_position + Vector3(0, 1.4, 0) - (player.global_position + Vector3(0, 1.65, 0))
	player.rotation.y = atan2(-e.x, -e.z)
	player.get_node("Head").rotation.x = atan2(e.y, Vector2(e.x, e.z).length())
	var pcam: Camera3D = player.get_node("Head/Camera3D")
	pcam.current = true
	await wait(4)
	sg.set_physics_process(false)
	sg._flash_t = 0.06
	sg._flash.light_energy = 4.0
	sg._flash.visible = true
	sg._flash_mesh.visible = true
	await wait(1)
	await snap("thumb_b")
	quit()
