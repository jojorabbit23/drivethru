# Close-up contact sheets of the kitchen (needs a display):
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --script res://tools/capture_kitchen.gd
# Writes docs/previews/kitchen_patties.png (a mushroom dropped, smashed,
# cooking, flipped, ready and burnt, for each kind) and kitchen_pass.png (the
# counter with the ticket rail, the warming tray, the bench building a burger,
# and the bell on the hatch).
extends SceneTree

const OUT := "res://docs/previews/"
var main: Node3D
var player: CharacterBody3D
var cam: Camera3D
var frames: Array[Image] = []

func _initialize() -> void:
	_run.call_deferred()

func wait(n: int) -> void:
	for i in n:
		await process_frame

func grab(label := "") -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
	frames.append(img)

func sheet(name: String, cols: int) -> void:
	var w := frames[0].get_width()
	var h := frames[0].get_height()
	var rows := ceili(frames.size() / float(cols))
	var out := Image.create(w * cols, h * rows, false, frames[0].get_format())
	for i in frames.size():
		out.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	out.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved ", name)
	frames.clear()

func look(from: Vector3, at: Vector3, fov := 45.0) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.fov = fov

func _run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.set_process_unhandled_input(false)
	player.global_position = Vector3(-3, 0.1, 3)      # out of the way
	cam = Camera3D.new()
	main.add_child(cam)
	cam.current = true
	await wait(5)
	var econ: Node = main.economy
	econ.add_cash(500)
	econ.store_mushrooms(6, "brown")
	econ.store_mushrooms(6, "blue")
	econ.store_mushrooms(6, "red")
	econ.upgrade_grill()
	econ.upgrade_grill()
	await wait(2)
	var g: Node3D = main.grill
	var close := g.global_position + Vector3(0.05, 0.42, 0.62)
	var at := g.global_position + Vector3(0, 0.04, 0)
	look(close, at, 50)
	# the drop and smash, frame by frame
	g.add_patty("brown")
	for f in [3, 6, 11, 14, 25]:
		await wait(f - (0 if f == 3 else 0))
		await grab()
	# all kinds cooking; flip the blue one mid-air
	g.add_patty("blue")
	g.add_patty("red")
	await wait(20)
	g.slots[1]["t"] = 3.0
	g.slots[2]["t"] = 2.0
	await wait(2)
	g.flip(1)
	await wait(6)
	await grab()
	await wait(14)
	await grab()
	# ready and burnt
	g.slots[0]["t"] = 7.0
	g.slots[1]["t"] = 8.0
	g.slots[2]["t"] = 20.0
	await wait(20)
	await grab()
	look(g.global_position + Vector3(0.0, 0.85, 0.75), at, 55)
	await wait(4)
	await grab()
	sheet("kitchen_patties", 3)
	# --- the pass ---
	for i in 3:
		g.scrape()
		g.take_patty()
	econ.buy_tray()
	econ.buy_bell()
	main.hatch.next_order = "blue"
	var car: Node3D = main.hatch.spawn_customer()
	car.position = main.hatch.lane_stop
	g.add_patty("red")
	g.add_patty("blue")
	g.add_patty("brown")
	await wait(20)
	g.slots[0]["t"] = 7.0
	g.slots[1]["t"] = 6.5
	g.slots[2]["t"] = 3.0
	await wait(3)
	main.tray.store_from_grill()
	g.add_patty("red")
	g.slots[0]["t"] = 2.0
	await wait(30)
	var stand := Vector3(1.75, 1.62, -2.95)
	look(stand, Vector3(1.6, 1.25, -4.7), 62)
	await wait(4)
	await grab()
	look(Vector3(1.4, 1.85, -3.5), Vector3(1.4, 1.8, -4.75), 55)
	await wait(4)
	await grab()
	look(Vector3(1.2, 1.45, -3.7), main.bench.global_position + Vector3(0.3, 0.05, 0.05), 45)
	await wait(2)
	main.bench.bag(player)
	await wait(7)
	await grab()
	await wait(6)
	await grab()
	look(main.hatch.global_position + Vector3(1.4, 0.65, 1.3), main.hatch.global_position + Vector3(0.62, 0.0, 0.12), 45)
	await wait(4)
	await grab()
	look(stand + Vector3(-0.4, -0.05, 0.2), Vector3(1.4, 1.1, -4.7), 70)
	await wait(4)
	await grab()
	sheet("kitchen_pass", 3)
	quit()
