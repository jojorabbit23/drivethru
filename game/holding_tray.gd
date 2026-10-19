# Heated holding tray (docs/COOKING_DESIGN.md "Kitchen Upgrades"), bought at
# the shop terminal. A steel pass shelf under a heat lamp, on the wall between
# the prep bench and the grill. Look at it and press E: it takes the grill's
# ready patties (longest-waiting first, up to 2) and keeps them warm, so their
# quality stops slipping while you're off fighting. The prep bench takes from
# the tray before the grill.
# Hidden (and not focusable) until bought.
extends "res://game/station.gd"

const MUSHROOM := preload("res://pickups/mushroom/mushroom_pickup_mesh.res")
const ALBEDO := preload("res://pickups/mushroom/mushroom_albedo.png")
const PATTY_SHADER := preload("res://game/patty.gdshader")

var grill: Node = null
var held: Array[Dictionary] = []     # {kind, ready_for}
var _zone: Area3D
var _pans: Array[Node3D] = []
var _lamp: OmniLight3D
var _label: Label3D
var _t := 0.0

func _ready() -> void:
	_zone = add_zone(Vector3(0.62, 0.36, 0.42), Vector3(0, 0.1, 0.05))
	# shelf on two brackets, steel tray, two pans
	add_box(Vector3(0.66, 0.03, 0.3), Vector3(0, -0.015, 0), P.CONCRETE_GREY.darkened(0.2))
	for x in [-0.27, 0.27]:
		add_box(Vector3(0.03, 0.12, 0.2), Vector3(x, -0.09, -0.04), P.WET_CHARCOAL)
	add_box(Vector3(0.6, 0.012, 0.24), Vector3(0, 0.006, 0.0), P.CONCRETE_GREY.lightened(0.15))
	for i in Economy.TRAY_SLOTS:
		var pan := Node3D.new()
		pan.position = Vector3(-0.14 + i * 0.28, 0.012, 0.0)
		add_child(pan)
		add_box(Vector3(0.24, 0.01, 0.2), Vector3(0, 0.005, 0), P.WET_CHARCOAL, pan)
		var m := MeshInstance3D.new()
		m.name = "Patty"
		m.mesh = MUSHROOM
		m.scale = Vector3(0.5, 0.35, 0.5)
		m.rotation.x = PI                           # gills up, like on the grill
		m.position = Vector3(0, 0.04, 0)
		var mat := ShaderMaterial.new()
		mat.shader = PATTY_SHADER
		mat.set_shader_parameter("detail", ALBEDO)
		mat.set_shader_parameter("cook", 0.82)
		m.material_override = mat
		m.visible = false
		pan.add_child(m)
		_pans.append(pan)
	# heat lamp: a hood on an arm, an amber bulb and its light
	add_box(Vector3(0.03, 0.34, 0.03), Vector3(0.0, 0.2, -0.13), P.WET_CHARCOAL)
	add_box(Vector3(0.5, 0.06, 0.16), Vector3(0.0, 0.37, -0.03), P.WET_CHARCOAL)
	var bulb := add_box(Vector3(0.42, 0.02, 0.08), Vector3(0.0, 0.335, -0.03), P.AMBER_GLOW)
	var bm := bulb.material_override as StandardMaterial3D
	bm.emission_enabled = true          # a light source: allowed to glow
	bm.emission = P.AMBER_GLOW
	bm.emission_energy_multiplier = 1.4
	_lamp = OmniLight3D.new()
	_lamp.light_color = P.AMBER_GLOW
	_lamp.light_energy = 0.9
	_lamp.omni_range = 0.9
	_lamp.position = Vector3(0, 0.25, 0.02)
	add_child(_lamp)
	_label = add_label("", Vector3(0, 0.2, 0.12), P.WARM_CHALK, 18)
	_label.pixel_size = 0.0022
	_label.outline_size = 0
	_refresh.call_deferred()

func _process(delta: float) -> void:
	_t += delta
	# a faint heat shimmer on the held patties
	for i in _pans.size():
		var m := _pans[i].get_node("Patty") as Node3D
		if m.visible:
			m.position.y = 0.04 + sin(_t * 3.0 + i) * 0.002
	_lamp.light_energy = 0.85 + sin(_t * 7.0) * 0.03

func _refresh() -> void:
	var e := economy()
	if e and not e.changed.is_connected(_refresh):
		e.changed.connect(_refresh)
	var on: bool = e != null and e.has_tray
	visible = on
	_zone.collision_layer = 32 if on else 0
	for i in _pans.size():
		var m := _pans[i].get_node("Patty") as MeshInstance3D
		m.visible = i < held.size()
		if m.visible:
			(m.material_override as ShaderMaterial).set_shader_parameter("cap_colour", Icons.KIND_COLOUR[held[i]["kind"]])
	_label.text = "WARM %d/%d" % [held.size(), Economy.TRAY_SLOTS] if on else ""

func free_slots() -> int:
	return Economy.TRAY_SLOTS - held.size()

func prompt(_player: Node) -> String:
	var ready: int = grill.count("ready") if grill else 0
	if free_slots() > 0 and ready > 0:
		var n := mini(ready, free_slots())
		return "E  move %d ready patt%s to the warming tray" % [n, "y" if n == 1 else "ies"]
	if held.is_empty():
		return "WARMING TRAY  ·  empty: E moves ready patties here"
	return "WARMING TRAY  ·  %d kept warm (the prep bench takes these first)" % held.size()

func interact(_player: Node) -> void:
	store_from_grill()

# Moves ready patties off the grill (longest-waiting first). Returns how many.
func store_from_grill() -> int:
	if grill == null:
		return 0
	var n := 0
	while free_slots() > 0 and grill.count("ready") > 0:
		var p: Dictionary = grill.take_patty("", true)
		if p.is_empty():
			break
		held.append({"kind": p["kind"], "ready_for": p["ready_for"]})
		n += 1
	if n > 0:
		Sfx.play_at(self, "thunk", global_position)
		_refresh()
	return n

# For the prep bench: the wanted kind if held, else the oldest. {} if empty.
func take(want := "") -> Dictionary:
	if held.is_empty():
		return {}
	var idx := 0
	for i in held.size():
		if held[i]["kind"] == want:
			idx = i
			break
	var p: Dictionary = held[idx]
	held.remove_at(idx)
	_refresh()
	return {"kind": p["kind"], "ready_for": p["ready_for"], "burnt": false}

func take_at(i: int) -> Dictionary:
	if i < 0 or i >= held.size():
		return {}
	var p: Dictionary = held[i]
	held.remove_at(i)
	_refresh()
	return {"kind": p["kind"], "ready_for": p["ready_for"], "burnt": false}

func has_kind(kind: String) -> bool:
	for p in held:
		if p["kind"] == kind:
			return true
	return false
