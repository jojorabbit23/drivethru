# Low roadside shot of a customer vehicle rolling up and stopping (needs a display):
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --write-movie wheels.avi --script res://tools/film_bus_wheels.gd [-- armored_truck]
extends SceneTree
var main: Node3D
var cam: Camera3D
var car: Node3D
var t := 0.0
func _initialize() -> void:
	_setup.call_deferred()
func _setup() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	cam = Camera3D.new()
	cam.fov = 50
	main.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(-6.5, 1.0, -14.5)   # across the road, side-on
	var fill := OmniLight3D.new()   # filming light only: the far side of the road is unlit
	fill.light_color = Color("#E9E1D1")
	fill.light_energy = 1.4
	fill.omni_range = 14.0
	fill.position = Vector3(-6.5, 3.0, -12.5)
	main.add_child(fill)
	var args := OS.get_cmdline_user_args()
	main.hatch.next_vehicle = args[0] if not args.is_empty() else "school_bus"
	car = main.hatch.spawn_customer()
	for c in main.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false   # no HUD in this shot
	process_frame.connect(_tick)
func _tick() -> void:
	t += 1.0 / 30.0
	if not is_instance_valid(car) or t > 9.0:
		quit()
		return
	cam.look_at(car.global_position + Vector3(0, 0.8, 0), Vector3.UP)
	cam.fov = 48.0
