# Prototype entry scene: shop + player + zombie spawner + debug HUD.
extends Node3D

const SHAMBLER := preload("res://enemies/shambler/shambler.tscn")

@export var auto_spawn := true      # tests switch this off
@export var first_zombie_delay := 3.0
@export var max_zombies := 12

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
	for w in player.weapons:
		if w.has_signal("hit"):
			w.hit.connect(_on_hit)
	player.weapon_changed.connect(func(_i, _w): _update_weapon())
	_update_weapon()
	_update_health()
	if auto_spawn:
		get_tree().create_timer(first_zombie_delay).timeout.connect(func(): spawn_zombie(shop.get_node("Windows/Window_A")))

func spawn_zombie(window: Node3D = null) -> Node:
	if get_tree().get_nodes_in_group("zombies").size() >= max_zombies:
		return null
	var windows := get_tree().get_nodes_in_group("windows")
	if window == null:
		window = windows[randi() % windows.size()]
	var z := SHAMBLER.instantiate()
	z.setup(window, player)
	add_child(z)
	var spawn: Vector3 = window.lane_spawn()
	z.global_position = spawn + Vector3(randf_range(-0.6, 0.6), 0.05, 0).rotated(Vector3.UP, window.rotation.y)
	z.rotation.y = atan2(window.outward().x, window.outward().z)
	z.died.connect(func(_z): _kills += 1; _update_health())
	return z

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_L: # toggle greybox room/window labels
				var labels := shop.get_node_or_null("GreyboxLabels") as Node3D
				if labels:
					labels.visible = not labels.visible
			KEY_Z:
				spawn_zombie()
			KEY_R:
				get_tree().reload_current_scene()

func _process(delta: float) -> void:
	_hitmark = maxf(0.0, _hitmark - delta * 4.0)
	_hud["cross"].modulate = Color("#F3A34D") if _hitmark > 0.0 else Color("#E9E1D1")
	_hud["cross"].scale = Vector2.ONE * (1.0 + _hitmark * 0.6)
	_hud["vignette"].color.a = maxf(0.0, _hud["vignette"].color.a - delta * 1.5)
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
	var names := ["1  PISTOL (placeholder)", "2  KNIFE"]
	_hud["weapon"].text = names[player.weapon_index] if player.weapon_index < names.size() else ""

func _update_health() -> void:
	_hud["health"].text = "HEALTH %d   ·   KILLS %d" % [int(player.health), _kills]

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
	help.text = "WASD move · Shift sprint · Space jump · 1/2 or wheel switch weapon · LMB fire / slash · RMB stab · hold E repair · Z spawn zombie · R restart · L labels · Esc mouse"
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
	_hud = {"cross": cross, "health": health, "prompt": prompt, "dead": dead, "vignette": vignette, "weapon": weapon}

# Keep the desktop responsive when this window is not being played.
# Headless test simulations retain their normal unrestricted speed.
func _notification(what: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Engine.max_fps = 15
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Engine.max_fps = int(ProjectSettings.get_setting("application/run/max_fps", 60))
