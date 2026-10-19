# The prep bench beside the grill (docs/COOKING_DESIGN.md "Burger Assembly").
# One press of E: takes a cooked patty, a bun and a topping, and hands you a
# wrapped burger. No ingredient dragging, no minigame - but you see it built:
# bun, pressed mushroom, topping and lid drop onto the board and get wrapped
# (game/burger_stack.gd; the burger is yours the moment you press E).
# Which patty: the kind on the order ticket (waiting or pulling in; from the warming tray,
# then the grill), else whatever's oldest on the tray, else the longest-waiting
# ready patty on the grill, else a burnt one (bagged as salvage).
# The prompt says what you'll get before you press: kind and quality.
# The burger's quality is fixed by how long the patty sat READY (the warming
# tray stops that clock):
#   up to 4 s   PERFECT ($30 + $6)   up to 8 s   GOOD ($30 + $3)
#   longer      STANDARD ($30)       burnt       SALVAGE ($15, any order)
# The bun tray and topping tub show what's left (a bun per 2 in stock, up to 8).
extends "res://game/station.gd"

const BurgerStack = preload("res://game/burger_stack.gd")

var grill: Node = null
var hatch: Node = null
var tray: Node = null
var _buns: Array[Node3D] = []
var _greens: Array[Node3D] = []

func _ready() -> void:
	add_zone(Vector3(1.0, 0.4, 0.62), Vector3(0, 0.12, 0))
	# bun tray (left), topping tub (middle), chopping board (right)
	add_box(Vector3(0.34, 0.03, 0.24), Vector3(-0.3, 0.015, -0.1), P.CONCRETE_GREY)
	add_box(Vector3(0.26, 0.07, 0.2), Vector3(0.08, 0.035, -0.12), P.CONCRETE_GREY.darkened(0.2))
	add_box(Vector3(0.24, 0.006, 0.18), Vector3(0.08, 0.066, -0.12), P.WET_CHARCOAL)
	add_box(Vector3(0.3, 0.02, 0.24), Vector3(0.33, 0.01, 0.05), P.BURNT_ORANGE.darkened(0.3))
	for i in 8:
		var bun := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.042
		s.height = 0.045
		s.radial_segments = 8
		s.rings = 3
		s.is_hemisphere = true
		bun.mesh = s
		bun.material_override = flat(P.AMBER_GLOW.darkened(0.15))
		bun.position = Vector3(-0.42 + (i % 4) * 0.08, 0.03 + (i / 4) * 0.025, -0.15 + (i / 4) * 0.08)
		bun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bun)
		_buns.append(bun)
	for i in 6:
		var leaf := add_box(Vector3(0.06, 0.012, 0.05), Vector3(0.0 + (i % 3) * 0.07 - 0.0, 0.074 + (i / 3) * 0.006, -0.16 + (i / 3) * 0.07), P.OXIDISED_TEAL if i % 2 == 0 else P.OXIDISED_TEAL.lightened(0.15))
		leaf.rotation.y = 0.4 * i
		_greens.append(leaf)
	add_label("PREP", Vector3(0.38, 0.22, -0.05), P.WARM_CHALK, 36)
	_stock.call_deferred()

func _stock() -> void:
	var e := economy()
	if e == null:
		return
	if not e.changed.is_connected(_stock):
		e.changed.connect(_stock)
	var nb := ceili(minf(e.buns, 16) / 2.0)
	for i in _buns.size():
		_buns[i].visible = i < nb
	var ng := ceili(minf(e.toppings, 12) / 2.0)
	for i in _greens.size():
		_greens[i].visible = i < ng

# The order on the ticket rail: the customer waiting, or the one pulling in.
func _wanted() -> String:
	if hatch and hatch.car != null and is_instance_valid(hatch.car) and hatch.car.state != "leaving":
		return hatch.car.order
	return ""

# Where the next burger's patty comes from: {from: "tray"|"grill", patty: {...}} or {}.
func next_patty() -> Dictionary:
	var want := _wanted()
	var g := -1
	if grill:
		g = grill.find_patty(want, true)
	var on_tray: bool = tray != null and not tray.held.is_empty()
	if on_tray and want != "" and tray.has_kind(want):
		return {"from": "tray", "patty": tray.held[_tray_index(want)]}
	if g >= 0 and want != "" and grill.kind_of(g) == want:
		return {"from": "grill", "patty": grill.describe(g)}
	if on_tray:
		return {"from": "tray", "patty": tray.held[_tray_index(want)]}
	if g >= 0:
		return {"from": "grill", "patty": grill.describe(g)}
	var b: int = grill.find_patty(want) if grill else -1
	if b >= 0:
		return {"from": "grill", "patty": grill.describe(b)}
	return {}

func _tray_index(want: String) -> int:
	for i in tray.held.size():
		if tray.held[i]["kind"] == want:
			return i
	return 0

func prompt(player: Node) -> String:
	var e := economy()
	if player.held != "":
		return "PREP  ·  hands full: serve that burger first"
	if not e.can_bag():
		return "PREP  ·  out of %s: buy supplies at the terminal" % ("buns" if e.buns <= 0 else "toppings")
	var n := next_patty()
	if n.is_empty():
		return "PREP  ·  no cooked patty yet"
	var p: Dictionary = n["patty"]
	if p.get("burnt", false):
		return "E  bag burnt patty as salvage ($%d)" % Economy.SALVAGE_PRICE
	var q := Economy.quality_for(p["ready_for"], false)
	return "E  bag %s burger  ·  %s%s" % [String(Economy.KIND_NAME[p["kind"]]).to_lower(), q.to_upper(), "  (from the tray)" if n["from"] == "tray" else ""]

func interact(player: Node) -> void:
	bag(player)

func bag(player: Node) -> bool:
	var e := economy()
	if player.held != "" or not e.can_bag():
		return false
	var n := next_patty()
	if n.is_empty():
		return false
	var patty: Dictionary
	if n["from"] == "tray":
		patty = tray.take(_wanted())
	else:
		patty = grill.take_patty(_wanted())
	if patty.is_empty():
		return false
	e.take_bun_and_topping()
	var quality := Economy.quality_for(patty["ready_for"], patty["burnt"])
	player.set_held("burger", {"kind": patty["kind"], "quality": quality})
	Sfx.play_at(self, "thunk", global_position + Vector3(0, 0.2, 0))
	var show := BurgerStack.new()
	show.position = Vector3(0.33, 0.02, 0.05)
	add_child(show)
	show.play(patty["kind"], patty["burnt"])
	return true
