# First-person renders of the knife (needs a display):
#   godot --path . --fixed-fps 60 --script res://tools/capture_knife.gd
extends SceneTree

const OUT := "res://docs/previews/"
var main: Node3D
var player: CharacterBody3D
var knife: Node
var prefix := "knife"

func _initialize() -> void:
	_run.call_deferred()

func wait(frames: int) -> void:
	for i in frames:
		await process_frame

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name.replace("knife", prefix) + ".png"))
	print("saved ", name)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	# Deterministic captures: desktop mouse movement must not steer the camera.
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# -- --dagger renders the alternative hand (slot 3) as dagger*.png
	var dagger := "--dagger" in OS.get_cmdline_user_args()
	knife = player.get_node("Head/Camera3D/Dagger" if dagger else "Head/Camera3D/Knife")
	prefix = "dagger" if dagger else "knife"
	await wait(5)
	player.global_position = Vector3(1.4, 0.05, -1.4)
	player.rotation.y = -PI / 2.0
	player.switch_weapon(3 if dagger else 1)
	await wait(12)
	await snap("knife0_draw")
	await wait(18)
	await snap("knife1_idle")
	# a zombie to cut
	var z: Node3D = main.spawn_zombie(main.get_node("ShopGreybox/Windows/Window_A"))
	z.state = 3
	z.global_position = Vector3(2.5, 0, -1.35)
	z.rotation.y = PI / 2.0
	await wait(3)
	z.set_physics_process(false)
	await wait(10)
	knife.request("slash")
	await wait(5)
	await snap("knife2_slash_windup")
	await wait(4)
	await snap("knife3_slash_hit")
	await wait(30)
	knife.request("stab")
	await wait(9)
	await snap("knife4_stab_drawback")
	await wait(6)
	await snap("knife5_stab_thrust")
	await wait(60)
	await snap("knife6_after")
	# pressed against a wall: the knife must not sink into it
	player.global_position = Vector3(1.2, 0.05, -0.5)
	player.rotation.y = PI
	await wait(10)
	knife.request("stab")
	await wait(15)
	await snap("knife7_stab_into_wall")
	if "--audit" in OS.get_cmdline_user_args():
		await audit_grip()
	main.queue_free()
	await wait(3)
	quit()

# Optional frame-by-frame contact audit. Outputs go outside the project cache.
func audit_grip() -> void:
	var directory: String = OS.get_environment("KNIFE_AUDIT_DIR")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://docs/previews/knife_audit")
	DirAccess.make_dir_recursive_absolute(directory)
	for zombie in get_nodes_in_group("zombies"): zombie.queue_free()
	player.global_position = Vector3(1.4,0.05,-1.4)
	player.rotation.y = -PI/2.0
	player.get_node("Head").rotation = Vector3.ZERO
	knife.set_physics_process(false)
	for clip in ["draw","slash","stab"]:
		var count: int = 17 if clip == "draw" else (16 if clip == "slash" else 15)
		for i in count:
			var time: float = float(i)/30.0
			if clip == "slash":
				knife._sample_clip("kitchen_knife_idle",0.0)
				knife._pose_at(knife.SLASH,time)
			else:
				knife._sample_clip("kitchen_knife_" + clip,time)
				knife._set_pose(knife.REST_POS,knife.REST_ROT)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("%s_%s_%02d.png" % [prefix,clip,i]))
	print("Grip audit saved to ",directory)
