# Flat-top griddle (docs/COOKING_DESIGN.md "Grill Selection / Management").
# Look at it, press E, pick a patty (Common / Blue / Red, with counts, or
# Cancel) and it goes on the first free slot. Under a second. Then it cooks in
# the background while you defend the shop.
#
# Slots: 2 on the Starter Grill; upgrades at the shop terminal give 3, then 4,
# then the Apocalypse Grill (4 slots, a 20 s ready window instead of 12).
# Each slot runs on its own:
#   RAW      0-1 s    grey, no steam, "RAW"
#   COOKING  1-6 s    browning, steam, sizzle, "COOKING n%"
#   READY    6-18 s   golden, bell, tick icon, "READY n s" countdown
#   BURNT    18 s +   black, heavy smoke, cross icon, alarm
# Every state has its own colour, icon, word, particles and sound, so none
# relies on colour alone. Each patty also shows its kind's mushroom icon.
# Ready (or burnt) patties are taken off by the prep bench when it bags a burger.
extends "res://game/station.gd"

const RAW_TIME := 1.0
const COOK_TIME := 6.0
const LAYOUT := {2: [-0.22, 0.22], 3: [-0.38, 0.0, 0.38], 4: [-0.43, -0.145, 0.145, 0.43]}

signal patty_state(slot: int, state: String)

var slots: Array[Dictionary] = []    # {state, t, kind, root, mesh, icon, kind_icon, label, steam, smoke}
var _sizzle: AudioStreamPlayer3D
var _alarm_t := 0.0

func _ready() -> void:
	for i in 4:
		slots.append(_make_slot())
	_sizzle = AudioStreamPlayer3D.new()
	_sizzle.stream = Sfx.stream("sizzle")
	_sizzle.volume_db = -12.0
	_sizzle.unit_size = 3.0
	add_child(_sizzle)
	add_zone(Vector3(1.25, 0.45, 0.7), Vector3(0, 0.18, 0))
	_layout.call_deferred()

func _make_slot() -> Dictionary:
	var root := Node3D.new()
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
	icon.position = Vector3(0, 0.38, 0)
	icon.visible = false
	root.add_child(icon)
	var kind_icon := Icons.sprite("mushroom_brown", 0.008)
	kind_icon.position = Vector3(0, 0.15, 0)
	kind_icon.visible = false
	root.add_child(kind_icon)
	var label := Label3D.new()
	label.position = Vector3(0, 0.25, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.pixel_size = 0.0015
	label.outline_size = 8
	label.outline_modulate = P.MIDNIGHT_TYNE
	label.visible = false
	root.add_child(label)
	var steam := _particles(P.WARM_CHALK, 0.03, 14, 0.9)
	root.add_child(steam)
	var smoke := _particles(P.WET_CHARCOAL, 0.07, 26, 1.6)
	root.add_child(smoke)
	return {"state": "", "t": 0.0, "kind": "brown", "root": root, "mesh": mesh, "icon": icon, "kind_icon": kind_icon, "label": label, "steam": steam, "smoke": smoke}

func slot_count() -> int:
	var e := economy()
	return int(e.grill()[1]) if e else 2

func ready_window() -> float:
	var e := economy()
	return float(e.grill()[3]) if e else 12.0

func burn_time() -> float:
	return COOK_TIME + ready_window()

# Place the active slots across the griddle (after an upgrade too).
func _layout() -> void:
	var e := economy()
	if e and not e.changed.is_connected(_layout):
		e.changed.connect(_layout)
	var xs: Array = LAYOUT[slot_count()]
	for i in slots.size():
		var root := slots[i]["root"] as Node3D
		root.visible = i < xs.size()
		if i < xs.size():
			root.position = Vector3(xs[i], 0, 0)

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
	var burning := false
	for i in slots.size():
		var s := slots[i]
		if s["state"] == "":
			continue
		s["t"] = (s["t"] as float) + delta
		var t: float = s["t"]
		var state := "raw"
		if t >= burn_time():
			state = "burnt"
		elif t >= COOK_TIME:
			state = "ready"
		elif t >= RAW_TIME:
			state = "cooking"
		if state != s["state"]:
			_enter(i, state)
		_show(i)
		noisy = noisy or state != "raw"
		burning = burning or state == "burnt"
	if noisy and not _sizzle.playing and is_inside_tree():
		_sizzle.play()
	elif not noisy and _sizzle.playing:
		_sizzle.stop()
	# the burnt alarm repeats (quietly) until the patty is dealt with
	if burning:
		_alarm_t -= delta
		if _alarm_t <= 0.0:
			_alarm_t = 4.0
			Sfx.play_at(self, "alarm", global_position + Vector3(0, 0.4, 0), -6.0)
	else:
		_alarm_t = 0.0

func _enter(i: int, state: String) -> void:
	var s := slots[i]
	s["state"] = state
	(s["icon"] as Sprite3D).texture = Icons.texture(state)
	(s["steam"] as CPUParticles3D).emitting = state == "cooking" or state == "ready"
	(s["smoke"] as CPUParticles3D).emitting = state == "burnt"
	if state == "ready":
		Sfx.play_at(self, "bell", global_position + Vector3((s["root"] as Node3D).position.x, 0.3, 0))
	patty_state.emit(i, state)

func _show(i: int) -> void:
	var s := slots[i]
	var state: String = s["state"]
	var t: float = s["t"]
	var mesh := s["mesh"] as MeshInstance3D
	var label := s["label"] as Label3D
	var tint: Color = Icons.KIND_COLOUR[s["kind"]]
	var raw_colour := P.CONCRETE_GREY.lerp(tint, 0.35)
	var colour := raw_colour
	match state:
		"raw":
			label.text = "RAW"
			label.modulate = P.WARM_CHALK
		"cooking":
			var k := (t - RAW_TIME) / (COOK_TIME - RAW_TIME)
			colour = raw_colour.lerp(tint.darkened(0.25), k)
			label.text = "COOKING %d%%" % int(k * 100.0)
			label.modulate = P.AMBER_GLOW
		"ready":
			colour = tint.lerp(P.AMBER_GLOW, 0.35).darkened(0.2)
			label.text = "READY  %ds" % ceili(burn_time() - t)
			label.modulate = P.ELECTRIC_TEAL
		"burnt":
			colour = P.WET_CHARCOAL.darkened(0.3)
			label.text = "BURNT"
			label.modulate = P.BURNT_ORANGE
	(mesh.material_override as StandardMaterial3D).albedo_color = colour

func _place(i: int, kind: String) -> void:
	var s := slots[i]
	s["t"] = 0.0
	s["kind"] = kind
	(s["mesh"] as MeshInstance3D).visible = true
	(s["icon"] as Sprite3D).visible = true
	(s["kind_icon"] as Sprite3D).texture = Icons.texture("mushroom_" + kind)
	(s["kind_icon"] as Sprite3D).visible = true
	(s["label"] as Label3D).visible = true
	_enter(i, "raw")
	_show(i)
	Sfx.play_at(self, "thunk", global_position + Vector3((s["root"] as Node3D).position.x, 0.1, 0))

func _clear(i: int) -> void:
	var s := slots[i]
	s["state"] = ""
	for key in ["mesh", "icon", "kind_icon", "label"]:
		(s[key] as Node3D).visible = false
	(s["steam"] as CPUParticles3D).emitting = false
	(s["smoke"] as CPUParticles3D).emitting = false
	patty_state.emit(i, "")

func first(state: String) -> int:
	for i in slot_count():
		if slots[i]["state"] == state:
			return i
	return -1

func state_of(i: int) -> String:
	return slots[i]["state"]

func kind_of(i: int) -> String:
	return slots[i]["kind"]

func count(state: String) -> int:
	var n := 0
	for i in slot_count():
		if slots[i]["state"] == state:
			n += 1
	return n

# --------------------------------------------------------------- use ----
func prompt(_player: Node) -> String:
	if first("burnt") >= 0:
		return "E  GRILL  ·  a patty is burning!"
	if first("") >= 0:
		return "E  place patty  ·  %d free slot%s" % [count(""), "" if count("") == 1 else "s"]
	return "GRILL FULL  ·  bag ready patties at the prep bench"

func interact(player: Node) -> void:
	player.open_menu(self, options(player))

func options(_player: Node) -> Array:
	var e := economy()
	var free := first("") >= 0
	var opts := []
	for kind in Economy.KINDS:
		var n := int(e.stock[kind])
		var label := "%s patty  x%d" % [Economy.KIND_NAME[kind], n]
		if not free:
			label += "  (grill full)"
		opts.append({"label": label, "enabled": free and n > 0, "icon": "mushroom_" + kind, "action": add_patty.bind(kind)})
	if first("burnt") >= 0:
		opts.append({"label": "Scrape burnt patty", "enabled": true, "icon": "burnt", "action": scrape})
	opts.append({"label": "Cancel", "enabled": true, "icon": "cancel", "action": func() -> void: pass})
	return opts

func add_patty(kind := "brown") -> bool:
	var free := first("")
	if free < 0 or not economy().take_mushroom(kind):
		return false
	_place(free, kind)
	return true

# Takes a patty off for the prep bench: the wanted kind if one is ready
# (longest-waiting first), else any ready patty, else a burnt one (salvage).
# Returns {kind, ready_for, burnt} or {} if nothing's done.
func take_patty(want := "") -> Dictionary:
	var best := -1
	for pass_i in 3:
		for i in slot_count():
			var s := slots[i]
			var ok: bool = (pass_i == 0 and s["state"] == "ready" and s["kind"] == want) \
				or (pass_i == 1 and s["state"] == "ready") or (pass_i == 2 and s["state"] == "burnt")
			if ok and (best < 0 or (s["t"] as float) > (slots[best]["t"] as float)):
				best = i
		if best >= 0:
			break
	if best < 0:
		return {}
	var s := slots[best]
	var out := {"kind": s["kind"], "ready_for": (s["t"] as float) - COOK_TIME, "burnt": s["state"] == "burnt"}
	_clear(best)
	return out

func scrape() -> bool:
	var i := first("burnt")
	if i < 0:
		return false
	_clear(i)
	return true
