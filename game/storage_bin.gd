# Storeroom mushroom bin. E stores every mushroom you're carrying; one stored
# mushroom makes one common patty at the grill. Its sign shows the stock.
extends "res://game/station.gd"

var _sign: Label3D
var _pile: Array[MeshInstance3D] = []

func _ready() -> void:
	# a slatted crate, open on top, with a heap that grows with the stock
	var wood := P.BURNT_ORANGE.darkened(0.35)
	add_box(Vector3(0.7, 0.06, 0.55), Vector3(0, 0.03, 0), P.WET_CHARCOAL)
	for side in [-1.0, 1.0]:
		add_box(Vector3(0.7, 0.5, 0.05), Vector3(0, 0.3, side * 0.25), wood)
		add_box(Vector3(0.05, 0.5, 0.55), Vector3(side * 0.33, 0.3, 0), wood)
	for y in [0.15, 0.42]:
		add_box(Vector3(0.72, 0.04, 0.57), Vector3(0, y, 0), wood.darkened(0.2))
	for i in 9:
		var cap := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.07
		sm.radial_segments = 6
		sm.rings = 2
		cap.mesh = sm
		cap.material_override = flat(P.BURNT_ORANGE)
		cap.position = Vector3(-0.22 + (i % 3) * 0.22, 0.48 + (i / 3) * 0.035, -0.14 + (i / 3) * 0.14)
		add_child(cap)
		_pile.append(cap)
	add_solid(Vector3(0.72, 0.58, 0.57), Vector3(0, 0.29, 0))
	# player_clip (layer 5) up to head height, like the shop's other furniture:
	# you can't climb onto the bin and wedge yourself against the wall
	var clip := add_solid(Vector3(0.76, 2.4, 0.61), Vector3(0, 1.2, 0))
	clip.collision_layer = 16
	add_zone(Vector3(0.9, 0.9, 0.75), Vector3(0, 0.45, 0))
	var icon := Icons.sprite("mushroom", 0.014)
	icon.position = Vector3(-0.2, 1.05, 0)
	add_child(icon)
	_sign = add_label("", Vector3(0.12, 1.05, 0))
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_refresh.call_deferred()

func _refresh() -> void:
	var e := economy()
	if e and not e.changed.is_connected(_refresh):
		e.changed.connect(_refresh)
	var n: int = e.mushrooms if e else 0
	_sign.text = "%d" % n
	for i in _pile.size():
		_pile[i].visible = i < n

func prompt(player: Node) -> String:
	var carrying: int = player.mushrooms
	if carrying > 0:
		return "E  store %d mushroom%s" % [carrying, "" if carrying == 1 else "s"]
	return "MUSHROOM STORE  ·  %d stored  ·  kill zombies for more" % economy().mushrooms

func interact(player: Node) -> void:
	var carrying: int = player.mushrooms
	if carrying <= 0:
		return
	player.mushrooms = 0
	player.mushrooms_changed.emit(0)
	economy().store_mushrooms(carrying)
	Sfx.play_at(self, "thunk", global_position + Vector3(0, 0.5, 0))
