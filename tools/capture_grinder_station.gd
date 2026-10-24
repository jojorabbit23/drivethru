# First-person views of the grinder drop-off with its HUD prompt:
# docs/previews/grinder_station_{ready,grinding,done}.png
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --script res://tools/capture_grinder_station.gd
extends SceneTree
var main: Node3D
var player: Node3D
func _initialize() -> void:
	run.call_deferred()
func snap(name: String, frames := 6) -> void:
	for i in frames:
		player._update_focus()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/" + name + ".png")
	print("saved ", name)
func run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	main.hatch.auto = false
	player = main.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var cam: Camera3D = player.camera
	cam.global_position = Vector3(4.55, 1.62, -0.95)
	cam.look_at(Vector3(5.38, 1.12, -0.42))
	player.add_mushrooms(2, "blue")
	player.add_mushrooms(1, "red")
	await snap("grinder_station_ready", 20)
	var g: Node3D = get_first_node_in_group("mushroom_grinder")
	player.use_focus()
	g.set_process(false)
	g.advance(0.75)
	await snap("grinder_station_grinding")
	g.advance(1.3)
	await snap("grinder_station_done")
	quit()
