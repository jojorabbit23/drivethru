# Films the kitchen and the shotgun from the player's eyes (needs a display):
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --write-movie kitchen.avi --script res://tools/film_kitchen.gd
# A DOUBLE BLUE ticket slides down the rail -> two mushrooms dropped and
# pressed -> one flipped -> both ready, one parked on the warming tray -> the
# bench builds the double -> served at the hatch -> the shop terminal sells
# the shotgun -> it's drawn and used on a Shambler at the kitchen window.
extends SceneTree

var main: Node3D
var player: CharacterBody3D
var cam: Camera3D
var head: Node3D

func _initialize() -> void:
	_run.call_deferred()

func wait(frames: int) -> void:
	for i in frames:
		await process_frame

# stand somewhere and turn to look at a point (smoothly over `frames`)
func look(stand: Vector3, at: Vector3, frames := 12) -> void:
	player.global_position = stand + Vector3(0, 0.05, 0)
	var d0 := Vector2(player.rotation.y, head.rotation.x)
	for i in frames:
		var e := at - cam.global_position
		var yaw := atan2(-e.x, -e.z)
		var pitch := atan2(e.y, Vector2(e.x, e.z).length())
		var k := float(i + 1) / frames
		k = k * k * (3.0 - 2.0 * k)
		player.rotation.y = lerp_angle(d0.x, yaw, k)
		head.rotation.x = lerpf(d0.y, pitch, k)
		await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.set_process_unhandled_input(false)
	cam = player.get_node("Head/Camera3D")
	head = player.get_node("Head")
	cam.rotation = Vector3.ZERO
	await wait(4)
	var econ: Node = main.economy
	econ.add_cash(270)
	econ.store_mushrooms(3, "blue")
	econ.buy_tray()
	econ.served = 3
	player.switch_weapon(1)
	var g: Node3D = main.grill
	var at_grill := Vector3(1.9, 0, -3.25)
	# 1. the ticket
	await look(at_grill, Vector3(1.4, 1.95, -4.7), 2)
	await wait(10)
	main.hatch.next_order = "double_blue"
	var car: Node3D = main.hatch.spawn_customer()
	await wait(45)
	# 2. two blue mushrooms on the grill
	await look(at_grill, g.global_position + Vector3(0, 0.05, -0.3), 14)
	g.add_patty("blue")
	await wait(22)
	g.add_patty("blue")
	await wait(40)
	# 3. look at the first and flip it
	await look(at_grill, (g.slots[0]["root"] as Node3D).global_position, 10)
	player.use_focus()
	await wait(30)
	# 4. (time passes) both ready; park one on the warming tray
	g.slots[0]["t"] = 6.2
	g.slots[1]["t"] = 6.4
	await wait(20)
	await look(at_grill, main.tray.global_position + Vector3(0, 0.1, 0), 14)
	player.use_focus()
	await wait(30)
	# 5. the bench builds the double
	await look(Vector3(0.9, 0, -3.35), main.bench.global_position + Vector3(0.2, 0.02, 0.05), 16)
	await wait(10)
	player.use_focus()
	await wait(40)
	# 6. serve it
	car.position = main.hatch.lane_stop - Vector3(car.CAB_FROM_CENTRE, 0, 0)
	car.state = "waiting"
	await look(Vector3(-3.0, 0, -3.75), main.hatch.global_position + Vector3(0, 0.45, -0.6), 2)
	await wait(25)
	player.use_focus()
	await wait(35)
	# 7. the shop terminal: weapons page, buy the shotgun
	await look(Vector3(-2.9, 0, 3.4), main.terminal.global_position + Vector3(0, 0.18, 0), 2)
	await wait(10)
	player.use_focus()
	await wait(25)
	player.use_focus()
	await wait(25)
	player.choose(1)
	await wait(30)
	# 8. at the kitchen window, a Shambler gets both barrels' worth
	var win: Node3D = main.get_node("ShopGreybox/Windows/Window_A")
	var z: Node3D = main.spawn_zombie(win)
	z.global_position = win.repair_point() + Vector3(-2.2, 0, 0.0)
	z.state = 3
	var stand: Vector3 = win.repair_point() + Vector3(-5.0, 0, 0.0)
	await look(stand, z.global_position + Vector3(0, 1.1, 0), 2)
	var sg: Node = player.weapon_named("SHOTGUN")
	for i in 40:
		if is_instance_valid(z) and not z.is_dead():
			var e: Vector3 = z.global_position + Vector3(0, 1.1, 0) - cam.global_position
			player.rotation.y = atan2(-e.x, -e.z)
			head.rotation.x = atan2(e.y, Vector2(e.x, e.z).length())
		await process_frame
	sg.shoot()
	await wait(60)
	if is_instance_valid(z) and not z.is_dead():
		sg.shoot()
		await wait(30)
	await wait(50)
	quit()
