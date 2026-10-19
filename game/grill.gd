# Flat-top griddle with three patty slots. Look at it and press E for a small
# menu: bag a ready burger, scrape off a burnt patty, or put a new patty on.
# Each slot runs RAW -> COOKING -> READY -> BURNT (docs/GAME_DESIGN.md):
#   0-1 s raw (grey, silent), 1-6 s cooking (browning, steam, sizzle),
#   6-18 s ready (golden, bell, tick icon, countdown), then burnt (black,
#   heavy smoke, cross icon). Every state has its own colour, icon, word,
#   particles and sound, so none relies on colour alone.
extends "res://game/station.gd"

const RAW_TIME := 1.0
const COOK_TIME := 6.0
const BURN_TIME := 18.0
const SLOT_X := [-0.38, 0.0, 0.38]

signal patty_state(slot: int, state: String)

var slots: Array[Dictionary] = []    # {state, t, mesh, icon, label, steam, smoke}
var _sizzle: AudioStreamPlayer3D

func _ready() -> void:
	for i in SLOT_X.size():
		var root := Node3D.new()
		root.position = Vector3(SLOT_X[i], 0.0, 0.0)
		add_child(root)
		var mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.1
		cyl.bottom_radius = 0.105
		cyl.height = 0.035
		cyl.radial_segments = 8
		cyl.rings = 1
		mesh.mesh = cyl
		mesh.position = Vector3(0, 0.02, 0)
		mesh.material_override = flat(P.CONCRETE_GREY)
		mesh.visible = false
		root.add_child(mesh)
		var icon := Icons.sprite("raw", 0.011)
		icon.position = Vector3(0, 0.36, 0)
		icon.visible = false
		root.add_child(icon)
		var label := Label3D.new()
		label.position = Vector3(0, 0.22, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 32
		label.pixel_size = 0.0016
		label.outline_size = 8
		label.outline_modulate = P.MIDNIGHT_TYNE
		label.visible = false
		root.add_child(label)
		var steam := _particles(P.WARM_CHALK, 0.03, 14, 0.9)
		root.add_child(steam)
		var smoke := _particles(P.WET_CHARCOAL, 0.07, 26, 1.6)
		root.add_child(smoke)
		slots.append({"state": "", "t": 0.0, "mesh": mesh, "icon": icon, "label": label, "steam": steam, "smoke": smoke})
	_sizzle = AudioStreamPlayer3D.new()
	_sizzle.stream = Sfx.stream("sizzle")
	_sizzle.volume_db = -12.0
	_sizzle.unit_size = 3.0
	add_child(_sizzle)
	add_zone(Vector3(1.25, 0.45, 0.7), Vector3(0, 0.18, 0))

func _particles(colour: Color, size: float, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 0.25, 0)
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.35
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.06
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(colour, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.mesh = q
	p.position = Vector3(0, 0.05, 0)
	return p

func _process(delta: float) -> void:
	var noisy := false
	for i in slots.size():
		var s := slots[i]
		if s["state"] == "":
			continue
		s["t"] = (s["t"] as float) + delta
		var t: float = s["t"]
		var state := "raw"
		if t >= BURN_TIME:
			state = "burnt"
		elif t >= COOK_TIME:
			state = "ready"
		elif t >= RAW_TIME:
			state = "cooking"
		if state != s["state"]:
			_enter(i, state)
		_show(i)
		noisy = noisy or state != "raw"
	if noisy and not _sizzle.playing and is_inside_tree():
		_sizzle.play()
	elif not noisy and _sizzle.playing:
		_sizzle.stop()

func _enter(i: int, state: String) -> void:
	var s := slots[i]
	s["state"] = state
	(s["icon"] as Sprite3D).texture = Icons.texture(state)
	(s["steam"] as CPUParticles3D).emitting = state == "cooking" or state == "ready"
	(s["smoke"] as CPUParticles3D).emitting = state == "burnt"
	if state == "ready":
		Sfx.play_at(self, "bell", global_position + Vector3(SLOT_X[i], 0.3, 0))
	patty_state.emit(i, state)

func _show(i: int) -> void:
	var s := slots[i]
	var state: String = s["state"]
	var t: float = s["t"]
	var mesh := s["mesh"] as MeshInstance3D
	var label := s["label"] as Label3D
	var colour := P.CONCRETE_GREY
	match state:
		"raw":
			label.text = "RAW"
			label.modulate = P.WARM_CHALK
		"cooking":
			var k := (t - RAW_TIME) / (COOK_TIME - RAW_TIME)
			colour = P.CONCRETE_GREY.lerp(P.BURNT_ORANGE.darkened(0.25), k)
			label.text = "COOKING %d%%" % int(k * 100.0)
			label.modulate = P.AMBER_GLOW
		"ready":
			colour = P.BURNT_ORANGE.darkened(0.25).lerp(P.AMBER_GLOW.darkened(0.35), 0.5)
			label.text = "READY  %ds" % ceili(BURN_TIME - t)
			label.modulate = P.ELECTRIC_TEAL
		"burnt":
			colour = P.WET_CHARCOAL.darkened(0.3)
			label.text = "BURNT"
			label.modulate = P.BURNT_ORANGE
	(mesh.material_override as StandardMaterial3D).albedo_color = colour

func _place(i: int) -> void:
	var s := slots[i]
	s["t"] = 0.0
	(s["mesh"] as MeshInstance3D).visible = true
	(s["icon"] as Sprite3D).visible = true
	(s["label"] as Label3D).visible = true
	_enter(i, "raw")
	_show(i)
	Sfx.play_at(self, "thunk", global_position + Vector3(SLOT_X[i], 0.1, 0))

func _clear(i: int) -> void:
	var s := slots[i]
	s["state"] = ""
	(s["mesh"] as MeshInstance3D).visible = false
	(s["icon"] as Sprite3D).visible = false
	(s["label"] as Label3D).visible = false
	(s["steam"] as CPUParticles3D).emitting = false
	(s["smoke"] as CPUParticles3D).emitting = false
	patty_state.emit(i, "")

func first(state: String) -> int:
	for i in slots.size():
		if slots[i]["state"] == state:
			return i
	return -1

func state_of(i: int) -> String:
	return slots[i]["state"]

# --------------------------------------------------------------- use ----
func prompt(player: Node) -> String:
	var e := economy()
	var ready := first("ready")
	if ready >= 0 and player.held == "":
		return "E  GRILL  ·  burger ready to bag"
	if first("burnt") >= 0:
		return "E  GRILL  ·  a patty is burning"
	return "E  GRILL  ·  %d mushroom%s stored" % [e.mushrooms, "" if e.mushrooms == 1 else "s"]

func interact(player: Node) -> void:
	player.open_menu(self, options(player))

func options(player: Node) -> Array:
	var e := economy()
	var opts := []
	if first("ready") >= 0:
		if player.held != "":
			opts.append({"label": "Bag burger  (hands full)", "enabled": false, "icon": "burger", "action": Callable()})
		elif e.buns <= 0:
			opts.append({"label": "Bag burger  (no buns - buy at the terminal)", "enabled": false, "icon": "burger", "action": Callable()})
		else:
			opts.append({"label": "Bag burger  (%d bun%s)" % [e.buns, "" if e.buns == 1 else "s"], "enabled": true, "icon": "burger", "action": bag_burger.bind(player)})
	if first("burnt") >= 0:
		opts.append({"label": "Scrape burnt patty", "enabled": true, "icon": "burnt", "action": scrape})
	var free := first("")
	var label := "Common patty  x%d" % e.mushrooms
	if free < 0:
		label += "  (grill full)"
	opts.append({"label": label, "enabled": free >= 0 and e.mushrooms > 0, "icon": "raw", "action": add_patty})
	return opts

func add_patty() -> bool:
	var free := first("")
	if free < 0 or not economy().take_mushroom():
		return false
	_place(free)
	return true

func bag_burger(player: Node) -> bool:
	var i := first("ready")
	if i < 0 or player.held != "" or not economy().take_bun():
		return false
	_clear(i)
	player.set_held("burger")
	Sfx.play_at(self, "thunk", global_position + Vector3(SLOT_X[i], 0.1, 0))
	return true

func scrape() -> bool:
	var i := first("burnt")
	if i < 0:
		return false
	_clear(i)
	return true
