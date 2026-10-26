# Rush hour and reputation HUD (game/order_hud.gd): a car at the hatch, a second
# waiting in line behind it, the reputation bar and streak, and the impatient car.
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tools/capture_order_pressure.gd
extends SceneTree
var main: Node3D
func _initialize() -> void:
	create_timer(60).timeout.connect(func() -> void: quit(1))
	run.call_deferred()

func shot(name: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var hud: Node = main.get_node("OrderHUD")
	var r: Rect2 = hud.panel.get_global_rect()
	assert(r.position.x >= 0 and r.end.y <= root.size.y - 30, "reputation HUD fits on screen")
	root.get_texture().get_image().save_png("res://docs/previews/order_pressure_" + name + ".png")

func run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	main.wave = 6
	main.player.set_physics_process(false)
	main.player.set_process_unhandled_input(false)
	main.hatch.auto = false
	main.get_node("ClarityHUD").clock = 9
	var rep: Node = main.get_node("Reputation")
	rep.value = 74.0
	rep.streak = 4
	main.hatch.next_orders.assign(["brown", "blue"])
	main.hatch.next_vehicle = "rugged_truck"
	var front: Node = main.hatch.spawn_customer(0)
	front._process(5.0)
	main.hatch.next_orders.assign(["double_red"])
	main.hatch.next_vehicle = "school_bus"
	var second: Node = main.hatch.spawn_queued()
	second._process(5.0)
	main.player.camera.global_position = Vector3(-3.0, 1.65, -4.2)
	main.player.camera.look_at(front.global_position + Vector3(0, 1.7, 0))
	await shot("hud")
	main.player.camera.global_position = Vector3(3.0, 4.5, -16.0)
	main.player.camera.look_at(Vector3(-11, 1.0, -8.0))
	await shot("queue")
	# impatient: bubble shakes, bar blinks; reputation shaky
	rep.value = 28.0
	rep.streak = 0
	front._t = front.patience * 0.8
	for i in 12:
		await process_frame
	main.player.camera.global_position = Vector3(-3.0, 1.65, -4.2)
	main.player.camera.look_at(front.global_position + Vector3(0, 1.7, 0))
	await shot("impatient")
	quit()
