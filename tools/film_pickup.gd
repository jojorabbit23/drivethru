# Films a mushroom drop and pickup from the player's view (needs a display):
#   godot --path . --rendering-method gl_compatibility --fixed-fps 30 --write-movie docs/video/pickup.avi --script res://tools/film_pickup.gd
# A Shambler and a Scuttler come at the player, are shot, each drops a glowing
# mushroom; the player watches them spin, then walks over and collects them.
extends SceneTree

var main: Node3D
var player: CharacterBody3D
var gun: Node
var cam: Camera3D
var head: Node3D
var t := 0.0
var foes: Array = []
var shot_t := 0.0
var close: Camera3D
var orbit := 0.0
var done_t := -1.0

func _initialize() -> void:
	_setup.call_deferred()

func _setup() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.max_health = 1e6
	player.health = 1e6
	cam = player.get_node("Head/Camera3D")
	head = player.get_node("Head")
	gun = player.get_node("Head/Camera3D/TestGun")
	player.global_position = Vector3(0.4, 0.05, -1.4)
	player.rotation.y = -PI / 2.0
	close = Camera3D.new()
	close.fov = 45
	main.add_child(close)
	var w: Node3D = main.get_node("ShopGreybox/Windows/Window_A")
	for i in 2:
		var z: Node3D = main.spawn_zombie(w) if i == 0 else main.spawn_scuttler(w)
		z.state = 3
		z.global_position = Vector3(4.0 + i * 0.3, 0.05, -2.0 + i * 1.3)
		z.rotation.y = PI / 2.0
		foes.append(z)
	await physics_frame
	for z in foes:
		z.set_physics_process(false)   # they stand still to be shot
	process_frame.connect(_tick)

func _aim(at: Vector3, k := 0.2) -> void:
	var dir := at - cam.global_position
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-dir.x, -dir.z), k)
	head.rotation.x = lerpf(head.rotation.x, atan2(dir.y, Vector2(dir.x, dir.z).length()), k)

func _tick() -> void:
	t += 1.0 / 30.0
	var alive := foes.filter(func(z): return is_instance_valid(z) and not z.is_dead())
	var ps := get_root_pickups()
	if not alive.is_empty() and t > 1.0:
		var z: Node3D = alive[0]
		var hb := z.find_child("HeadHitbox", true, false) as Node3D
		if hb == null:
			hb = z.find_child("CapHitbox", true, false) as Node3D
		_aim(hb.global_position, 0.3)
		if t - shot_t > 0.6 and t > 1.8:
			gun.shoot()
			shot_t = t
	elif alive.is_empty() and not ps.is_empty():
		var p: Node3D = ps[0]
		var since := t - shot_t
		if since > 1.4 and since < 5.4:
			# close-up: circle slowly round the first mushroom
			close.current = true
			orbit += 0.012
			var c := p.global_position
			close.global_position = c + Vector3(cos(orbit) * 0.8, 0.55, sin(orbit) * 0.8)
			close.look_at(c, Vector3.UP)
		else:
			cam.current = true
			_aim(p.global_position, 0.12)
		if since > 5.4:   # then walk over and pick them up
			var to := p.global_position - player.global_position
			to.y = 0
			player.velocity = to.normalized() * 2.2
			player.move_and_slide()
	elif alive.is_empty() and ps.is_empty():
		cam.current = true
		if t - shot_t > 1.0 and get_nodes_in_group("pickups").is_empty():
			shot_t = minf(shot_t, t)
		if player.mushrooms >= 2:
			head.rotation.x = lerpf(head.rotation.x, -0.15, 0.1)
			if done_t < 0.0:
				done_t = t
			if t - done_t > 1.5:
				quit()
	if t > 22.0:
		quit()

func get_root_pickups() -> Array:
	return get_nodes_in_group("pickups")
