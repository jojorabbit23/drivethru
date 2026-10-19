# The prep bench beside the grill (docs/COOKING_DESIGN.md "Burger Assembly").
# One press of E: takes the cooked patties, a bun and a topping, and hands you
# a wrapped burger. No ingredient dragging, no minigame - but you see it built:
# bun, pressed mushroom(s), topping and lid drop onto the board and get wrapped
# (game/burger_stack.gd; the burger is yours the moment you press E).
#
# It builds what's on the order ticket (the customer waiting, or pulling in;
# game/recipes.gd):
#   a single     the ordered kind (warming tray first, then the grill), else
#                whatever's oldest on the tray, else the longest-waiting ready
#                patty on the grill, else a burnt one (bagged as salvage)
#   a double or  needs all its patties ready (tray first); until then the
#   the special  prompt says what's missing. Burnt salvage still works.
# The prompt says what you'll get before you press: recipe and quality.
# Quality is fixed by how long the patty sat READY (the warming tray stops that
# clock); a two-patty burger is only as good as its older patty:
#   up to 4 s   PERFECT (+$6 tip)    up to 8 s   GOOD (+$3)
#   longer      STANDARD             burnt       SALVAGE ($15, any order)
# The bun tray and topping tub show what's left (a bun per 2 in stock, up to 8).
extends "res://game/station.gd"

const BurgerStack = preload("res://game/burger_stack.gd")
const Recipes = preload("res://game/recipes.gd")

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
		var leaf := add_box(Vector3(0.06, 0.012, 0.05), Vector3((i % 3) * 0.07, 0.074 + (i / 3) * 0.006, -0.16 + (i / 3) * 0.07), P.OXIDISED_TEAL if i % 2 == 0 else P.OXIDISED_TEAL.lightened(0.15))
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
func ticket() -> String:
	if hatch and hatch.car != null and is_instance_valid(hatch.car) and hatch.car.state != "leaving":
		return hatch.car.order
	return ""

# What E would make now:
#   {order, picks: [{from: "tray"|"grill", i, patty}], burnt}   ready to bag
#   {order, missing: [kinds], have: n}                           a double/special that isn't ready
#   {}                                                           nothing cooked
func plan() -> Dictionary:
	var t := ticket()
	if t != "" and not Recipes.is_single(t):
		var picks := []
		var missing := []
		var used_tray := {}
		var used_grill := {}
		for kind: String in Recipes.patties(t):
			var p := _find(kind, used_tray, used_grill)
			if p.is_empty():
				missing.append(kind)
			else:
				picks.append(p)
		if missing.is_empty():
			return {"order": t, "picks": picks, "burnt": false}
		var b := _burnt()
		if not b.is_empty():
			return {"order": "salvage", "picks": [b], "burnt": true, "missing": missing}
		return {"order": t, "missing": missing, "have": picks.size()}
	# a single (or no ticket): the ordered kind, else the oldest done patty
	var want := t
	var p := {}
	if want != "":
		p = _find(want, {}, {})
	if p.is_empty() and tray != null and not tray.held.is_empty():
		p = {"from": "tray", "i": 0, "patty": tray.held[0]}
	if p.is_empty() and grill != null:
		var g: int = grill.find_patty("", true)
		if g >= 0:
			p = {"from": "grill", "i": g, "patty": grill.describe(g)}
	if not p.is_empty():
		return {"order": String(p["patty"]["kind"]), "picks": [p], "burnt": false}
	var b := _burnt()
	if not b.is_empty():
		return {"order": "salvage", "picks": [b], "burnt": true}
	return {}

# A ready patty of `kind`, tray first, skipping ones already picked.
func _find(kind: String, used_tray: Dictionary, used_grill: Dictionary) -> Dictionary:
	if tray != null:
		for i in tray.held.size():
			if tray.held[i]["kind"] == kind and not used_tray.has(i):
				used_tray[i] = true
				return {"from": "tray", "i": i, "patty": tray.held[i]}
	if grill != null:
		var best := -1
		for i in grill.slot_count():
			if grill.state_of(i) == "ready" and grill.kind_of(i) == kind and not used_grill.has(i):
				if best < 0 or (grill.slots[i]["t"] as float) > (grill.slots[best]["t"] as float):
					best = i
		if best >= 0:
			used_grill[best] = true
			return {"from": "grill", "i": best, "patty": grill.describe(best)}
	return {}

func _burnt() -> Dictionary:
	if grill == null:
		return {}
	var b: int = grill.find_patty("")
	if b >= 0 and grill.state_of(b) == "burnt":
		return {"from": "grill", "i": b, "patty": grill.describe(b)}
	return {}

static func _quality(picks: Array) -> String:
	var worst := 0.0
	for p: Dictionary in picks:
		worst = maxf(worst, float(p["patty"]["ready_for"]))
	return Economy.quality_for(worst, false)

func prompt(player: Node) -> String:
	var e := economy()
	if player.held != "":
		return "PREP  ·  hands full: serve that burger first"
	if not e.can_bag():
		return "PREP  ·  out of %s: buy supplies at the terminal" % ("buns" if e.buns <= 0 else "toppings")
	var pl := plan()
	if pl.is_empty():
		return "PREP  ·  no cooked patty yet"
	if not pl.has("picks"):
		# "needs 2 red patties", "needs a ready blue patty too", "needs a red and a blue patty"
		var counts := {}
		for k: String in pl["missing"]:
			counts[k] = int(counts.get(k, 0)) + 1
		var parts := []
		for k: String in counts:
			var n: int = counts[k]
			parts.append(("%d %s" % [n, String(Economy.KIND_NAME[k]).to_lower()]) if n > 1 else ("a %s%s" % ["ready " if int(pl["have"]) > 0 else "", String(Economy.KIND_NAME[k]).to_lower()]))
		var many: bool = (pl["missing"] as Array).size() > 1
		return "PREP  ·  the %s needs %s patt%s%s" % [Recipes.name_of(pl["order"]).to_lower(), " and ".join(parts), "ies" if many else "y", " too" if int(pl["have"]) > 0 else ""]
	if pl["burnt"]:
		return "E  bag burnt patty as salvage ($%d)" % Economy.SALVAGE_PRICE
	var from_tray := false
	for p: Dictionary in pl["picks"]:
		from_tray = from_tray or p["from"] == "tray"
	return "E  bag %s burger  ·  %s%s" % [Recipes.name_of(pl["order"]).to_lower(), _quality(pl["picks"]).to_upper(), "  (from the tray)" if from_tray else ""]

func interact(player: Node) -> void:
	bag(player)

func bag(player: Node) -> bool:
	var e := economy()
	if player.held != "" or not e.can_bag():
		return false
	var pl := plan()
	if pl.is_empty() or not pl.has("picks"):
		return false
	var picks: Array = pl["picks"]
	var quality := "burnt" if pl["burnt"] else _quality(picks)
	var kinds := []
	# take them: tray indices high to low so the rest don't shift
	var tray_idx := []
	for p: Dictionary in picks:
		kinds.append(p["patty"]["kind"])
		if p["from"] == "tray":
			tray_idx.append(int(p["i"]))
		else:
			grill.take_slot(int(p["i"]))
	tray_idx.sort()
	tray_idx.reverse()
	for i: int in tray_idx:
		tray.take_at(i)
	e.take_bun_and_topping()
	var order: String = pl["order"]
	if pl["burnt"]:
		order = String(kinds[0])
	player.set_held("burger", {"kind": order, "quality": quality, "patties": kinds})
	Sfx.play_at(self, "thunk", global_position + Vector3(0, 0.2, 0))
	var show := BurgerStack.new()
	show.position = Vector3(0.33, 0.02, 0.05)
	add_child(show)
	show.play(kinds, pl["burnt"])
	return true
