# Base for things the player looks at and uses with E (storage bin, grill,
# customer window, shop terminal). The player's look-ray hits an Area3D on
# physics layer 6 ("interact") whose meta "station" points back here.
#   prompt(player) -> String   the HUD line while looked at
#   interact(player)           E pressed (may call player.open_menu)
extends Node3D

const P = preload("res://core/palette.gd")
const Sfx = preload("res://game/sfx.gd")
const Icons = preload("res://game/icons.gd")
const Economy = preload("res://game/economy.gd")

func prompt(_player: Node) -> String:
	return ""

func interact(_player: Node) -> void:
	pass

func economy() -> Node:
	return Economy.of(self)

# An invisible box the look-ray can hit (local to this station).
func add_zone(size: Vector3, centre: Vector3) -> Area3D:
	var a := Area3D.new()
	a.name = "Zone"
	a.collision_layer = 32
	a.collision_mask = 0
	a.monitoring = false
	a.monitorable = false
	a.set_meta("station", self)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	a.add_child(cs)
	a.position = centre
	add_child(a)
	return a

# Solid furniture the player and enemies bump into (world layer).
func add_solid(size: Vector3, centre: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	b.position = centre
	add_child(b)
	return b

func add_box(size: Vector3, centre: Vector3, colour: Color, parent: Node3D = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = centre
	m.material_override = flat(colour)
	parent.add_child(m)
	return m

static func flat(colour: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	return m

# World-space label in a chunky pixel style, always facing the camera.
func add_label(text: String, centre: Vector3, colour: Color = P.WARM_CHALK, size := 48) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = centre
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.pixel_size = 0.0018
	l.outline_size = 10
	l.modulate = colour
	l.outline_modulate = P.MIDNIGHT_TYNE
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.no_depth_test = false
	add_child(l)
	return l
