# Films a Scuttler encounter on the west lane (needs a display):
#   godot --path . --fixed-fps 30 --write-movie docs/scuttler.avi --script res://tools/film_scuttler.gd
# Lane sprint -> ram the bottom boards -> dive through the gap -> the player
# (back office) shoots it in the leg (knockback) then the cap.
extends SceneTree

var main: Node3D
var player: CharacterBody3D
var z: Node
var win: Node3D
var cam: Camera3D
var pcam: Camera3D
var gun: Node
var t := 0.0
var shots := 0
var next_shot := 0.0
var dead_t := -1.0

func _initialize() -> void:
	_setup.call_deferred()

func _setup() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.max_health = 1000.0
	player.health = 1000.0
	pcam = player.get_node("Head/Camera3D")
	gun = player.get_node("Head/Camera3D/TestGun")
	player.global_position = Vector3(-1.4, 0.05, 2.6)
	player.rotation.y = PI / 2.0   # face -X, toward window B
	cam = Camera3D.new()
	cam.near = 0.05
	main.add_child(cam)
	cam.current = true
	win = main.get_node("ShopGreybox/Windows/Window_B")
	z = main.spawn_scuttler(win)
	process_frame.connect(_tick)

func _tick() -> void:
	var dt := 1.0 / 30.0
	t += dt
	if not is_instance_valid(z):
		quit()
		return
	var zp: Vector3 = (z as Node3D).global_position
	match z.state:
		0: # LANE: low shot from beside the lane, tracking it in
			cam.current = true
			cam.fov = 58
			cam.global_position = Vector3(-8.6, 0.55, 3.9)
			cam.look_at(zp + Vector3(0, 0.55, 0), Vector3.UP)
		1: # BREACH: outside, side-on at the window
			cam.current = true
			cam.fov = 60
			cam.global_position = Vector3(-8.4, 1.3, 4.6)
			cam.look_at(Vector3(-6.4, 0.9, 2.4), Vector3.UP)
		2: # CLIMB: the player's view of it diving through
			pcam.current = true
			player.get_node("Head").rotation.x = deg_to_rad(-12)
		_: # HUNT / ATTACK / STAGGER / DEAD: player's view; leg then cap
			pcam.current = true
			if not z.is_dead():
				var aim: Vector3 = zp + (Vector3(0, 0.3, 0) if shots == 0 else Vector3(0, 0.85, 0))
				var dir := aim - pcam.global_position
				player.rotation.y = lerp_angle(player.rotation.y, atan2(-dir.x, -dir.z), 0.25)
				var head: Node3D = player.get_node("Head")
				head.rotation.x = lerpf(head.rotation.x, atan2(dir.y, Vector2(dir.x, dir.z).length()), 0.25)
				if zp.distance_to(player.global_position) < 3.2 and t >= next_shot:
					gun.shoot()
					shots += 1
					next_shot = t + 0.7
			else:
				if dead_t < 0.0:
					dead_t = t
				if t - dead_t > 3.2:
					quit()
	if t > 30.0:
		quit()
