# First-person renders of the knife (needs a display):
#   godot --path . --fixed-fps 60 --script res://tools/capture_knife.gd
extends SceneTree

const OUT := "res://docs/previews/"
var main: Node3D
var player: CharacterBody3D
var knife: Node

func _initialize() -> void:
	_run.call_deferred()

func wait(frames: int) -> void:
	for i in frames:
		await process_frame

func snap(name: String) -> void:
	await wait(1)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved ", name)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	knife = player.get_node("Head/Camera3D/Knife")
	await wait(5)
	player.global_position = Vector3(1.4, 0.05, -1.4)
	player.rotation.y = -PI / 2.0
	player.switch_weapon(1)
	await wait(30)
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
	quit()
