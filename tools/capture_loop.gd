# Renders the burger loop stations (needs a display):
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 60 --script res://tools/capture_loop.gd
# Writes docs/previews/loop*.png
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

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved ", name)

func stand_look(stand: Vector3, at: Vector3) -> void:
	player.global_position = stand + Vector3(0, 0.05, 0)
	await wait(2)
	var head: Node3D = player.get_node("Head")
	var d := at - cam.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await wait(3)

func _run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cam = player.get_node("Head/Camera3D")
	await wait(5)
	var econ: Node = main.economy
	econ.add_cash(58)
	econ.store_mushrooms(4, "brown")
	econ.store_mushrooms(2, "blue")
	econ.store_mushrooms(1, "red")
	econ.add_cash(200)
	econ.upgrade_grill()     # 3 slots for the shot
	player.switch_weapon(1)
	# 1. grill: raw, cooking, ready + menu
	await wait(2)
	main.grill.add_patty("brown")
	await wait(1)
	main.grill.slots[0]["t"] = 7.5
	main.grill.add_patty("blue")
	main.grill.slots[1]["t"] = 3.5
	main.grill.add_patty("red")
	main.grill.slots[2]["t"] = 0.3
	await stand_look(Vector3(2.1, 0, -3.25), main.grill.global_position + Vector3(0, 0.05, -0.3))   # the back edge: not a patty (E there flips it)
	player.use_focus()
	await wait(8)
	await snap("loop1_grill_menu")
	player.close_menu()
	# 2. burnt
	main.grill.slots[0]["t"] = 19.0
	await wait(40)
	await snap("loop2_grill_burnt")
	main.grill.scrape()
	# 3. bag a burger and serve a car
	main.grill.slots[1]["t"] = 7.0
	await wait(2)
	main.hatch.next_order = "blue"
	var car: Node3D = main.hatch.spawn_customer()
	main.bench.bag(player)
	await stand_look(Vector3(0.8, 0, -3.3), main.bench.global_position + Vector3(0, 0.1, 0))
	await wait(4)
	await snap("loop7_prep_bench")
	car.position = main.hatch.lane_stop
	await wait(2)
	car.set("_t", 5.0)
	await wait(3)
	await stand_look(Vector3(-3.0, 0, -3.7), main.hatch.global_position + Vector3(0, 0.75, -1.4))
	await wait(10)
	await snap("loop3_hatch_customer")
	# 4. outside view of the drive-through
	var out_cam := Camera3D.new()
	out_cam.fov = 60
	main.add_child(out_cam)
	out_cam.global_position = Vector3(2.5, 2.4, -12.0)
	out_cam.look_at(Vector3(-3.0, 1.3, -6.5), Vector3.UP)
	out_cam.current = true
	await wait(4)
	await snap("loop4_drive_thru_outside")
	cam.current = true
	out_cam.queue_free()
	main.hatch.serve(player)
	await wait(4)
	# 5. storage bin
	player.add_mushrooms(2, "brown")
	player.add_mushrooms(1, "red")
	await stand_look(Vector3(1.7, 0, 1.6), main.storage.global_position + Vector3(0, 0.4, 0))
	await wait(6)
	await snap("loop5_storage")
	# 6. shop terminal
	await stand_look(Vector3(-2.9, 0, 3.4), main.terminal.global_position + Vector3(0, 0.18, 0))
	player.use_focus()
	player.use_focus()          # the weapons page
	await wait(8)
	await snap("loop6_terminal")
	player.close_menu()
	main.queue_free()
	await wait(3)
	quit()
