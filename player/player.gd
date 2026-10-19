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

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health := 0.0
var mushrooms := 0                 # glowing mushrooms picked up from dead enemies (carried)
var held := ""                     # item in hand: "" or "burger" (a bagged burger)

# Stations (game/station.gd) are looked at and used with E. A station may open
# a small menu: options are {label, enabled, action: Callable, icon}; keys 1-4
# pick one, E picks the first enabled one. Looking away closes it.
const INTERACT_LAYER := 32         # physics layer 6 "interact"
@export var interact_reach := 2.3
var focus: Node = null
var menu_station: Node = null
var menu_options: Array = []
var repair_window: Node3D = null   # window currently in reach (for the HUD)
var repair_progress := 0.0         # 0..1 toward the next board
var _shake := 0.0

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
	"weapon_1": [KEY_1],
	"weapon_2": [KEY_2],
	"weapon_3": [KEY_3],
	"weapon_4": [KEY_4],
}

signal weapon_changed(index: int, weapon: Node)

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
	for c in camera.get_children():
		if c.has_method("set_active"):
			weapons.append(c)
	for i in weapons.size():
		weapons[i].set_active(i == weapon_index)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif menu_station and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_4:
		choose(event.physical_keycode - KEY_1)
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
			switch_weapon(posmod(weapon_index + step, weapons.size()))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and not is_dead():
		velocity.y = jump_velocity

	var input_dir := Vector2.ZERO if is_dead() else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(dir * speed, acceleration * delta)
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

func switch_weapon(i: int) -> void:
	if i == weapon_index or i < 0 or i >= weapons.size():
		return
	weapon_index = i
	for k in weapons.size():
		weapons[k].set_active(k == i)
	weapon_changed.emit(i, weapons[i])

func current_weapon() -> Node:
	return weapons[weapon_index] if weapon_index < weapons.size() else null

# ------------------------------------------------------------ health ----
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

func add_mushrooms(n: int) -> void:
	mushrooms += n
	mushrooms_changed.emit(mushrooms)

func set_held(item: String) -> void:
	held = item
	held_changed.emit(item)

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
	if not menu_station or i < 0 or i >= menu_options.size() or not menu_options[i]["enabled"]:
		return
	var action: Callable = menu_options[i]["action"]
	close_menu()
	action.call()

# ------------------------------------------------------------ repair ----
func _update_repair(delta: float) -> void:
	repair_window = null
	if is_dead() or focus:
		return
	var best := repair_reach
	for w in get_tree().get_nodes_in_group("windows"):
		var d := Vector2(w.repair_point().x - global_position.x, w.repair_point().z - global_position.z).length()
		if d < best and w.boards_left() < w.boards.size():
			best = d
			repair_window = w
	if repair_window and Input.is_action_pressed("interact"):
		repair_progress += delta / repair_time
		if repair_progress >= 1.0:
			repair_progress = 0.0
			repair_window.repair_board()
	else:
		repair_progress = 0.0
