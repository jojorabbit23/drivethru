# The kitchen's ticket rail: a steel strip on the wall above the counter. When
# a customer pulls in, a paper ticket slides down with their burger on it (the
# recipe's pixel icon and its name) and a bar that shrinks as their patience
# runs out, turning orange near the end. So you can see what to cook without
# walking to the hatch. Not a station: it only shows.
extends Node3D

const P = preload("res://core/palette.gd")
const Icons = preload("res://game/icons.gd")
const Economy = preload("res://game/economy.gd")
const Sfx = preload("res://game/sfx.gd")
const Recipes = preload("res://game/recipes.gd")

var hatch: Node = null
var _ticket: Node3D
var _icon: Sprite3D
var _name: Label3D
var _bar_bg: MeshInstance3D
var _bar: MeshInstance3D
var _idle: Label3D
var _shown_car: Node = null
var _drop := 0.0

func _ready() -> void:
	_box(Vector3(0.9, 0.035, 0.03), Vector3(0, 0, 0), P.CONCRETE_GREY.lightened(0.1))      # the rail
	_box(Vector3(0.9, 0.008, 0.035), Vector3(0, -0.02, 0.0), P.WET_CHARCOAL)                # its lip
	_ticket = Node3D.new()
	add_child(_ticket)
	_box(Vector3(0.2, 0.26, 0.004), Vector3(0, -0.15, 0.02), P.WARM_CHALK, _ticket)          # paper
	_box(Vector3(0.03, 0.03, 0.01), Vector3(0, -0.01, 0.025), P.WET_CHARCOAL, _ticket)       # clip
	_icon = Icons.sprite("burger", 0.0075)
	_icon.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_icon.position = Vector3(0, -0.105, 0.024)
	_ticket.add_child(_icon)
	_name = Label3D.new()
	_name.font_size = 18
	_name.pixel_size = 0.0017
	_name.outline_size = 0
	_name.modulate = P.WET_CHARCOAL
	_name.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_name.position = Vector3(0, -0.205, 0.024)
	_name.line_spacing = -2.0
	_ticket.add_child(_name)
	_bar_bg = _box(Vector3(0.16, 0.016, 0.004), Vector3(0, -0.255, 0.024), P.CONCRETE_GREY, _ticket)
	_bar = _box(Vector3(0.16, 0.016, 0.004), Vector3(0, -0.255, 0.026), P.OXIDISED_TEAL, _ticket)
	_idle = Label3D.new()
	_idle.font_size = 18
	_idle.pixel_size = 0.0017
	_idle.outline_size = 0
	_idle.modulate = P.CONCRETE_GREY
	_idle.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_idle.text = "NO ORDERS"
	_idle.position = Vector3(0, -0.06, 0.03)
	add_child(_idle)
	_ticket.visible = false

func _box(size: Vector3, pos: Vector3, colour: Color, parent: Node3D = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m

# The car whose ticket is up: the one waiting, or the one pulling in.
func current_car() -> Node:
	if hatch == null or hatch.car == null or not is_instance_valid(hatch.car):
		return null
	return hatch.car if hatch.car.state != "leaving" else null

func _process(delta: float) -> void:
	var c := current_car()
	if c != _shown_car:
		_shown_car = c
		if c:
			_icon.texture = Icons.texture("burger_" + String(c.order))
			_name.text = Recipes.ticket_text(c.order,maxi(0,c.quantity-c.received))
			_drop = 1.0
			Sfx.play_at(self, "click", global_position, -10.0)
	_ticket.visible = c != null
	_idle.visible = c == null
	if c == null:
		return
	_name.text=Recipes.ticket_text(c.order,maxi(0,c.quantity-c.received))
	# the ticket slides down onto the rail
	_drop = maxf(0.0, _drop - delta * 4.0)
	_ticket.position.y = 0.12 * _drop * _drop
	# patience: full while it's still driving in, then shrinking
	var left := 1.0
	if c.state == "waiting":
		left = 1.0 - c.waited_fraction()
	_bar.scale.x = maxf(0.001, left)
	_bar.position.x = -0.08 * (1.0 - left)
	(_bar.material_override as StandardMaterial3D).albedo_color = P.OXIDISED_TEAL if left > 0.3 else P.BURNT_ORANGE
	_name.modulate = P.WET_CHARCOAL if c.state == "waiting" else P.CONCRETE_GREY
