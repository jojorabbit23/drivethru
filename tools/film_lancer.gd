# Films a Lancer encounter at Window A (needs a display):
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --write-movie lancer.avi --script res://tools/film_lancer.gd
# Lane stalk -> prying the boards (outside) -> from the repair spot inside, a
# lance comes through the gap -> step back, it climbs in, lunges, and the
# player puts three rounds in its cap.
extends SceneTree

var main: Node3D
var player: CharacterBody3D
var head: Node3D
var z: Node
var win: Node3D
var cam: Camera3D
var pcam: Camera3D
var gun: Node
var t := 0.0
var hp0 := 0.0
var stabbed_t := -1.0
var lunged_t := -1.0
var dead_t := -1.0
var board_t := -1.0
var next_shot := 0.0
var backed := false

func _initialize() -> void:
	_setup.call_deferred()

func _setup() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.set_process_unhandled_input(false)
	hp0 = player.health
	head = player.get_node("Head")
	pcam = player.get_node("Head/Camera3D")
	gun = player.get_node("Head/Camera3D/TestGun")
	win = main.get_node("ShopGreybox/Windows/Window_A")
	player.global_position = win.repair_point() + Vector3(0, 0.05, 0)
	_look(win.global_position)
	cam = Camera3D.new()
	cam.near = 0.05
	main.add_child(cam)
	cam.current = true
	z = main.spawn_lancer(win)
	win.board_removed.connect(func(_i): if board_t < 0.0: board_t = t)
	process_frame.connect(_tick)

func _look(at: Vector3, k := 1.0) -> void:
	var d := at - pcam.global_position
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-d.x, -d.z), k)
	head.rotation.x = lerpf(head.rotation.x, atan2(d.y, Vector2(d.x, d.z).length()), k)

func _tick() -> void:
	var dt := 1.0 / 30.0
	t += dt
	if not is_instance_valid(z):
		quit()
		return
	var zp: Vector3 = (z as Node3D).global_position
	var out: Vector3 = win.outward()
	var wp: Vector3 = win.global_position
	if player.health < hp0:
		if z.state == 1 and stabbed_t < 0.0:
			stabbed_t = t
		elif z.state != 1 and lunged_t < 0.0:
			lunged_t = t
		hp0 = player.health
	match z.state:
		0: # LANE: low shot beside the lane, tracking it in
			cam.current = true
			cam.fov = 55
			cam.global_position = Vector3(13.5, 1.4, -0.6)
			cam.look_at(zp + Vector3(0, 1.0, 0), Vector3.UP)
		1: # BREACH: outside and side-on, then the view from the repair spot
			if board_t < 0.0 or t - board_t < 1.6:
				cam.current = true
				cam.fov = 60
				cam.global_position = Vector3(8.9, 1.7, -0.4)
				cam.look_at(Vector3(6.4, 1.2, -2.5), Vector3.UP)
			else:
				pcam.current = true
				if stabbed_t > 0.0 and t - stabbed_t > 1.4 and not backed:
					backed = true
					player.global_position = win.repair_point() - out * 2.6 + Vector3(0, 0.05, 0)
				_look(wp + Vector3(0, -0.2, 0), 0.3)
		2: # CLIMB
			pcam.current = true
			_look(wp + Vector3(0, -0.4, 0), 0.3)
		_: # HUNT / ATTACK / STAGGER / DEAD
			if not z.is_dead():
				pcam.current = true
				var hb := z.find_child("HeadHitbox", true, false) as Node3D
				_look(hb.global_position if lunged_t > 0.0 else zp + Vector3(0, 1.2, 0), 0.3)
				if lunged_t > 0.0 and t - lunged_t > 0.6 and t >= next_shot:
					gun.shoot()
					next_shot = t + 0.55
			else:
				if dead_t < 0.0:
					dead_t = t
				_look(zp + Vector3(0, 0.3, 0), 0.15)
				if t - dead_t > 4.0:
					quit()
	if t > 60.0:
		quit()
