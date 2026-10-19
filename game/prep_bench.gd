# The prep bench beside the grill (docs/COOKING_DESIGN.md "Burger Assembly").
# One press of E: takes a cooked patty off the grill, a bun and a topping, and
# hands you a wrapped burger. No ingredient dragging, no minigame.
# Which patty: the kind the waiting customer ordered if one is ready, else the
# longest-waiting ready patty, else a burnt one (bagged as salvage).
# The burger's quality is fixed here by how long the patty sat READY:
#   up to 4 s   PERFECT ($30 + $6)   up to 8 s   GOOD ($30 + $3)
#   longer      STANDARD ($30)       burnt       SALVAGE ($15, any order)
extends "res://game/station.gd"

var grill: Node = null
var hatch: Node = null

func _ready() -> void:
	add_zone(Vector3(1.0, 0.4, 0.62), Vector3(0, 0.12, 0))
	# a stack of wrapped burgers waiting to be filled, and the bun + topping trays
	add_box(Vector3(0.34, 0.05, 0.24), Vector3(-0.3, 0.025, -0.1), P.CONCRETE_GREY)
	add_box(Vector3(0.34, 0.05, 0.24), Vector3(0.1, 0.025, -0.1), P.CONCRETE_GREY)
	var bun := Icons.sprite("bun", 0.01)
	bun.position = Vector3(-0.3, 0.2, -0.1)
	add_child(bun)
	var top := Icons.sprite("topping", 0.01)
	top.position = Vector3(0.1, 0.2, -0.1)
	add_child(top)
	add_label("PREP", Vector3(0.38, 0.22, -0.05), P.WARM_CHALK, 36)

func _wanted() -> String:
	if hatch and hatch.has_method("waiting_car"):
		var c: Node = hatch.waiting_car()
		if c:
			return c.order
	return ""

func prompt(player: Node) -> String:
	var e := economy()
	if player.held != "":
		return "PREP  ·  hands full: serve that burger first"
	if not e.can_bag():
		return "PREP  ·  out of %s: buy supplies at the terminal" % ("buns" if e.buns <= 0 else "toppings")
	if grill == null or (grill.first("ready") < 0 and grill.first("burnt") < 0):
		return "PREP  ·  no cooked patty yet"
	if grill.first("ready") < 0:
		return "E  bag burnt patty as salvage ($%d)" % Economy.SALVAGE_PRICE
	return "E  bag burger"

func interact(player: Node) -> void:
	bag(player)

func bag(player: Node) -> bool:
	var e := economy()
	if player.held != "" or grill == null or not e.can_bag():
		return false
	var patty: Dictionary = grill.take_patty(_wanted())
	if patty.is_empty():
		return false
	e.take_bun_and_topping()
	var quality := Economy.quality_for(patty["ready_for"], patty["burnt"])
	player.set_held("burger", {"kind": patty["kind"], "quality": quality})
	Sfx.play_at(self, "thunk", global_position + Vector3(0, 0.2, 0))
	return true
