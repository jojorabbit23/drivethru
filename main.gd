# Entry scene: shop + player + waves + the burger loop (stations, economy) + HUD.
extends Node3D

const SHAMBLER := preload("res://enemies/shambler/shambler.tscn")
const SCUTTLER := preload("res://enemies/scuttler/scuttler.tscn")
const LANCER := preload("res://enemies/lancer/lancer.tscn")
const PICKUP := preload("res://pickups/mushroom/mushroom_pickup.gd")

@export var auto_spawn := true      # tests switch this off
@export var first_zombie_delay := 3.0
@export var spawn_interval := 11.0   # a new Shambler every this many seconds
@export var max_zombies := 12        # alive at once; pending wave enemies wait at the cap
@export var scuttler_every := 3      # every Nth spawn is a Scuttler (0 = never)
@export var lancer_every := 5        # from wave 2, every Nth spawn is a Lancer (0 = never; beats a Scuttler)
@export var lancer_from_wave := 2
@export var drop_delay := 0.6        # seconds after a kill before its mushroom pops out
@export var wave_break := 20.0       # seconds between clearing a wave and the next
@export var auto_collect := false    # accessibility: pickups fly to you from anywhere (F2)

signal wave_started(n: int)
signal wave_cleared(n: int)

const P = preload("res://core/palette.gd")
const Economy = preload("res://game/economy.gd")
const Icons = preload("res://game/icons.gd")
const StorageBin = preload("res://game/storage_bin.gd")
const Grill = preload("res://game/grill.gd")
const CustomerWindow = preload("res://game/customer_window.gd")
const ShopTerminal = preload("res://game/shop_terminal.gd")
const PrepBench = preload("res://game/prep_bench.gd")
const HoldingTray = preload("res://game/holding_tray.gd")
const OrderRail = preload("res://game/order_rail.gd")
const Recipes = preload("res://game/recipes.gd")
const MushroomPickupScript = preload("res://pickups/mushroom/mushroom_pickup.gd")

var wave := 0
var _wave_left := 0
var _break_t := -1.0
var economy: Node
var grill: Node3D
var hatch: Node3D
var tray: Node3D
var rail: Node3D
var storage: Node3D
var terminal: Node3D
var bench: Node3D
var _toast_t := 0.0

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
	player.weapon_added.connect(func(w: Node) -> void:
		if w.has_signal("hit"):
			w.hit.connect(_on_hit)
		if w.has_signal("ammo_changed"):
			w.ammo_changed.connect(func(_m, _r): _update_weapon())
		_update_weapon())
	_build_stations()
	player.held_changed.connect(func(_i): _update_status())
	player.menu_changed.connect(_update_menu)
	economy.changed.connect(_update_status)
	var gun := player.get_node_or_null("Head/Camera3D/TestGun")
	if gun:
		gun.ammo_changed.connect(func(_m, _r): _update_weapon())
	hatch.customer_arrived.connect(func(_c): _toast("CUSTOMER AT THE WINDOW", P.ELECTRIC_TEAL))
	hatch.customer_served.connect(func(c: int, tip: int):
		var q: String = hatch.last_quality
		_toast("%s  +$%d%s" % ["SALVAGE" if q == "burnt" else q.to_upper(), c + tip, ("  (tip $%d)" % tip) if tip > 0 else ""], P.AMBER_GLOW))
	hatch.customer_missed.connect(func(): _toast("CUSTOMER LEFT", P.CONCRETE_GREY))
	MushroomPickupScript.auto_collect = auto_collect
	_update_weapon()
	_update_health()
	_update_status()
	if auto_spawn:
		_start_wave(1)

# The vertical-slice stations, placed on the generated shop's furniture.
func _build_stations() -> void:
	economy = Node.new()
	economy.set_script(Economy)
	economy.name = "Economy"
	add_child(economy)
	var iz := 4.75   # interior half-depth (tools/build_shop.gd: HALF_D - EXT_OUTER - EXT_INNER)
	storage = _station(StorageBin, "MushroomStore", Vector3(0.55, 0.0, 1.4), 0.0)
	grill = _station(Grill, "Grill", Vector3(2.1, 0.92, -iz + 0.325), 0.0)
	hatch = _station(CustomerWindow, "DriveThruWindow", Vector3(-3.0, 1.0, -5.0), 0.0)
	terminal = _station(ShopTerminal, "ShopTerminal", Vector3(-2.89, 0.77, iz - 0.29), 0.0)
	bench = _station(PrepBench, "PrepBench", Vector3(0.79, 0.92, -iz + 0.325), 0.0)
	# the pass above the counter: warming tray (once bought) and the ticket rail
	tray = _station(HoldingTray, "WarmingTray", Vector3(1.38, 1.36, -iz + 0.17), 0.0)
	tray.grill = grill
	rail = _station(OrderRail, "OrderRail", Vector3(1.4, 2.15, -iz + 0.03), 0.0)
	rail.hatch = hatch
	bench.grill = grill
	bench.hatch = hatch
	bench.tray = tray
	hatch.auto = auto_spawn
	var m := shop.get_node_or_null("Markers")
	if m:
		hatch.set_lane((m.get_node("Customer_Lane_Start") as Node3D).global_position, (m.get_node("Customer_Stop") as Node3D).global_position, (m.get_node("Customer_Lane_End") as Node3D).global_position)

func _station(script: Script, label: String, at: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.set_script(script)
	n.name = label
	add_child(n)
	n.position = at
	n.rotation.y = yaw
	return n

# Waves (docs/GAME_DESIGN.md): wave n sends 4 + 2n enemies, one every
# max(5, 12 - n) seconds (11 s in wave 1), on random lanes (never three in a
# row on one side). When the last one of a wave is dead, a break of
# wave_break seconds, then the next. Stops when the player dies.
func _physics_process(delta: float) -> void:
	if not auto_spawn or player.is_dead():
		return
	if _wave_left > 0:
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t += wave_interval(wave)
			# The cap delays a spawn; it must not erase enemies from the wave.
			if get_tree().get_nodes_in_group("zombies").size() >= max_zombies:
				return
			_wave_left -= 1
			var n := _spawned + 1
			if lancer_every > 0 and wave >= lancer_from_wave and n % lancer_every == 0:
				spawn_lancer(_pick_window())
			elif scuttler_every > 0 and n % scuttler_every == 0:
				spawn_scuttler(_pick_window())
			else:
				spawn_zombie(_pick_window())
	elif get_tree().get_nodes_in_group("zombies").is_empty():
		if _break_t < 0.0:
			_break_t = wave_break
			wave_cleared.emit(wave)
			_toast("WAVE %d CLEARED" % wave, P.ELECTRIC_TEAL)
		_break_t -= delta
		if _break_t <= 0.0:
			_start_wave(wave + 1)

func _start_wave(n: int) -> void:
	wave = n
	_wave_left = wave_size(n)
	_spawn_t = first_zombie_delay if n == 1 else 0.5
	_break_t = -1.0
	wave_started.emit(n)
	_toast("WAVE %d" % n, P.AMBER_GLOW)

static func wave_size(n: int) -> int:
	return 4 + 2 * n

func wave_interval(n: int) -> float:
	return maxf(5.0, spawn_interval + 1.0 - n)

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

func in_break() -> bool:
	return _wave_left == 0 and _break_t >= 0.0

func spawn_scuttler(window: Node3D = null) -> Node:
	return spawn_enemy(SCUTTLER, window)

func spawn_lancer(window: Node3D = null) -> Node:
	return spawn_enemy(LANCER, window)

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
	z.died.connect(func(_z): _kills += 1; economy.add_cash(Economy.KILL_CASH); _update_health(); _drop_later(_z))
	return z

# Every dead enemy drops one glowing mushroom.
func _drop_later(z: Node3D) -> void:
	var at := z.global_position
	var kind := drop_kind(z)
	get_tree().create_timer(drop_delay).timeout.connect(func():
		if is_instance_valid(z):
			at = z.global_position
		drop_pickup(at, kind))

# What each enemy drops (docs/COOKING_DESIGN.md: mushrooms are the livestock):
# Shamblers mostly common brown, sometimes blue; Scuttlers blue, sometimes red;
# Lancers (the tough one) always red.
func drop_kind(enemy: Node) -> String:
	var path := "" if enemy == null else (enemy.get_script() as Script).resource_path
	if path.ends_with("lancer.gd"):
		return "red"
	if path.ends_with("scuttler.gd"):
		return "red" if randf() < 0.3 else "blue"
	return "blue" if randf() < 0.2 else "brown"

func drop_pickup(at: Vector3, kind := "brown") -> Node3D:
	var p: Node3D = PICKUP.new()
	p.kind = kind
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
			KEY_C:
				spawn_lancer()
			KEY_R:
				get_tree().reload_current_scene()
			KEY_F2:
				auto_collect = not auto_collect
				MushroomPickupScript.auto_collect = auto_collect
				_toast("AUTO-COLLECT %s" % ("ON" if auto_collect else "OFF"), P.ELECTRIC_TEAL)

func _process(delta: float) -> void:
	_hitmark = maxf(0.0, _hitmark - delta * 4.0)
	_hud["cross"].modulate = Color("#F3A34D") if _hitmark > 0.0 else Color("#E9E1D1")
	_hud["cross"].scale = Vector2.ONE * (1.0 + _hitmark * 0.6)
	_hud["vignette"].color.a = maxf(0.0, _hud["vignette"].color.a - delta * 1.5)
	_update_wave_hud()
	var prompt := ""
	if player.focus and not player.is_dead():
		prompt = player.focus.prompt(player)
	elif player.repair_window and not player.is_dead():
		var w = player.repair_window
		prompt = "Hold E to repair %s  (%d/%d)" % [w.name.replace("_", " "), w.boards_left(), w.boards.size()]
		if player.repair_progress > 0.0:
			prompt += "  " + "|".repeat(int(player.repair_progress * 10)).rpad(10, ".")
	_hud["prompt"].text = prompt
	if _toast_t > 0.0:
		_toast_t -= delta
		_hud["toast"].modulate.a = clampf(_toast_t / 0.6, 0.0, 1.0)
	if player.menu_station:
		_update_menu()

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
	var text: String = names[player.weapon_index] if player.weapon_index < names.size() else ""
	var gun: Node = player.current_weapon()
	if gun and gun.get("display_name") != null:
		text = "%d  %s" % [player.weapon_index + 1, gun.display_name]
	if gun and gun.get("mag") != null:
		text += "   %d / %d%s" % [gun.mag, gun.reserve, "  RELOADING" if gun.is_reloading() else ("  EMPTY" if gun.mag == 0 and gun.reserve == 0 else "")]
	_hud["weapon"].text = text

func _update_wave_hud() -> void:
	if not auto_spawn or player.is_dead():
		_hud["wave"].text = ""
		return
	var alive := get_tree().get_nodes_in_group("zombies").size()
	if in_break():
		_hud["wave"].text = "WAVE %d IN %ds" % [wave + 1, ceili(_break_t)]
	else:
		_hud["wave"].text = "WAVE %d   ·   %d TO COME   ·   ZOMBIES %d" % [wave, _wave_left, alive]
	if player.current_weapon() and player.current_weapon().get("mag") != null:
		_update_weapon()

func _update_health() -> void:
	_hud["health"].text = "HEALTH %d   ·   KILLS %d   ·   MUSHROOMS %d" % [int(player.health), _kills, player.mushrooms]
	_update_status()

# Top-left: cash; carried mushrooms by kind (stored in brackets); buns and
# toppings; the burger in your hands (kind and quality).
func _update_status() -> void:
	if _hud.is_empty() or economy == null:
		return
	_hud["cash"].text = "$%d" % economy.cash
	for k in Economy.KINDS:
		_hud["carry_" + k].text = "%d (%d)" % [player.carried[k], economy.stock[k]]
	_hud["buns"].text = "%d" % economy.buns
	_hud["tops"].text = "%d" % economy.toppings
	_hud["held"].visible = player.held != ""
	if player.held == "burger":
		var b: Dictionary = player.held_burger
		(_hud["held_icon"] as TextureRect).texture = Icons.texture("burger_" + String(b.get("kind", "brown")))
		var q: String = b.get("quality", "standard")
		_hud["held_text"].text = "%s %s" % [Recipes.name_of(String(b.get("kind", "brown"))).to_upper(), "SALVAGE" if q == "burnt" else q.to_upper()]

func _update_menu() -> void:
	var box: VBoxContainer = _hud["menu"]
	for c in box.get_children():
		c.queue_free()
	box.visible = player.menu_station != null
	if not box.visible:
		return
	# refresh live (patty counts, cash) while open
	if player.menu_station.has_method("options"):
		player.menu_options = player.menu_station.options(player)
	if player.menu_station.has_method("menu_title"):
		box.add_child(_label(player.menu_station.menu_title(), 18, P.ELECTRIC_TEAL))
	var first := true
	for i in player.menu_options.size():
		var o: Dictionary = player.menu_options[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var key := _label("%d" % (i + 1), 18, P.AMBER_GLOW if o["enabled"] else P.CONCRETE_GREY)
		row.add_child(key)
		row.add_child(_icon(o.get("icon", "burger"), 28))
		var text := _label(o["label"] + ("    [E]" if o["enabled"] and first else ""), 18, P.WARM_CHALK if o["enabled"] else P.CONCRETE_GREY)
		row.add_child(text)
		if o["enabled"]:
			first = false
		box.add_child(row)

func _toast(text: String, colour: Color) -> void:
	if _hud.is_empty():
		return
	_hud["toast"].text = text
	_hud["toast"].add_theme_color_override("font_color", colour)
	_hud["toast"].modulate.a = 1.0
	_toast_t = 2.2

func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", P.MIDNIGHT_TYNE)
	l.add_theme_constant_override("outline_size", 6)
	return l

func _icon(name: String, size: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Icons.texture(name)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t

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
	cross.add_theme_font_size_override("font_size", 18)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.pivot_offset = cross.size * 0.5
	layer.add_child(cross)
	var help := Label.new()
	help.text = "WASD move · Shift sprint · Space jump · 1/2/3 or wheel weapon · LMB fire / slash · RMB stab\nE use / hold E repair · F2 auto-collect · Z/X/C spawn · R restart · Esc mouse"
	help.add_theme_font_size_override("font_size", 18)
	help.add_theme_constant_override("line_spacing", 0)
	help.add_theme_color_override("font_color", Color("#E9E1D1", 0.6))
	help.position = Vector2(16, 8)
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
	weapon.position += Vector2(-416, -40)
	weapon.size = Vector2(400, 30)
	layer.add_child(weapon)
	var wave_label := Label.new()
	wave_label.add_theme_font_size_override("font_size", 16)
	wave_label.add_theme_color_override("font_color", Color("#65C9C2"))
	wave_label.add_theme_color_override("font_outline_color", Color("#101C2C"))
	wave_label.add_theme_constant_override("outline_size", 6)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	wave_label.position += Vector2(-436, 34)
	wave_label.size = Vector2(420, 24)
	layer.add_child(wave_label)
	# status row, top-left under the help line
	var status := HBoxContainer.new()
	status.position = Vector2(16, 48)
	status.add_theme_constant_override("separation", 6)
	layer.add_child(status)
	var cash := _label("$0", 26, P.AMBER_GLOW)
	status.add_child(cash)
	var carries := {}
	for k in Economy.KINDS:
		status.add_child(_label("  ", 18, P.WARM_CHALK))
		status.add_child(_icon("mushroom_" + k, 26))
		var l := _label("0 (0)", 18, P.WARM_CHALK)
		status.add_child(l)
		carries[k] = l
	status.add_child(_label("   ", 18, P.WARM_CHALK))
	status.add_child(_icon("bun", 26))
	var buns := _label("0", 18, P.WARM_CHALK)
	status.add_child(buns)
	status.add_child(_icon("topping", 26))
	var tops := _label("0", 18, P.WARM_CHALK)
	status.add_child(tops)
	var held := HBoxContainer.new()
	held.add_child(_label("   HOLDING", 16, P.ELECTRIC_TEAL))
	var held_icon := _icon("burger", 28)
	held.add_child(held_icon)
	var held_text := _label("BURGER", 16, P.ELECTRIC_TEAL)
	held.add_child(held_text)
	held.visible = false
	status.add_child(held)
	# station menu, above the prompt
	var menu := VBoxContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	menu.position += Vector2(-210, -285)
	menu.size = Vector2(420, 150)
	menu.alignment = BoxContainer.ALIGNMENT_END
	menu.visible = false
	layer.add_child(menu)
	# big centred announcements
	var toast := _label("", 30, P.AMBER_GLOW)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.position += Vector2(-300, 90)
	toast.size = Vector2(600, 40)
	toast.modulate.a = 0.0
	layer.add_child(toast)
	_hud = {"wave": wave_label, "cross": cross, "health": health, "prompt": prompt, "dead": dead, "vignette": vignette, "weapon": weapon,
		"cash": cash, "buns": buns, "tops": tops, "held": held, "held_icon": held_icon, "held_text": held_text, "menu": menu, "toast": toast}
	for k in carries:
		_hud["carry_" + k] = carries[k]

# Keep the desktop responsive when this window is not being played.
# Headless test simulations retain their normal unrestricted speed.
func _notification(what: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Engine.max_fps = 15
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Engine.max_fps = int(ProjectSettings.get_setting("application/run/max_fps", 60))
