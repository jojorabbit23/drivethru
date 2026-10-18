# Renders the Shambler doing its thing in the shop (needs a display):
#   godot --path . --fixed-fps 60 --script res://tools/capture_zombie.gd
extends SceneTree

const OUT := "res://docs/previews/"
const DT := 1.0 / 60.0

var main: Node3D
var cam: Camera3D
var t := 0.0

func _initialize() -> void:
	_run.call_deferred()

func step_until(cond: Callable, limit := 60.0) -> void:
	var start := t
	while not cond.call() and t - start < limit:
		await process_frame
		t += DT

func wait(seconds: float) -> void:
	var end := t + seconds
	while t < end:
		await process_frame
		t += DT

func shot(name: String, pos: Vector3, look: Vector3, fov := 70.0) -> void:
	cam.current = true
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved ", name)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	player.max_health = 1e6
	player.health = 1e6
	player.global_position = Vector3(-3.0, 0.05, 3.0)  # parked in the office
	cam = Camera3D.new()
	cam.near = 0.05
	main.add_child(cam)
	await wait(0.5)
	var win: Node3D = main.get_node("ShopGreybox/Windows/Window_A")
	var z: Node = main.spawn_zombie(win)
	await wait(6.0)
	await shot("z1_lane_from_window", Vector3(4.7, 1.62, -2.35), z.global_position + Vector3(0, 1.3, 0), 60)
	await shot("z2_lane_outside", Vector3(13.5, 2.2, -0.6), z.global_position + Vector3(0, 1.0, 0), 60)
	await step_until(func(): return z.state == 1 and win.boards_left() <= 2)
	await shot("z3_ripping_outside", Vector3(8.9, 1.9, -0.4), Vector3(6.4, 1.3, -2.5), 62)
	await shot("z4_ripping_inside", Vector3(3.6, 1.6, -1.6), Vector3(6.0, 1.5, -2.4), 65)
	await step_until(func(): return z.state == 2)
	await wait(0.75)
	await shot("z5_climbing_in", Vector3(2.4, 1.5, -1.2), Vector3(5.4, 1.2, -2.4), 65)
	await step_until(func(): return z.state == 3)
	await wait(2.0)
	await shot("z6_hunting", Vector3(1.0, 1.7, -3.9), z.global_position + Vector3(0, 1.0, 0), 65)
	# let it come for the player, then look through the player's eyes
	await step_until(func(): return z.state == 4, 40.0)
	await wait(0.4)
	var pcam: Camera3D = player.get_node("Head/Camera3D")
	await shot("z7_attack_first_person", pcam.global_position, z.global_position + Vector3(0, 1.2, 0), 75)
	await wait(1.0)
	z.take_damage(999.0, true)
	await wait(1.8)
	await shot("z8_dead", z.global_position + Vector3(1.6, 1.4, 1.2), z.global_position + Vector3(0, 0.3, 0), 60)
	quit()
