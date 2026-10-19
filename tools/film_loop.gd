# Films the vertical-slice loop from the player's view (needs a display):
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --write-movie loop.avi --script res://tools/film_loop.gd
# kill -> collect -> store -> cook -> bag -> serve -> buy ammo, with cuts.
extends SceneTree

var main: Node3D
var player: CharacterBody3D
var cam: Camera3D
var head: Node3D
var gun: Node
var t := 0.0
var seg := 0
var seg_t := 0.0
var z: Node3D
var car: Node3D
var shots := 0
var next_shot := 0.0
var path: Array = []

func _initialize() -> void:
	_setup.call_deferred()

func _setup() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.set_process_unhandled_input(false)
	player.max_health = 1e6
	player.health = 1e6
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cam = player.get_node("Head/Camera3D")
	head = player.get_node("Head")
	gun = player.get_node("Head/Camera3D/TestGun")
	main.hatch.auto = false
	_begin(0)
	process_frame.connect(_tick)

func _aim(at: Vector3, k := 0.18) -> void:
	var d := at - cam.global_position
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-d.x, -d.z), k)
	head.rotation.x = lerpf(head.rotation.x, atan2(d.y, Vector2(d.x, d.z).length()), k)

func _place(at: Vector3, look: Vector3) -> void:
	player.global_position = at + Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	var d := look - (at + Vector3(0, 1.6, 0))
	player.rotation.y = atan2(-d.x, -d.z)
	head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func _walk(dt: float) -> bool:
	if path.is_empty():
		return true
	var to: Vector3 = path[0]
	var d := to - player.global_position
	d.y = 0.0
	if d.length() < 0.15:
		path.pop_front()
		return path.is_empty()
	player.velocity = d.normalized() * 2.6
	player.velocity.y = 0.0
	player.move_and_slide()
	_aim(to + Vector3(0, 1.4, 0) + d.normalized() * 2.0, 0.12)
	return false

func _begin(n: int) -> void:
	seg = n
	seg_t = 0.0
	match n:
		0: # kitchen, pistol out; a Shambler has got in through window A
			player.switch_weapon(0)
			_place(Vector3(2.6, 0, -1.6), Vector3(5.0, 1.2, -2.2))
			z = main.spawn_zombie(main.get_node("ShopGreybox/Windows/Window_A"))
			z.state = 3
			z.global_position = Vector3(5.2, 0.05, -2.2)
		1: # walk to the storeroom bin
			player.switch_weapon(1)
			_place(Vector3(3.0, 0, -0.9), Vector3(3.0, 1.2, 1.0))
			path = [Vector3(3.0, 0, 0.6), Vector3(1.8, 0, 1.4)]
		2: # grill
			main.economy.store_mushrooms(1)
			_place(Vector3(2.1, 0, -3.2), main.grill.global_position + Vector3(0, 0.05, 0))
			car = main.hatch.spawn_customer()
		3: # the hatch: the car is waiting
			_place(Vector3(-3.0, 0, -3.65), main.hatch.global_position + Vector3(0, 0.65, -1.4))
		4: # shop terminal
			player.switch_weapon(0)
			_place(Vector3(-2.9, 0, 3.4), main.terminal.global_position + Vector3(0, 0.18, 0))

func _tick() -> void:
	var dt := 1.0 / 30.0
	t += dt
	seg_t += dt
	match seg:
		0:
			if is_instance_valid(z) and not z.is_dead():
				var hb := z.find_child("HeadHitbox", true, false) as Node3D
				_aim(hb.global_position, 0.3)
				if seg_t > 1.2 and seg_t >= next_shot:
					gun.shoot()
					next_shot = seg_t + 0.45
			else:
				_aim(player.global_position + Vector3(2.0, 0.6, -0.6) + Vector3(0, 0, 0), 0.05)
				if player.mushrooms > 0 and seg_t > 6.5 or seg_t > 12.0:
					_begin(1)
		1:
			var arrived := _walk(dt)
			if arrived:
				_aim(main.storage.global_position + Vector3(0, 0.4, 0), 0.25)
				if seg_t > 4.0 and player.mushrooms > 0 and player.focus == main.storage:
					player.use_focus()
				if seg_t > 6.0:
					_begin(2)
		2:
			if seg_t > 0.8 and seg_t < 0.9:
				player.use_focus()           # open the menu
			if seg_t > 2.2 and seg_t < 2.3:
				player.use_focus()           # common patty
			if seg_t > 2.6 and seg_t < 2.7:
				main.grill.add_patty()       # and a second one
			# fast-forward the cooking (x3) so the clip stays short
			for s in main.grill.slots:
				if s["state"] == "raw" or s["state"] == "cooking":
					s["t"] = (s["t"] as float) + dt * 2.0
			if seg_t > 7.6 and seg_t < 7.7:
				player.use_focus()
			if seg_t > 9.0 and seg_t < 9.1:
				player.use_focus()           # bag
			if seg_t > 10.5:
				_begin(3)
		3:
			if car and is_instance_valid(car) and car.state == "arriving":
				car.set("_t", 5.0)
			if seg_t > 2.5 and seg_t < 2.6:
				player.use_focus()           # serve
			if seg_t > 6.0:
				_begin(4)
		4:
			if seg_t > 1.0 and seg_t < 1.1:
				player.use_focus()
			if seg_t > 2.5 and seg_t < 2.6:
				player.use_focus()           # 24 rounds
			if seg_t > 5.0:
				quit()
	if t > 60.0:
		quit()
