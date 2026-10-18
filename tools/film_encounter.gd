# Films one full Shambler encounter with a scripted camera (needs a display).
#   godot --path . --fixed-fps 30 --write-movie docs/encounter.avi --script res://tools/film_encounter.gd
# Shots follow the zombie's state: lane -> ripping -> climbing -> hunting the
# player in first person -> the player shoots it down.
extends SceneTree

var main: Node3D
var player: CharacterBody3D
var z: Node
var win: Node3D
var cam: Camera3D
var pcam: Camera3D
var gun: Node
var t := 0.0
var shot_t := 0.0
var shot := ""
var shots_fired := 0
var dead_t := -1.0

func _initialize() -> void:
	_setup.call_deferred()

func _setup() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.max_health = 100.0
	pcam = player.get_node("Head/Camera3D")
	gun = player.get_node("Head/Camera3D/TestGun")
	# Player waits in the kitchen doorway, watching window A.
	player.global_position = Vector3(1.2, 0.05, -2.2)
	player.rotation.y = atan2(-1.0, 0.0)  # face +X (east)
	cam = Camera3D.new()
	cam.near = 0.05
	cam.fov = 60
	main.add_child(cam)
	cam.current = true
	win = main.get_node("ShopGreybox/Windows/Window_A")
	z = main.spawn_zombie(win)
	z.global_position = win.lane_spawn() + Vector3(-2.0, 0.05, 0)  # skip some walking
	process_frame.connect(_tick)

func cut(name: String) -> void:
	if shot != name:
		shot = name
		shot_t = 0.0

func _tick() -> void:
	var dt := 1.0 / 30.0
	t += dt
	shot_t += dt
	if not is_instance_valid(z):
		quit()
		return
	var zp: Vector3 = (z as Node3D).global_position
	match z.state:
		0: # LANE: low tracking shot from the lane barrier, then over the shoulder
			if zp.x > 9.6:
				cut("lane_wide")
				cam.current = true
				cam.fov = 55
				cam.global_position = Vector3(zp.x - 3.2, 1.0, -0.9)
				cam.look_at(zp + Vector3(0, 1.3, 0), Vector3.UP)
			else:
				cut("lane_behind")
				cam.current = true
				cam.fov = 60
				cam.global_position = zp + Vector3(2.4, 1.9, 0.7)
				cam.look_at(win.global_position + Vector3(0, -0.2, 0), Vector3.UP)
		1: # BREACH: first two boards from outside, the rest from the kitchen
			if win.boards_left() >= 3:
				cut("rip_out")
				cam.current = true
				cam.fov = 62
				cam.global_position = Vector3(8.9, 1.9, -0.4)
				cam.look_at(Vector3(6.4, 1.3, -2.5), Vector3.UP)
			else:
				cut("rip_in")
				pcam.current = true
		2: # CLIMB: player's view
			pcam.current = true
		_: # HUNT / ATTACK: player's view; the player opens fire
			pcam.current = true
			if not z.is_dead():
				var aim: Vector3 = zp + Vector3(0, 1.1 if shots_fired < 2 else 1.62, 0)
				# turn the player and head toward the aim, smoothly
				var dir := aim - pcam.global_position
				player.rotation.y = lerp_angle(player.rotation.y, atan2(-dir.x, -dir.z), 0.18)
				var head: Node3D = player.get_node("Head")
				var pitch := atan2(dir.y, Vector2(dir.x, dir.z).length())
				head.rotation.x = lerpf(head.rotation.x, pitch, 0.18)
				# fire once it's close and in the doorway light: two body shots, then the head
				if zp.distance_to(player.global_position) < 3.4 and fmod(t, 0.55) < dt:
					gun.shoot()
					shots_fired += 1
			else:
				if dead_t < 0.0:
					dead_t = t
				if t - dead_t > 0.9:
					cut("corpse")
					cam.current = true
					cam.fov = 60
					cam.global_position = zp + Vector3(-1.7, 1.5, 1.4)
					cam.look_at(zp + Vector3(0, 0.3, 0), Vector3.UP)
				if t - dead_t > 3.5:
					quit()
	if t > 60.0:
		quit()
