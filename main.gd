# Prototype entry scene: shop + player + zombie spawner + debug HUD.
extends Node3D

const SHAMBLER := preload("res://enemies/shambler/shambler.tscn")
const SCUTTLER := preload("res://enemies/scuttler/scuttler.tscn")
const PICKUP := preload("res://pickups/mushroom/mushroom_pickup.gd")

@export var auto_spawn := true      # tests switch this off
@export var first_zombie_delay := 3.0
@export var spawn_interval := 11.0   # a new Shambler every this many seconds
@export var max_zombies := 12        # alive at once; a spawn is skipped while at the cap
@export var scuttler_every := 3      # every Nth spawn is a Scuttler (0 = never)
@export var drop_delay := 0.6        # seconds after a kill before its mushroom pops out

var _spawn_t := 0.0
var _spawned := 0
var _last_sides: Array[String] = []  # recent lanes, to avoid long streaks on one side

@onready var player: CharacterBody3D = $Player
@onready var shop: Node3D = $ShopGreybox

var _hud: Dictionary = {}
var _hitmark := 0.0
var _kills := 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 0
	var start := shop.get_node_or_null("Markers/PlayerStart") as Node3D
	if start:
		player.global_transform = start.global_transform
	_build_hud()
	player.health_changed.connect(func(_h, _m): _update_health())
	player.hurt.connect(func(_a, _f): _flash_damage())
	player.died.connect(_on_player_died)
	player.mushrooms_changed.connect(func(_n): _update_health())
	for w in player.weapons:
		if w.has_signal("hit"):
			w.hit.connect(_on_hit)
	player.weapon_changed.connect(func(_i, _w): _update_weapon())
	_update_weapon()
	_update_health()
	_spawn_t = first_zombie_delay

# Wave clock: first zombie after first_zombie_delay, then one every
# spawn_interval seconds, on a random lane (never three in a row on the same
# side). Stops when the player dies.
func _physics_process(delta: float) -> void:
	if not auto_spawn or player.is_dead():
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t += spawn_interval
		var n := _spawned + 1
		if scuttler_every > 0 and n % scuttler_every == 0:
			spawn_scuttler(_pick_window())
		else:
			spawn_zombie(_pick_window())

func _pick_window() -> Node3D:
	var windows := get_tree().get_nodes_in_group("windows")
	var pick: Node3D = windows[randi() % windows.size()]
	if _last_sides.size() >= 2 and _last_sides[-1] == _last_sides[-2] and _last_sides[-1] == pick.name:
		for w in windows:
			if w.name != pick.name:
				pick = w
				break
	_last_sides.append(pick.name)
	if _last_sides.size() > 2:
		_last_sides.pop_front()
	return pick

func next_spawn_in() -> float:
	return maxf(_spawn_t, 0.0)

func spawn_scuttler(window: Node3D = null) -> Node:
	return spawn_enemy(SCUTTLER, window)

func spawn_zombie(window: Node3D = null) -> Node:
	return spawn_enemy(SHAMBLER, window)

func spawn_enemy(scene: PackedScene, window: Node3D = null) -> Node:
	if get_tree().get_nodes_in_group("zombies").size() >= max_zombies:
		return null
	var windows := get_tree().get_nodes_in_group("windows")
	if window == null:
		window = windows[randi() % windows.size()]
	_spawned += 1
	var z := scene.instantiate()
	z.setup(window, player)
	add_child(z)
	var spawn: Vector3 = window.lane_spawn()
	z.global_position = spawn + Vector3(randf_range(-0.6, 0.6), 0.05, 0).rotated(Vector3.UP, window.rotation.y)
	z.rotation.y = atan2(window.outward().x, window.outward().z)
	z.died.connect(func(_z): _kills += 1; _update_health(); _drop_later(_z))
	return z

# Every dead Shambler or Scuttler drops one glowing mushroom.
func _drop_later(z: Node3D) -> void:
	var at := z.global_position
	get_tree().create_timer(drop_delay).timeout.connect(func():
		if is_instance_valid(z):
			at = z.global_position
		drop_pickup(at))

func drop_pickup(at: Vector3) -> Node3D:
	var p: Node3D = PICKUP.new()
	add_child(p)
	p.drop(at, at.y)
	return p

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_L: # toggle greybox room/window labels
				var labels := shop.get_node_or_null("GreyboxLabels") as Node3D
				if labels:
					labels.visible = not labels.visible
			KEY_Z:
				spawn_zombie()
			KEY_X:
				spawn_scuttler()
			KEY_R:
				get_tree().reload_current_scene()

func _process(delta: float) -> void:
	_hitmark = maxf(0.0, _hitmark - delta * 4.0)
	_hud["cross"].modulate = Color("#F3A34D") if _hitmark > 0.0 else Color("#E9E1D1")
	_hud["cross"].scale = Vector2.ONE * (1.0 + _hitmark * 0.6)
	_hud["vignette"].color.a = maxf(0.0, _hud["vignette"].color.a - delta * 1.5)
	_update_wave_hud()
	var prompt := ""
	if player.repair_window and not player.is_dead():
		var w = player.repair_window
		prompt = "Hold E to repair %s  (%d/%d)" % [w.name.replace("_", " "), w.boards_left(), w.boards.size()]
		if player.repair_progress > 0.0:
			prompt += "  " + "|".repeat(int(player.repair_progress * 10)).rpad(10, ".")
	_hud["prompt"].text = prompt

func _on_hit(_z: Node, headshot: bool, killed: bool) -> void:
	_hitmark = 1.0
	if killed:
		_hud["prompt"].text = "HEADSHOT" if headshot else ""

func _flash_damage() -> void:
	_hud["vignette"].color.a = 0.45

func _on_player_died() -> void:
	_hud["dead"].visible = true

func _update_weapon() -> void:
	var names := ["1  PISTOL (placeholder)", "2  KNIFE", "3  DAGGER (alt hand)"]
	_hud["weapon"].text = names[player.weapon_index] if player.weapon_index < names.size() else ""

func _update_wave_hud() -> void:
	if not auto_spawn or player.is_dead():
		_hud["wave"].text = ""
		return
	var alive := get_tree().get_nodes_in_group("zombies").size()
	_hud["wave"].text = "NEXT ZOMBIE IN %ds   ·   ZOMBIES %d" % [ceili(next_spawn_in()), alive]

func _update_health() -> void:
	_hud["health"].text = "HEALTH %d   ·   KILLS %d   ·   MUSHROOMS %d" % [int(player.health), _kills, player.mushrooms]

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var vignette := ColorRect.new()
	vignette.color = Color("#C96B35", 0.0)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vignette)
	var cross := Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 22)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.pivot_offset = cross.size * 0.5
	layer.add_child(cross)
	var help := Label.new()
	help.text = "WASD move · Shift sprint · Space jump · 1/2/3 or wheel switch weapon · LMB fire / slash · RMB stab · hold E repair · Z spawn Shambler · X spawn Scuttler · R restart · L labels · Esc mouse"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color("#E9E1D1", 0.6))
	help.position = Vector2(16, 12)
	layer.add_child(help)
	var health := Label.new()
	health.add_theme_font_size_override("font_size", 18)
	health.add_theme_color_override("font_color", Color("#E9E1D1"))
	health.add_theme_color_override("font_outline_color", Color("#101C2C"))
	health.add_theme_constant_override("outline_size", 6)
	health.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	health.position += Vector2(16, -40)
	layer.add_child(health)
	var prompt := Label.new()
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color("#65C9C2"))
	prompt.add_theme_color_override("font_outline_color", Color("#101C2C"))
	prompt.add_theme_constant_override("outline_size", 6)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position += Vector2(-200, -90)
	prompt.size = Vector2(400, 30)
	layer.add_child(prompt)
	var dead := Label.new()
	dead.text = "YOU DIED\npress R to restart"
	dead.visible = false
	dead.add_theme_font_size_override("font_size", 40)
	dead.add_theme_color_override("font_color", Color("#C96B35"))
	dead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dead.position += Vector2(-200, -60)
	dead.size = Vector2(400, 120)
	layer.add_child(dead)
	var weapon := Label.new()
	weapon.add_theme_font_size_override("font_size", 18)
	weapon.add_theme_color_override("font_color", Color("#F3A34D"))
	weapon.add_theme_color_override("font_outline_color", Color("#101C2C"))
	weapon.add_theme_constant_override("outline_size", 6)
	weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon.position += Vector2(-316, -40)
	weapon.size = Vector2(300, 30)
	layer.add_child(weapon)
	var wave := Label.new()
	wave.add_theme_font_size_override("font_size", 16)
	wave.add_theme_color_override("font_color", Color("#65C9C2"))
	wave.add_theme_color_override("font_outline_color", Color("#101C2C"))
	wave.add_theme_constant_override("outline_size", 6)
	wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	wave.position += Vector2(-336, 34)
	wave.size = Vector2(320, 24)
	layer.add_child(wave)
	_hud = {"wave": wave, "cross": cross, "health": health, "prompt": prompt, "dead": dead, "vignette": vignette, "weapon": weapon}

# Keep the desktop responsive when this window is not being played.
# Headless test simulations retain their normal unrestricted speed.
func _notification(what: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Engine.max_fps = 15
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Engine.max_fps = int(ProjectSettings.get_setting("application/run/max_fps", 60))
