# Greybox first-person controller. Placeholder until the PSX arms pack is
# wired in: the Head/Camera3D node is where the arms rig will be parented.
# Also owns health and window repair (hold E at a window's repair spot).
extends CharacterBody3D

signal health_changed(health: float, max_health: float)
signal hurt(amount: float, from: Node3D)
signal died
signal mushrooms_changed(count: int)
signal focus_changed(station: Node)
signal menu_changed
signal held_changed(item: String)

@export var walk_speed := 4.2
@export var sprint_speed := 6.5
@export var jump_velocity := 4.0
@export var acceleration := 14.0
@export var mouse_sensitivity := 0.0025
@export var max_health := 100.0
@export var repair_reach := 1.4
@export var repair_time := 0.9   # seconds per board while holding E

@export_group("Movement feel")
@export var deceleration := 10.0       # stopping is gentler than starting
@export var air_control := 0.6          # the part of that control you keep off the ground
@export var coyote_time := 0.12        # jump grace after walking off an edge
@export var jump_buffer := 0.12        # jump grace before you land

@export_group("View")
@export var bob_amount := 0.022        # rise into each step
@export var bob_lateral := 0.016       # sway across a stride pair
@export var bob_speed := 1.9           # radians of step cycle per metre travelled
@export var idle_sway := 0.0016        # breathing at rest, in metres
@export var land_dip := 0.014          # view drop per m/s of landing speed
@export var max_dip := 0.08
@export var sprint_fov_boost := 3.5    # degrees wider while sprinting

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health := 0.0
var mushrooms := 0                 # mushrooms carried, all kinds (see carried)
var carried := {"brown": 0, "blue": 0, "red": 0}
var held := ""                     # item in hand: "" or "burger" (a bagged burger)
var held_burger := {}              # {kind, quality} of the bagged burger
const BurgerItems = preload("res://game/burger_items.gd")
var burgers: Array[Dictionary] = []
var burger_capacity: int = 1
var selected_burger: int = 0

# Stations (game/station.gd) are looked at and used with E. A station may open
# a small menu: options are {label, enabled, action: Callable, icon}; keys 1-4
# pick one, E picks the first enabled one. Looking away closes it.
const INTERACT_LAYER := 32         # physics layer 6 "interact"
@export_group("")
@export var interact_reach := 2.3
var focus: Node = null
var menu_station: Node = null
var menu_options: Array = []
var repair_window: Node3D = null   # window currently in reach (for the HUD)
var repair_progress := 0.0         # 0..1 toward the next board
var _shake := 0.0

# Movement feel. The view offsets below move the camera, never Head: the death
# tween drops Head's y, and the head is where aiming pitch lives.
const LAND_MIN_SPEED := 1.5        # a softer drop than this never dips the view
var _coyote := 0.0
var _jump_buffer := 0.0
var _bob_t := 0.0                  # steps taken, in radians
var _bob := Vector3.ZERO           # smoothed walk bob
var _dip := 0.0                    # landing dip, easing back to level
var _last_vy := 0.0                # last air speed, for the landing dip
var _was_grounded := true
var _idle_t := 0.0
var _base_fov := 75.0
var _sprint_fov := false
var _weapon_home := {}             # weapon -> the transform the scene gave it
# Render interpolation for the first-person position; collision and aim stay live.
var _view_previous_body := Vector3.ZERO
var _view_current_body := Vector3.ZERO
var _view_previous_local := Vector3.ZERO
var _view_current_local := Vector3.ZERO

# Default bindings are registered in code so the project works out of the box.
# Move them into Project Settings > Input Map whenever you like; existing
# actions there take priority and are left untouched.
const DEFAULT_BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"flip_patty": [KEY_F],
	"switch_prep_ticket": [KEY_G],
	"weapon_1": [KEY_1],
	"weapon_2": [KEY_2],
	"weapon_3": [KEY_3],
	"weapon_4": [KEY_4],
	"next_burger": [KEY_V],
}

signal weapon_changed(index: int, weapon: Node)
signal weapon_added(weapon: Node)

# Weapons are the children of Head/Camera3D that have set_active():
# 0 = placeholder pistol, 1 = knife. 1/2 or the mouse wheel switch.
var weapons: Array[Node] = []
var weapon_index := 0

func _ready() -> void:
	add_to_group("player")
	health = max_health
	for action in DEFAULT_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in DEFAULT_BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mb)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_base_fov = camera.fov
	_view_current_body = global_position
	_view_previous_body = global_position
	_view_current_local = camera.position
	_view_previous_local = camera.position
	for c in camera.get_children():
		if c.has_method("set_active"):
			weapons.append(c)
	for i in weapons.size():
		weapons[i].set_active(i == weapon_index)
	for w in weapons:
		_remember_weapon(w)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif menu_station and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		choose(event.physical_keycode - KEY_1)
	elif event.is_action_pressed("switch_prep_ticket") and not event.is_echo():
		get_parent().bench.cycle_ticket()
	elif event.is_action_pressed("flip_patty") and is_instance_valid(focus) and focus.has_method("flip_input"):
		if menu_station == focus: close_menu()
		focus.flip_input(self)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("next_burger"):
		cycle_burger()
	elif event.is_action_pressed("interact") and focus:
		use_focus()
	elif event.is_action_pressed("weapon_1"):
		switch_weapon(0)
	elif event.is_action_pressed("weapon_2"):
		switch_weapon(1)
	elif event.is_action_pressed("weapon_3"):
		switch_weapon(2)
	elif event.is_action_pressed("weapon_4"):
		switch_weapon(3)
	elif event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if not weapons.is_empty():
			var step := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			for offset in range(1,weapons.size()+1):
				var next_index: int=posmod(weapon_index+step*offset,weapons.size())
				if weapons[next_index].get_meta("purchased",true):
					switch_weapon(next_index)
					break
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	_view_previous_body = _view_current_body
	_view_previous_local = _view_current_local
	if BurgerItems.tick(burgers, delta, false, self): held_changed.emit(held)
	var grounded := is_on_floor()
	# Jump forgiveness: a short grace after walking off an edge, and a short
	# buffer before you land, so a jump at the last moment isn't dropped.
	if grounded:
		_coyote = coyote_time
	else:
		_coyote = maxf(0.0, _coyote - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	if Input.is_action_just_pressed("jump") and not is_dead():
		_jump_buffer = jump_buffer
	if _jump_buffer > 0.0 and _coyote > 0.0 and not is_dead():
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		grounded = false
	elif not grounded:
		velocity.y -= gravity * delta

	var input_dir := Vector2.ZERO if is_dead() else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var sprinting := Input.is_action_pressed("sprint")
	var speed := sprint_speed if sprinting else walk_speed
	# You start quicker than you stop, and off the ground you keep only part of
	# that control, so a jump carries its momentum.
	var rate := acceleration if input_dir != Vector2.ZERO else deceleration
	if not grounded:
		rate *= air_control
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(dir * speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	_update_focus()
	_update_repair(delta)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		camera.rotation.z = sin(Time.get_ticks_msec() * 0.05) * _shake * 0.05
	else:
		camera.rotation.z = 0.0
	var moved := Vector2(velocity.x, velocity.z).length()
	# The view reads the floor as it is after the move, or a landing is missed.
	_update_view(delta, is_on_floor(), moved)
	_update_fov(delta, sprinting and moved > walk_speed * 0.9)
	_update_weapon_idle(moved)
	_view_current_body = global_position
	_view_current_local = camera.position
	# Teleports/spawn corrections must snap rather than travel through walls.
	if _view_previous_body.distance_to(_view_current_body) > 0.5:
		_view_previous_body = _view_current_body
		_view_previous_local = _view_current_local

func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless" or is_dead(): return
	if not global_position.is_equal_approx(_view_current_body): return
	var fraction: float = Engine.get_physics_interpolation_fraction()
	var body_offset: Vector3 = _view_previous_body.lerp(_view_current_body, fraction) - global_position
	camera.position = _view_previous_local.lerp(_view_current_local, fraction) + head.global_basis.inverse() * body_offset

# The view: a small bob as you walk, a dip when you land, and a slow breath at
# rest. This is the only thing that moves the camera itself.
func _update_view(delta: float, grounded: bool, speed: float) -> void:
	# Landing: the faster you arrive, the deeper the drop, and it eases level
	# again. The fall speed is the one from the frame before the floor stopped
	# it, and a drop under LAND_MIN_SPEED (a step, a lip) doesn't count.
	if grounded and not _was_grounded:
		_dip = clampf((-_last_vy - LAND_MIN_SPEED) * land_dip, 0.0, max_dip)
	_was_grounded = grounded
	_last_vy = velocity.y
	_dip = lerpf(_dip, 0.0, 1.0 - exp(-9.0 * delta))
	# Walk bob: one sway across each stride pair, one rise per step. It fades
	# out in the air, where the ground stops driving the feet.
	var k := 0.0 if is_dead() else clampf(speed / walk_speed, 0.0, 1.35)
	_bob_t += delta * speed * bob_speed
	var target := Vector3(sin(_bob_t) * bob_lateral, sin(_bob_t * 2.0) * bob_amount, 0.0) * k
	if not grounded:
		target = Vector3.ZERO
	_bob = _bob.lerp(target, 1.0 - exp(-14.0 * delta))
	# Standing still: a body isn't a tripod, so the view breathes a millimetre.
	_idle_t += delta
	var idle := Vector3(sin(_idle_t * 0.61) * 0.5, sin(_idle_t * 0.83), 0.0) * idle_sway
	if is_dead():
		idle = Vector3.ZERO
	else:
		idle *= 1.0 / (1.0 + speed * 2.0)
	# The camera's *rotation* is never touched here: it is the aim (weapons fire
	# along camera.global_basis, the tests aim with camera.look_at). Position only.
	camera.position = _bob + Vector3(0.0, -_dip, 0.0) + idle

# Sprint opens the view up a little. Once it has kicked in it always eases back
# to the scene's own fov, so nothing else's framing is fought over.
func _update_fov(delta: float, sprinting: bool) -> void:
	if sprinting:
		_sprint_fov = true
	if not _sprint_fov:
		return
	var target := _base_fov + (sprint_fov_boost if sprinting else 0.0)
	camera.fov = lerpf(camera.fov, target, 1.0 - exp(-7.0 * delta))
	if not sprinting and absf(camera.fov - _base_fov) < 0.05:
		camera.fov = _base_fov
		_sprint_fov = false

# A held weapon isn't rigid: at rest it drifts and settles a few millimetres,
# and every few seconds the grip shuffles. The weapon's slot seeds it, so no two
# weapons breathe together, and it fades out as soon as you walk. The offset
# goes on the weapon node, on top of the transform the scene gave it, so the
# weapon's own animation (which drives a child pivot) is left alone.
func _update_weapon_idle(speed: float) -> void:
	var w := current_weapon()
	if not (w is Node3D) or not _weapon_home.has(w):
		return
	var home: Transform3D = _weapon_home[w]
	var k := 0.0 if is_dead() else 1.0 / (1.0 + speed * 1.5)
	var seed := float(weapons.find(w)) * 0.37
	var drift := Vector3(
		sin(_idle_t * 0.43 + seed) * 0.0032 + sin(_idle_t * 0.19 + seed * 2.1) * 0.0018,
		sin(_idle_t * 0.31 + seed * 2.9) * 0.0026 + sin(_idle_t * 0.11 + seed) * 0.0016,
		0.0)
	var tilt := Vector3(
		sin(_idle_t * 0.37 + seed * 3.3) * 0.5,
		sin(_idle_t * 0.23 + seed * 1.1) * 0.5,
		sin(_idle_t * 0.29 + seed * 2.3) * 0.4)
	var u := fposmod(_idle_t + seed * 2.0, 5.0 + seed * 3.0) / (5.0 + seed * 3.0)
	if u < 0.09:                               # the shuffle: out and back
		var s := sin(u / 0.09 * PI)
		drift += Vector3(0.004, -0.003, 0.0) * s
		tilt += Vector3(0.0, 0.7, -0.5) * s
	(w as Node3D).transform = home * Transform3D(Basis.from_euler(tilt * k * PI / 180.0), drift * k)

func switch_weapon(i: int) -> void:
	if i == weapon_index or i < 0 or i >= weapons.size():
		return
	if not weapons[i].get_meta("purchased",true):return
	weapon_index = i
	for k in weapons.size():
		weapons[k].set_active(k == i)
		# Put the weapon we're leaving back exactly where the scene put it,
		# rather than freezing it mid-shuffle.
		if k != i and _weapon_home.has(weapons[k]):
			(weapons[k] as Node3D).transform = _weapon_home[weapons[k]]
	weapon_changed.emit(i, weapons[i])

# A weapon bought later (the shotgun): goes on the camera in the next slot.
func add_weapon(w: Node, equip := true) -> void:
	camera.add_child(w)
	w.owner = self
	weapons.append(w)
	_remember_weapon(w)
	w.set_active(false)
	weapon_added.emit(w)
	if equip:
		switch_weapon(weapons.size() - 1)

# The idle shuffle offsets a weapon from where the scene put it, so remember the
# transform each weapon came with.
func _remember_weapon(w: Node) -> void:
	if w is Node3D:
		_weapon_home[w] = (w as Node3D).transform

func has_weapon(display_name: String) -> bool:
	for w in weapons:
		if w.get("display_name") == display_name and w.get_meta("purchased",true):
			return true
	return false

func weapon_named(display_name: String) -> Node:
	for w in weapons:
		if w.get("display_name") == display_name and w.get_meta("purchased",true):
			return w
	return null

func current_weapon() -> Node:
	return weapons[weapon_index] if weapon_index < weapons.size() else null

# ------------------------------------------------------------ health ----
func heal(amount: float) -> float:
	if is_dead() or amount <= 0.0: return 0.0
	var restored: float=minf(amount,maxf(0.0,max_health-health))
	if restored > 0.0:
		health += restored
		health_changed.emit(health,max_health)
	return restored

func take_damage(amount: float, from: Node3D = null) -> void:
	if is_dead():
		return
	health = maxf(0.0, health - amount)
	_shake = 1.0
	hurt.emit(amount, from)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()
		var tw := create_tween()
		tw.tween_property(head, "position:y", 0.35, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func is_dead() -> bool:
	return health <= 0.0

func add_mushrooms(n: int, kind := "brown") -> void:
	carried[kind] = int(carried[kind]) + n
	mushrooms += n
	mushrooms_changed.emit(mushrooms)

func drop_carried() -> Dictionary:
	var out := carried.duplicate()
	carried = {"brown": 0, "blue": 0, "red": 0}
	mushrooms = 0
	mushrooms_changed.emit(0)
	return out

func set_held(item: String, burger := {}) -> void:
	# Compatibility for older stations/scripts: replaces the selected held item.
	if item == "burger":
		if not burgers.is_empty(): burgers[selected_burger] = burger
		else: burgers.append(burger)
		if not burger.has("hot_remaining"): burger.hot_remaining = BurgerItems.HOT_SECONDS
	elif not burgers.is_empty():
		burgers.remove_at(selected_burger)
	_sync_burger()

func can_carry_burger() -> bool:
	return burgers.size() < burger_capacity

func add_burger(burger: Dictionary) -> bool:
	if not can_carry_burger(): return false
	if not burger.has("hot_remaining"): burger.hot_remaining = BurgerItems.HOT_SECONDS
	burgers.append(burger)
	selected_burger = burgers.size() - 1
	_sync_burger()
	return true

func take_selected_burger() -> Dictionary:
	if burgers.is_empty(): return {}
	var item: Dictionary = burgers[selected_burger]
	burgers.remove_at(selected_burger)
	_sync_burger()
	return item

func cycle_burger() -> void:
	if burgers.is_empty(): return
	selected_burger = (selected_burger + 1) % burgers.size()
	_sync_burger()

func unlock_burger_slots(wave_number: int) -> void:
	burger_capacity = maxi(burger_capacity, mini(4, 1 + wave_number / 3))
	_sync_burger()

func _sync_burger() -> void:
	selected_burger = clampi(selected_burger, 0, maxi(0, burgers.size() - 1))
	held = "burger" if not burgers.is_empty() else ""
	held_burger = burgers[selected_burger] if not burgers.is_empty() else {}
	held_changed.emit(held)

# ----------------------------------------------------------- stations ----
func _update_focus() -> void:
	var found: Node = null
	if not is_dead():
		var from := camera.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * interact_reach, 1 | INTERACT_LAYER, [get_rid()])
		q.collide_with_areas = true
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] is Area3D and (hit["collider"] as Area3D).has_meta("station"):
			found = (hit["collider"] as Area3D).get_meta("station")
	if found != focus:
		focus = found
		if menu_station and menu_station != focus:
			close_menu()
		focus_changed.emit(focus)

# E on the focused station: pick from its open menu, or let it act.
func use_focus() -> void:
	if not focus or is_dead():
		return
	if menu_station == focus:
		for i in menu_options.size():
			if menu_options[i]["enabled"]:
				choose(i)
				return
		close_menu()
		return
	focus.interact(self)

func open_menu(station: Node, options: Array) -> void:
	menu_station = station
	menu_options = options
	menu_changed.emit()

func close_menu() -> void:
	menu_station = null
	menu_options = []
	menu_changed.emit()

func choose(i: int) -> void:
	if menu_station and menu_station.has_method("options"):
		menu_options = menu_station.options(self)   # live: cash and stock may have changed
	if not menu_station or i < 0 or i >= menu_options.size() or not menu_options[i]["enabled"]:
		return
	var action: Callable = menu_options[i]["action"]
	close_menu()
	action.call()

# ------------------------------------------------------------ repair ----
func _update_repair(delta: float) -> void:
	var previous: Node3D=repair_window
	repair_window = null
	if is_dead() or focus:
		repair_progress=0.0
		return
	var best := repair_reach
	for w in get_tree().get_nodes_in_group("windows"):
		var d := Vector2(w.repair_point().x - global_position.x, w.repair_point().z - global_position.z).length()
		if d >= best or w.boards_left() >= w.boards.size():continue
		var target: Vector3=w.global_position
		var direction: Vector3=camera.global_position.direction_to(target)
		if (-camera.global_basis.z).dot(direction)<0.65:continue
		var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,target,1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
		best=d
		repair_window=w
	if previous!=repair_window:repair_progress=0.0
	if repair_window and Input.is_action_pressed("interact"):
		repair_progress += delta / repair_time
		if repair_progress >= 1.0:
			repair_progress = 0.0
			repair_window.repair_board()
	else:
		repair_progress = 0.0
