# Films a bus customer arriving, being served and driving off (needs a display):
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --write-movie bus.avi --script res://tools/film_bus.gd
extends SceneTree
var main: Node3D
var cam: Camera3D
var car: Node3D
var t := 0.0
var served := false
func _initialize() -> void:
	_setup.call_deferred()
func _setup() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	cam = Camera3D.new()
	cam.fov = 55
	main.add_child(cam)
	cam.current = true
	car = main.hatch.spawn_customer()
	process_frame.connect(_tick)
func _tick() -> void:
	t += 1.0 / 30.0
	var k := clampf(t / 12.0, 0.0, 1.0)
	cam.global_position = Vector3(lerpf(-10.0, 4.0, k), 2.0, -14.5)
	if not is_instance_valid(car):
		quit()
		return
	cam.look_at(Vector3(-3.0, 1.5, -7.0).lerp(car.global_position + Vector3(0, 1.4, 0), 0.6), Vector3.UP)
	var player: Node = main.player
	if t > 8.0 and not served:
		served = true
		player.set_held("burger")
		main.hatch.serve(player)
	if t > 14.0:
		quit()
