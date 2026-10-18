# Short close-up of the ooze (needs a display):
#   godot --path . --fixed-fps 30 --write-movie docs/ooze.avi --script res://tools/film_ooze.gd
extends SceneTree

var main: Node3D
var player: CharacterBody3D
var cam: Camera3D
var z: Node3D
var t := 0.0
var fired := []

func _initialize() -> void:
	_setup.call_deferred()

func _setup() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	cam = Camera3D.new()
	cam.near = 0.03
	cam.fov = 60
	main.add_child(cam)
	cam.current = true
	z = main.spawn_zombie(main.get_node("ShopGreybox/Windows/Window_A"))
	z.state = 3
	z.global_position = Vector3(4.7, 0, -1.3)
	z.rotation.y = atan2(1.0, 0.0)
	player.global_position = Vector3(1.0, 0.05, -1.3)
	process_frame.connect(_tick)

func fire(at: Vector3) -> void:
	var pcam: Camera3D = player.get_node("Head/Camera3D")
	pcam.look_at(at, Vector3.UP)
	player.get_node("Head/Camera3D/TestGun").shoot()

func _tick() -> void:
	t += 1.0 / 30.0
	if t > 0.1 and z.is_physics_processing():
		z.set_physics_process(false)
		z.velocity = Vector3.ZERO
	var skel: Skeleton3D = z.get_node("Model/Skeleton3D")
	var head := skel.to_global(skel.get_bone_global_pose(skel.find_bone("head")).origin) + Vector3(0, 0.14, 0)
	for k in [[1.0, 1.15], [2.3, 0.95], [3.7, -1.0]]:
		if t >= k[0] and not fired.has(k[0]):
			fired.append(k[0])
			fire(head if k[1] < 0.0 else z.global_position + Vector3(0, k[1], 0))
	# slow dolly from side-on toward the wall behind, then down to the floor
	var a := clampf((t - 0.3) / 7.5, 0.0, 1.0)
	var e := a * a * (3.0 - 2.0 * a)
	var p0 := Vector3(2.8, 1.55, -0.25)
	var p1 := Vector3(3.6, 1.7, -0.3)
	var l0 := Vector3(4.9, 1.2, -1.4)
	var l1 := Vector3(5.5, 0.5, -1.8)
	cam.global_position = p0.lerp(p1, e)
	cam.look_at(l0.lerp(l1, e), Vector3.UP)
	if t > 8.5:
		quit()
