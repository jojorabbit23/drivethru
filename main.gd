# Entry scene: shop + player + waves + the burger loop (stations, economy) + HUD.
extends Node3D

const SHAMBLER := preload("res://enemies/shambler/shambler.tscn")
const SCUTTLER := preload("res://enemies/scuttler/scuttler.tscn")
const LANCER := preload("res://enemies/lancer/lancer.tscn")
const SCIENTIST := preload("res://enemies/scientist/scientist.tscn")
const HOLLOWHEAD := preload("res://enemies/hollowhead/hollowhead.tscn")
const PICKUP := preload("res://pickups/mushroom/mushroom_pickup.gd")
const HEALTH_PICKUP := preload("res://pickups/health/health_pickup.gd")
@export_range(0.0,1.0,0.001) var health_drop_chance: float=0.075

@export var building_decorations_enabled: bool=false # saved set, opt in when placing later
@export var auto_spawn := true      # tests switch this off
@export var first_zombie_delay := 3.0
@export var spawn_interval := 11.0   # a new Shambler every this many seconds
@export var max_zombies := 12        # alive at once; pending wave enemies wait at the cap
@export var scientist_every := 4     # occupies an ordinary wave slot, never adds enemies
@export var scuttler_every := 3      # every Nth spawn is a Scuttler (0 = never)
@export var lancer_every := 5        # every Nth spawn is a Lancer (0 = never; beats a Scuttler)
# One new enemy type per wave, each announced as it arrives: wave 1 is
# Shamblers and Hollowheads only.
@export var scuttler_from_wave := 2
@export var scientist_from_wave := 3
@export var lancer_from_wave := 4
@export var max_group := 4           # later waves arrive in groups of up to this many
const GROUP_STAGGER := 0.35          # seconds between members of one group
const CAP_RETRY := 1.0               # a spawn held back by max_zombies retries this soon
@export var drop_delay := 0.6        # seconds after a kill before its mushroom pops out
@export var wave_break := 20.0       # seconds between clearing wave 1 and wave 2;
                                     # +2 s per wave after that, up to 30 s (orders grow too)
@export var auto_collect := false    # accessibility: pickups fly to you from anywhere (F2)

signal wave_started(n: int)
signal wave_cleared(n: int)

const P = preload("res://core/palette.gd")
const Economy = preload("res://game/economy.gd")
const Icons = preload("res://game/icons.gd")
const StorageBin = preload("res://game/storage_bin.gd")
const GrinderStation = preload("res://game/grinder_station.gd")
const Grill = preload("res://game/grill.gd")
const CustomerWindow = preload("res://game/customer_window.gd")
const ShopTerminal = preload("res://game/shop_terminal.gd")
const PrepBench = preload("res://game/prep_bench.gd")
const HoldingTray = preload("res://game/holding_tray.gd")
const OrderRail = preload("res://game/order_rail.gd")
const DiscountBox = preload("res://game/discount_box.gd")
const KitchenRadio = preload("res://game/kitchen_radio.gd")
const ServingTray = preload("res://game/serving_tray.gd")
const BurgerBin = preload("res://game/burger_bin.gd")
const BurgerItems = preload("res://game/burger_items.gd")
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
var grinder_station: Node3D
var terminal: Node3D
var bench: Node3D
var delivery: Node3D
var serving_tray: Node3D
var burger_bin: Node3D
var _toast_t := 0.0

var _spawn_t := 0.0
var _spawned := 0
var _group_left := 0                 # members of the current group still to spawn
var _group_windows: Array[String] = []  # windows this group has used: spread it out
var _wave_kills_at_start := 0
var _wave_earned_at_start := 0
var _last_sides: Array[String] = []  # recent lanes, to avoid long streaks on one side

@onready var player: CharacterBody3D = $Player
@onready var shop: Node3D = $ShopGreybox

var _hud: Dictionary = {}
var _burger_hud: Array[Dictionary] = []
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
	wave_started.connect(player.unlock_burger_slots)
	for w in player.weapons:
		if w.has_signal("hit"):
			w.hit.connect(_on_hit)
		if w.has_signal("ammo_changed"):
			w.ammo_changed.connect(_on_ammo_changed)
	player.weapon_changed.connect(func(_i, _w): _update_weapon())
	player.weapon_added.connect(func(w: Node) -> void:
		if w.has_signal("hit"):
			w.hit.connect(_on_hit)
		if w.has_signal("ammo_changed"):
			w.ammo_changed.connect(_on_ammo_changed)
		_update_weapon())
	_build_stations()
	add_to_group("decorated_game")
	if building_decorations_enabled:
		add_child(load("res://props/building_decor/generated/building_decor.tscn").instantiate())
	player.held_changed.connect(func(_i): _update_status())
	player.menu_changed.connect(_update_menu)
	economy.changed.connect(_update_status)
	hatch.customer_arrived.connect(func(c: Node):
		_toast("CUSTOMER AT THE WINDOW", P.ELECTRIC_TEAL)
		_warn_missing(c))
	economy.changed.connect(_check_supplies)
	hatch.customer_served.connect(func(c: int, tip: int):
		var q: String = hatch.last_quality
		_toast("%s  +$%d%s" % ["SALVAGE" if q == "burnt" else q.to_upper(), c + tip, ("  (tip $%d)" % tip) if tip > 0 else ""], P.AMBER_GLOW))
	hatch.customer_missed.connect(func(): _toast("CUSTOMER LEFT", P.CONCRETE_GREY))
	MushroomPickupScript.auto_collect = auto_collect
	var clarity: CanvasLayer=preload("res://presentation/clarity_hud.gd").new()
	clarity.name="ClarityHUD"
	add_child(clarity)
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
	# second drop-off at Codex's kitchen grinder (presentation/kitchen/visuals.gd)
	grinder_station = _station(GrinderStation, "GrinderStation", Vector3(5.42, 0.95, -0.42), PI)
	grill = _station(Grill, "Grill", Vector3(2.1, 0.92, -iz + 0.325), 0.0)
	hatch = _station(CustomerWindow, "DriveThruWindow", Vector3(-3.0, 1.0, -5.0), 0.0)
	serving_tray = _station(ServingTray,"ServingTray",Vector3(-3.0,1.02,-4.40),0.0)
	burger_bin = _station(BurgerBin,"BurgerBin",Vector3(-1.82,0.20,-4.04),0.0)
	var discount: Node=_station(DiscountBox,"DiscountBox",Vector3(-3.76,1.02,-4.40),0.0)
	discount.tray=serving_tray
	hatch.serving_tray=serving_tray
	terminal = _station(ShopTerminal, "ShopTerminal", Vector3(-2.89, 0.77, iz - 0.29), 0.0)
	bench = _station(PrepBench, "PrepBench", Vector3(0.79, 0.92, -iz + 0.325), 0.0)
	_station(KitchenRadio,"KitchenRadio",Vector3(4.40,1.045,-4.50),0.0)
	# the pass above the counter: warming tray (once bought) and the ticket rail
	tray = _station(HoldingTray, "WarmingTray", Vector3(1.38, 1.36, -iz + 0.17), 0.0)
	tray.grill = grill
	rail = _station(OrderRail, "OrderRail", Vector3(1.4, 2.15, -iz + 0.03), 0.0)
	rail.hatch = hatch
	bench.grill = grill
	bench.hatch = hatch
	bench.tray = tray
	delivery=preload("res://game/delivery_station.gd").new()
	delivery.name="DeliveryStation";delivery.position=Vector3(5.70,0,6.25);delivery.rotation.y=-PI/2.0
	delivery.garage=shop.get_node("Garage");delivery.bench=bench;delivery.auto=auto_spawn
	add_child(delivery)
	bench.delivery_hatch=delivery
	delivery.customer_arrived.connect(func(_ticket: Node):_toast("DELIVERY CALL  ·  stock the garage tray",P.ELECTRIC_TEAL))
	delivery.customer_served.connect(func(cash: int,tip: int):_toast("DELIVERY +$%d  TIP +$%d"%[cash,tip],P.AMBER_GLOW))
	delivery.customer_missed.connect(func():_toast("DELIVERY CANCELLED",P.BURNT_ORANGE))
	hatch.auto = auto_spawn
	var m := shop.get_node_or_null("Markers")
	if m:
		hatch.set_lane((m.get_node("Customer_Lane_Start") as Node3D).global_position, (m.get_node("Customer_Stop") as Node3D).global_position, (m.get_node("Customer_Lane_End") as Node3D).global_position)
	# orders side (Job A): reputation, serve streak and the order HUD
	preload("res://game/reputation.gd").attach(self)

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
			# The cap delays a spawn (soon retried); it must not erase enemies from the wave.
			if get_tree().get_nodes_in_group("zombies").size() >= max_zombies:
				_spawn_t = CAP_RETRY
				return
			if _group_left <= 0:
				_group_left = mini(group_size(wave), _wave_left)
				_group_windows.clear()
			_group_left -= 1
			# the next member of this group follows quickly; then the next group
			_spawn_t += GROUP_STAGGER if _group_left > 0 else wave_interval(wave) * group_size(wave) - GROUP_STAGGER * (group_size(wave) - 1)
			_wave_left -= 1
			_spawn_next()
	elif get_tree().get_nodes_in_group("zombies").is_empty():
		if _break_t < 0.0:
			_break_t = break_length(wave)
			wave_cleared.emit(wave)
			_toast("WAVE %d CLEARED  ·  %d KILLS  ·  +$%d" % [wave, _kills - _wave_kills_at_start, economy.earned - _wave_earned_at_start], P.ELECTRIC_TEAL)
		_break_t -= delta
		if _break_t <= 0.0:
			_start_wave(wave + 1)

# Which enemy the next wave slot is: a fixed rotation on the running spawn
# count, each type joining from its own wave.
func _spawn_next() -> void:
	var n := _spawned + 1
	var window := _pick_window(_group_windows)
	_group_windows.append(window.name)
	if lancer_every > 0 and wave >= lancer_from_wave and n % lancer_every == 0:
		spawn_lancer(window)
	elif scuttler_every > 0 and wave >= scuttler_from_wave and n % scuttler_every == 0:
		spawn_scuttler(window)
	elif scientist_every > 0 and wave >= scientist_from_wave and n % scientist_every == 0:
		spawn_scientist(window)
	elif n % 2 == 1:
		spawn_hollowhead(window)
	else:
		spawn_zombie(window)

func _start_wave(n: int) -> void:
	wave = n
	_wave_left = wave_size(n)
	_group_left = 0
	_spawn_t = first_zombie_delay if n == 1 else 0.5
	_break_t = -1.0
	_wave_kills_at_start = _kills
	_wave_earned_at_start = economy.earned if economy else 0
	wave_started.emit(n)
	_toast(wave_banner(n), P.AMBER_GLOW)

# "WAVE 4  ·  LANCERS: AIM FOR THE CAP" when a new enemy type joins.
func wave_banner(n: int) -> String:
	var news := ""
	if scuttler_every > 0 and n == scuttler_from_wave:
		news = "SCUTTLERS: FAST AND LOW"
	elif scientist_every > 0 and n == scientist_from_wave:
		news = "SCIENTISTS: THE HEAD COMES OFF"
	elif lancer_every > 0 and n == lancer_from_wave:
		news = "LANCERS: THEY STAB THROUGH BOARDS"
	elif group_size(n) > group_size(n - 1):
		news = "THEY COME IN %s NOW" % {2: "PAIRS", 3: "THREES", 4: "FOURS"}.get(group_size(n), "GROUPS")
	return "WAVE %d" % n + ("  ·  " + news if news != "" else "")

static func wave_size(n: int) -> int:
	return 4 + 2 * n

# Average seconds per enemy (a group of g arrives every g x this).
func wave_interval(n: int) -> float:
	return maxf(5.0, spawn_interval + 1.0 - n)

# Waves 1-3 arrive one at a time, 4-6 in pairs, 7-9 in threes, then fours.
func group_size(n: int) -> int:
	return clampi(1 + (n - 1) / 3, 1, max_group)

func break_length(cleared: int) -> float:
	return wave_break + minf(10.0, 2.0 * float(cleared - 1))

# A random open window; never three in a row on one side, and (when there are
# enough windows) not one this group has already used.
func _pick_window(avoid: Array[String] = []) -> Node3D:
	var windows := get_tree().get_nodes_in_group("windows")
	var fresh := windows.filter(func(w: Node): return not avoid.has(String(w.name)))
	if fresh.is_empty():
		fresh = windows
	var pick: Node3D = fresh[randi() % fresh.size()]
	if not avoid.is_empty():
		_last_sides.append(pick.name)
		if _last_sides.size() > 2:
			_last_sides.pop_front()
		return pick
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

func spawn_scientist(window: Node3D = null) -> Node:
	return spawn_enemy(SCIENTIST, window)

func spawn_hollowhead(window: Node3D = null) -> Node:
	return spawn_enemy(HOLLOWHEAD, window)

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

var _pending_mushrooms: Dictionary={"brown":0,"blue":0,"red":0}

# Every dead enemy drops one glowing mushroom.
func _drop_later(z: Node3D) -> void:
	var at := z.global_position
	var kind := drop_kind(z)
	_pending_mushrooms[kind]+=1
	var health_drop: bool=randf() < health_drop_chance
	get_tree().create_timer(drop_delay).timeout.connect(func():
		if is_instance_valid(z):
			at = z.global_position
		_pending_mushrooms[kind]-=1
		drop_pickup(at, kind)
		if health_drop:drop_health_pickup(at))

func drop_health_pickup(at: Vector3) -> Node3D:
	var bottle: Node3D=HEALTH_PICKUP.new()
	bottle.healed.connect(func(amount: float):_toast("+%d HP" % int(amount),P.ELECTRIC_TEAL))
	add_child(bottle)
	bottle.drop(at,at.y)
	return bottle

# Scarcity changes odds within each enemy's existing drop pool; never adds loot.
# Include loose and already-rolled drops to avoid over-correcting after rapid kills.
func mushroom_supply() -> Dictionary:
	var supply: Dictionary=_pending_mushrooms.duplicate()
	for kind: String in Economy.KINDS:
		supply[kind]+=int(economy.stock.get(kind,0))+int(player.carried.get(kind,0))
	for pickup: Node in get_tree().get_nodes_in_group("pickups"):
		if not pickup._taken and not pickup.is_queued_for_deletion():
			supply[pickup.kind]+=pickup.value
	return supply

func drop_weights(enemy: Node) -> Dictionary:
	var path: String="" if enemy==null or enemy.get_script()==null else (enemy.get_script() as Script).resource_path
	var weights: Dictionary={"brown":.8,"blue":.2}
	if path.ends_with("lancer.gd"):return {"red":1.0}
	if path.ends_with("scuttler.gd"):weights={"blue":.7,"red":.3}
	var supply: Dictionary=mushroom_supply()
	var highest: int=0
	for kind: String in Economy.KINDS:highest=maxi(highest,int(supply[kind]))
	var total: float=0.0
	for kind: String in weights:
		# A two-mushroom buffer softens small differences; boost is capped below 4x.
		var shortage: float=float(highest-int(supply[kind]))/float(highest+2)
		weights[kind]*=1.0+3.0*shortage
		total+=float(weights[kind])
	for kind: String in weights:weights[kind]/=total
	return weights

func drop_kind(enemy: Node) -> String:
	var weights: Dictionary=drop_weights(enemy)
	var roll: float=randf()
	var last: String="brown"
	for kind: String in weights:
		last=kind
		roll-=float(weights[kind])
		if roll<0:return kind
	return last

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
			KEY_H:
				spawn_hollowhead()
			KEY_B:
				spawn_scientist()
			KEY_R:
				var weapon: Node = player.current_weapon()
				if player.is_dead() or weapon == null or not weapon.has_method("reload"):
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

func _on_ammo_changed(_mag: int = 0, _reserve: int = 0) -> void:
	_update_weapon()

func _update_weapon() -> void:
	var names := ["1  PISTOL", "2  KNIFE", "3  CROP DUSTER", "4  DAGGER (alt hand)"]
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
	for i in 4:
		var entry: Dictionary=_burger_hud[i]
		var occupied: bool=i<player.burgers.size()
		var unlocked: bool=i<player.burger_capacity
		var selected: bool=occupied and i==player.selected_burger
		(entry.style as StyleBoxFlat).border_color=P.AMBER_GLOW if selected else P.BLUE_SLATE
		(entry.icon as TextureRect).modulate=Color.WHITE if occupied else Color(1,1,1,0.22 if unlocked else 0.07)
		(entry.icon as TextureRect).texture=Icons.texture("burger_"+String(player.burgers[i].get("kind","brown"))) if occupied else Icons.texture("burger")
		(entry.badge as TextureRect).visible=occupied
		if occupied:(entry.badge as TextureRect).texture=Icons.texture(BurgerItems.icon(player.burgers[i]))
		(entry.label as Label).text=BurgerItems.timer(player.burgers[i]) if occupied else ("EMPTY" if unlocked else "W%d" % (i*3))
		(entry.label as Label).modulate=P.AMBER_GLOW if occupied and BurgerItems.cold(player.burgers[i]) else P.WARM_CHALK
	_hud["held_text"].text="V  SELECT  %d/%d" % [player.burgers.size(),player.burger_capacity]
	if player.held=="burger":
		_hud["held_text"].text+="\n%s  %s" % [Recipes.name_of(String(player.held_burger.get("kind","brown"))).to_upper(),"COLD" if BurgerItems.cold(player.held_burger) else String(player.held_burger.get("quality","standard")).to_upper()]

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

# QoL: say so when an order can't be made from anything you have, so the
# player knows to hunt that colour (drops favour scarce kinds) or skip it.
func _warn_missing(c: Node) -> void:
	var missing := missing_kinds(c)
	if not missing.is_empty():
		_toast("NO %s MUSHROOMS FOR THIS ORDER" % " OR ".join(missing.map(func(k: String): return String(Economy.KIND_NAME[k]).to_upper())), P.BURNT_ORANGE)

# Patty kinds an order still needs that are nowhere: not stored, not on the
# grill (raw/cooking/ready), not in the warming tray, and no finished burger
# of that recipe in hand or on the serving tray.
func missing_kinds(c: Node) -> Array[String]:
	var out: Array[String] = []
	if c == null or not c.has_method("remaining_lines"):
		return out
	for line: Dictionary in c.remaining_lines():
		var order: String = line.kind
		var made := false
		for b: Dictionary in player.burgers:
			made = made or String(b.get("kind", "")) == order
		if serving_tray:
			for b: Dictionary in serving_tray.items:
				made = made or (not b.is_empty() and String(b.get("kind", "")) == order)
		if made:
			continue
		for kind: String in Recipes.patties(order):
			if out.has(kind) or int(economy.stock[kind]) > 0:
				continue
			var cooking := false
			for i in grill.slot_count():
				cooking = cooking or (grill.kind_of(i) == kind and grill.state_of(i) != "" and grill.state_of(i) != "burnt")
			if not cooking and not (tray and tray.has_kind(kind)):
				out.append(kind)
	return out

# QoL: warn before the buns/toppings run out, and when they do.
var _supply_warned := 99
func _check_supplies() -> void:
	var left: int = mini(economy.buns, economy.toppings)
	if left == 0 and _supply_warned > 0:
		_toast("OUT OF %s  ·  BUY SUPPLIES AT THE TERMINAL" % ("BUNS" if economy.buns <= 0 else "TOPPINGS"), P.BURNT_ORANGE)
	elif left <= 3 and left > 0 and _supply_warned > 3:
		_toast("%d %s LEFT  ·  BUY SUPPLIES SOON" % [left, "BUN" if left == 1 else "BUNS"], P.AMBER_GLOW)
	_supply_warned = left if left <= 3 else 99

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
	held.add_theme_constant_override("separation",6)
	held.position=Vector2(16,88)
	layer.add_child(held)
	for i in 4:
		var panel:=PanelContainer.new()
		var style:=StyleBoxFlat.new()
		style.bg_color=Color(P.MIDNIGHT_TYNE,0.85)
		style.set_border_width_all(2)
		style.set_content_margin_all(5)
		panel.add_theme_stylebox_override("panel",style)
		var column:=VBoxContainer.new()
		var icon:=_icon("burger",28)
		column.add_child(icon)
		var label:=_label("",12,P.WARM_CHALK)
		column.add_child(label)
		panel.add_child(column)
		held.add_child(panel)
		var badge: TextureRect=_icon("freshness_fresh",20)
		column.add_child(badge)
		_burger_hud.append({"style":style,"icon":icon,"label":label,"badge":badge})
	var held_icon: TextureRect=_burger_hud[0].icon
	var held_text := _label("V  SELECT",14,P.ELECTRIC_TEAL)
	held.add_child(held_text)
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
		Engine.max_fps = int(ProjectSettings.get_setting("application/run/max_fps", 0))
