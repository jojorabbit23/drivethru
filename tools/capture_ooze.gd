# Close-up renders of the ooze (needs a display):
#   godot --path . --fixed-fps 60 --script res://tools/capture_ooze.gd
extends SceneTree

const OUT := "res://docs/previews/"
var main: Node3D
var player: CharacterBody3D
var cam: Camera3D

func _initialize() -> void:
	_run.call_deferred()

func wait(frames: int) -> void:
	for i in frames:
		await process_frame

func shot(name: String, pos: Vector3, look: Vector3, fov := 60.0) -> void:
	cam.current = true
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	await wait(2)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved ", name)

func fire_at(at: Vector3) -> void:
	var pcam: Camera3D = player.get_node("Head/Camera3D")
	pcam.look_at(at, Vector3.UP)
	await wait(1)
	player.get_node("Head/Camera3D/TestGun").shoot()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	cam = Camera3D.new()
	cam.near = 0.03
	main.add_child(cam)
	await wait(10)
	# A Shambler standing in the kitchen with the east wall behind it.
	var z: Node3D = main.spawn_zombie(main.get_node("ShopGreybox/Windows/Window_A"))
	z.state = 3
	z.global_position = Vector3(4.7, 0, -1.3)
	z.rotation.y = atan2(1.0, 0.0)   # facing west, toward the player
	await wait(3)
	z.set_physics_process(false)
	player.global_position = Vector3(1.0, 0.05, -1.3)
	await wait(3)
	# mid-spray: body shot
	await fire_at(z.global_position + Vector3(0, 1.15, 0))
	await wait(5)
	await shot("ooze1_body_hit_spray", Vector3(2.9, 1.5, 0.2), z.global_position + Vector3(0.4, 1.0, 0), 55)
	await wait(110)
	await shot("ooze2_wall_behind", Vector3(3.1, 1.5, -0.25), Vector3(5.75, 1.05, -1.6), 62)
	# second body shot, then a headshot
	await fire_at(z.global_position + Vector3(0, 1.05, 0))
	await wait(40)
	var skel: Skeleton3D = z.get_node("Model/Skeleton3D")
	var head := skel.to_global(skel.get_bone_global_pose(skel.find_bone("head")).origin) + Vector3(0, 0.14, 0)
	await fire_at(head)
	await wait(6)
	await shot("ooze3_headshot_burst", Vector3(2.7, 1.7, 0.4), head + Vector3(0.3, 0.0, 0), 55)
	await wait(240)
	await shot("ooze4_aftermath", Vector3(2.3, 2.0, -0.3), Vector3(4.9, 0.4, -1.7), 62)
	await shot("ooze5_player_view", player.get_node("Head/Camera3D").global_position, Vector3(5.5, 0.8, -1.4), 75)
	quit()
