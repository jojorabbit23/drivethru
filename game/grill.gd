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
#
# The patty IS the mushroom: a whole one drops onto the plate gills-up (stalk
# showing, cap in its kind's colour underneath), the spatula presses it down,
# and it browns, goldens or chars as it cooks. Look at a cooking patty and
# press E to FLIP it (once) onto its gills, showing the seared cap: it cooks
# the rest 1.6x faster. Optional; an unflipped patty cooks as before.
# Ready (or burnt) patties are taken off by the prep bench when it bags a burger.
extends "res://game/station.gd"

const RAW_TIME := 1.0
const COOK_TIME := 6.0
const MUSHROOM := preload("res://pickups/mushroom/mushroom_pickup_mesh.res")
const ALBEDO := preload("res://pickups/mushroom/mushroom_albedo.png")
const FLIP_RATE := 1.6        # cooking speed once flipped
const SMASHED := Vector3(1.12, 0.7, 1.12)    # pressed down, still a mushroom
const PATTY_SHADER := preload("res://game/patty.gdshader")
const LAYOUT := {2: [-0.22, 0.22], 3: [-0.38, 0.0, 0.38], 4: [-0.43, -0.145, 0.145, 0.43]}

signal patty_state(slot: int, state: String)

var slots: Array[Dictionary] = []    # {state, t, kind, flipped, root, patty, mesh, icon, kind_icon, label, steam, smoke, spit}
var spatula: Node3D
var _spatula_tw: Tween
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
	spatula = _make_spatula()
	add_child(spatula)
	_layout.call_deferred()

# A steel spatula that rests at the right end of the plate and does the
# smashing and flipping.
func _make_spatula() -> Node3D:
	var sp := Node3D.new()
	sp.name = "Spatula"
	add_box(Vector3(0.13, 0.006, 0.11), Vector3(0, 0.003, 0), P.CONCRETE_GREY.lightened(0.25), sp)
	add_box(Vector3(0.025, 0.02, 0.05), Vector3(0, 0.018, 0.075), P.CONCRETE_GREY, sp)
	var handle := add_box(Vector3(0.028, 0.028, 0.17), Vector3(0, 0.04, 0.17), P.WET_CHARCOAL, sp)
	handle.rotation.x = deg_to_rad(-12.0)
	sp.position = _spatula_home()
	sp.rotation.y = deg_to_rad(-20.0)
	return sp

func _spatula_home() -> Vector3:
	return Vector3(0.66, 0.012, 0.12)

func _make_slot() -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	# patty: a pivot at the mushroom's centre, so it can squash and flip in place
	var patty := Node3D.new()
	patty.name = "Patty"
	patty.visible = false
	root.add_child(patty)
	var mesh := MeshInstance3D.new()
	mesh.mesh = MUSHROOM
	mesh.scale = Vector3.ONE * 0.5          # 0.2 m across, 0.17 m tall
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = PATTY_SHADER
	mat.set_shader_parameter("detail", ALBEDO)
	mesh.material_override = mat
	patty.add_child(mesh)
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
	label.font_size = 18           # the pixel font's native size (crisp)
	label.pixel_size = 0.0022
	label.outline_size = 0         # the pixel font has its outline baked in
	label.outline_modulate = P.MIDNIGHT_TYNE
	label.visible = false
	root.add_child(label)
	var steam := _particles(P.WARM_CHALK, 0.03, 14, 0.9)
	root.add_child(steam)
	var smoke := _particles(P.WET_CHARCOAL, 0.07, 26, 1.6)
	root.add_child(smoke)
	var spit := _spits()
	root.add_child(spit)
	return {"state": "", "t": 0.0, "kind": "brown", "flipped": false, "root": root, "patty": patty, "mesh": mesh, "icon": icon, "kind_icon": kind_icon, "label": label, "steam": steam, "smoke": smoke, "spit": spit}

# little amber grease spits that hop off a sizzling patty
func _spits() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 8
	p.lifetime = 0.45
	p.explosiveness = 0.1
	p.direction = Vector3.UP
	p.spread = 55.0
	p.gravity = Vector3(0, -3.0, 0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.11
	p.emission_ring_inner_radius = 0.08
	p.emission_ring_height = 0.0
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.albedo_color = P.AMBER_GLOW
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.mesh = q
	p.position = Vector3(0, 0.03, 0)
	return p

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
		var rate := FLIP_RATE if s["flipped"] and (s["t"] as float) < COOK_TIME else 1.0
		s["t"] = (s["t"] as float) + delta * rate
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
	(s["spit"] as CPUParticles3D).emitting = state == "cooking"
	if state == "ready":
		Sfx.play_at(self, "bell", global_position + Vector3((s["root"] as Node3D).position.x, 0.3, 0))
	patty_state.emit(i, state)

func _show(i: int) -> void:
	var s := slots[i]
	var state: String = s["state"]
	var t: float = s["t"]
	var mesh := s["mesh"] as MeshInstance3D
	var label := s["label"] as Label3D
	var kind := String(Economy.KIND_NAME[s["kind"]]).to_upper()
	var cook := 0.0
	var burnt := 0.0
	match state:
		"raw":
			label.text = "%s\nRAW" % kind
			label.modulate = P.WARM_CHALK
		"cooking":
			var k := (t - RAW_TIME) / (COOK_TIME - RAW_TIME)
			cook = k * 0.7
			label.text = "%s\n%d%%" % [kind, int(k * 100.0)]
			label.modulate = P.AMBER_GLOW
		"ready":
			cook = 0.7 + 0.3 * clampf((t - COOK_TIME) / ready_window(), 0.0, 1.0)
			label.text = "%s\n%ds" % [kind, ceili(burn_time() - t)]
			label.modulate = P.ELECTRIC_TEAL
		"burnt":
			cook = 1.0
			burnt = 1.0
			label.text = "%s\nBURNT" % kind
			label.modulate = P.BURNT_ORANGE
	var mat := mesh.material_override as ShaderMaterial
	mat.set_shader_parameter("cap_colour", Icons.KIND_COLOUR[s["kind"]])
	mat.set_shader_parameter("cook", cook)
	mat.set_shader_parameter("burnt", burnt)
	# a cooking patty simmers: a faint breathing swell, faster once flipped
	var patty := s["patty"] as Node3D
	if state == "cooking" and not patty.has_meta("busy"):
		var w := sin(t * (14.0 if s["flipped"] else 9.0)) * 0.03
		patty.scale = Vector3(SMASHED.x - w * 0.3, SMASHED.y + w, SMASHED.z - w * 0.3)

func _place(i: int, kind: String) -> void:
	var s := slots[i]
	s["t"] = 0.0
	s["kind"] = kind
	s["flipped"] = false
	_drop_and_smash(i)
	(s["icon"] as Sprite3D).visible = true
	(s["kind_icon"] as Sprite3D).texture = Icons.texture("mushroom_" + kind)
	(s["kind_icon"] as Sprite3D).visible = false   # the mushroom itself shows its kind now
	(s["label"] as Label3D).visible = true
	_enter(i, "raw")
	_show(i)
	Sfx.play_at(self, "thunk", global_position + Vector3((s["root"] as Node3D).position.x, 0.1, 0))

# The whole mushroom drops onto the plate, then the spatula smashes it flat.
func _drop_and_smash(i: int) -> void:
	var s := slots[i]
	var patty := s["patty"] as Node3D
	var x := (s["root"] as Node3D).position.x
	patty.visible = true
	_kill_tween(s)
	patty.set_meta("busy", true)
	patty.scale = Vector3.ONE
	patty.rotation = Vector3(PI, randf() * TAU, 0)   # gills up, like a portobello on a plate
	patty.position = Vector3(0, 0.32, 0)
	var whole_y := 0.085                     # resting on its stalk
	var flat_y := 0.085 * SMASHED.y          # smashed: half its new height
	var tw := patty.create_tween()
	s["tw"] = tw
	tw.tween_property(patty, "position:y", whole_y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.18)
	tw.tween_property(patty, "scale", SMASHED, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(patty, "position:y", flat_y, 0.07)
	tw.tween_callback(func() -> void:
		patty.remove_meta("busy")
		var puff := s["steam"] as CPUParticles3D
		puff.restart()
		puff.emitting = s["state"] == "cooking" or s["state"] == "ready" or s["state"] == "raw"
		Sfx.play_at(self, "thunk", global_position + Vector3(x, 0.05, 0), -2.0))
	_swing_spatula([
		[Vector3(x, 0.24, 0.02), 0.18, 0.0],
		[Vector3(x, 0.24, 0.02), 0.2, 0.0],
		[Vector3(x, 0.07, 0.02), 0.07, 0.0],
		[Vector3(x, 0.07, 0.02), 0.12, 0.0],
	])

func can_flip(i: int) -> bool:
	return i >= 0 and i < slot_count() and slots[i]["state"] in ["raw", "cooking"] and not slots[i]["flipped"] and not (slots[i]["patty"] as Node3D).has_meta("busy")

# Flip a cooking patty (once): it hops, turns over, and cooks the rest faster.
func flip(i: int) -> bool:
	if not can_flip(i):
		return false
	var s := slots[i]
	s["flipped"] = true
	var patty := s["patty"] as Node3D
	var x := (s["root"] as Node3D).position.x
	patty.set_meta("busy", true)
	var y0 := patty.position.y
	var tw := patty.create_tween()
	s["tw"] = tw
	tw.tween_interval(0.1)
	tw.tween_property(patty, "position:y", y0 + 0.16, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(patty, "rotation:x", patty.rotation.x + PI, 0.28)
	tw.tween_property(patty, "position:y", y0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		patty.remove_meta("busy")
		patty.scale = SMASHED
		Sfx.play_at(self, "thunk", global_position + Vector3(x, 0.05, 0), -6.0))
	_swing_spatula([
		[Vector3(x + 0.16, 0.012, 0.02), 0.1, 0.0],
		[Vector3(x, 0.03, 0.02), 0.06, 0.0],
		[Vector3(x - 0.02, 0.12, 0.02), 0.12, -0.9],
	])
	return true

# Moves the spatula through [position, seconds, tilt about z] keys, then home.
func _swing_spatula(keys: Array) -> void:
	if _spatula_tw and _spatula_tw.is_valid():
		_spatula_tw.kill()
	_spatula_tw = spatula.create_tween()
	for k: Array in keys:
		_spatula_tw.tween_property(spatula, "position", k[0], k[1]).set_trans(Tween.TRANS_QUAD)
		_spatula_tw.parallel().tween_property(spatula, "rotation:z", k[2], k[1])
	_spatula_tw.tween_property(spatula, "position", _spatula_home(), 0.25).set_trans(Tween.TRANS_QUAD)
	_spatula_tw.parallel().tween_property(spatula, "rotation:z", 0.0, 0.25)

# Which slot the player is looking at (the look ray meets the plate), or -1.
func aimed_slot(player: Node) -> int:
	var cam: Camera3D = player.get("camera")
	if cam == null:
		return -1
	var o := cam.global_position
	var d := -cam.global_basis.z
	var plate_y := global_position.y + 0.03
	if d.y > -0.05:
		return -1
	var hit := to_local(o + d * ((plate_y - o.y) / d.y))
	var best := -1
	var best_d := 0.14
	for i in slot_count():
		var dx := absf(hit.x - (slots[i]["root"] as Node3D).position.x)
		if dx < best_d and absf(hit.z) < 0.25:
			best = i
			best_d = dx
	return best

func _kill_tween(s: Dictionary) -> void:
	var tw: Tween = s.get("tw")
	if tw and tw.is_valid():
		tw.kill()
	(s["patty"] as Node3D).remove_meta("busy")

func _clear(i: int) -> void:
	var s := slots[i]
	_kill_tween(s)
	s["state"] = ""
	for key in ["patty", "icon", "kind_icon", "label"]:
		(s[key] as Node3D).visible = false
	(s["steam"] as CPUParticles3D).emitting = false
	(s["spit"] as CPUParticles3D).emitting = false
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
func prompt(player: Node) -> String:
	var a := aimed_slot(player)
	if can_flip(a):
		return "E  flip the %s patty  ·  cooks faster" % String(Economy.KIND_NAME[slots[a]["kind"]]).to_lower()
	if first("burnt") >= 0:
		return "E  GRILL  ·  a patty is burning!"
	if first("") >= 0:
		return "E  place patty  ·  %d free slot%s" % [count(""), "" if count("") == 1 else "s"]
	return "GRILL FULL  ·  bag ready patties at the prep bench"

func interact(player: Node) -> void:
	if flip(aimed_slot(player)):
		return
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

# Which patty the prep bench (or the warming tray) would take: the wanted kind
# if one is ready (longest-waiting first), else any ready patty, else a burnt
# one (salvage) unless ready_only. -1 if nothing's done.
func find_patty(want := "", ready_only := false) -> int:
	var best := -1
	for pass_i in (2 if ready_only else 3):
		for i in slot_count():
			var s := slots[i]
			var ok: bool = (pass_i == 0 and s["state"] == "ready" and s["kind"] == want) \
				or (pass_i == 1 and s["state"] == "ready") or (pass_i == 2 and s["state"] == "burnt")
			if ok and (best < 0 or (s["t"] as float) > (slots[best]["t"] as float)):
				best = i
		if best >= 0:
			break
	return best

# {kind, ready_for, burnt} of slot i, without taking it.
func describe(i: int) -> Dictionary:
	var s := slots[i]
	return {"kind": s["kind"], "ready_for": (s["t"] as float) - COOK_TIME, "burnt": s["state"] == "burnt"}

# Takes a patty off (see find_patty). Returns {kind, ready_for, burnt} or {}.
func take_patty(want := "", ready_only := false) -> Dictionary:
	var best := find_patty(want, ready_only)
	if best < 0:
		return {}
	var out := describe(best)
	_clear(best)
	return out

# Takes slot i off, whatever it is. {} if empty.
func take_slot(i: int) -> Dictionary:
	if i < 0 or i >= slots.size() or slots[i]["state"] == "":
		return {}
	var out := describe(i)
	_clear(i)
	return out

func scrape() -> bool:
	var i := first("burnt")
	if i < 0:
		return false
	_clear(i)
	return true
