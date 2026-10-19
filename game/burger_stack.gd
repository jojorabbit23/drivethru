# The prep bench's little show when you bag a burger (about 0.8 s, visual
# only: the burger is in your hands the moment you press E). The bottom bun,
# the patty (a pressed mushroom in its kind's colour, or charred), the topping
# and the top bun drop onto the board one after another, a paper wrap folds up
# round them, and the bag lifts away toward you.
#   var s := BurgerStack.new(); bench.add_child(s); s.play(kind, burnt)
extends Node3D

const P = preload("res://core/palette.gd")
const Icons = preload("res://game/icons.gd")
const MUSHROOM := preload("res://pickups/mushroom/mushroom_pickup_mesh.res")
const ALBEDO := preload("res://pickups/mushroom/mushroom_albedo.png")
const PATTY_SHADER := preload("res://game/patty.gdshader")

const STEP := 0.11       # seconds between layers

func play(kind: String, burnt := false) -> void:
	var layers := [
		_bun(false),
		_patty(kind, burnt),
		_topping(),
		_bun(true),
	]
	var heights := [0.0, 0.03, 0.058, 0.07]
	var tw := create_tween()
	for i in layers.size():
		var n: Node3D = layers[i]
		n.position = Vector3(0, heights[i] + 0.16, 0)
		n.visible = false
		add_child(n)
		tw.tween_callback(func() -> void: n.visible = true)
		tw.tween_property(n, "position:y", heights[i], STEP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# the wrap folds up round the stack
	var wrap := _box(Vector3(0.15, 0.085, 0.15), Vector3(0, 0.045, 0), P.WARM_CHALK)   # a paper clamshell
	wrap.scale = Vector3(1, 0.01, 1)
	wrap.visible = false
	tw.tween_callback(func() -> void: wrap.visible = true)
	tw.tween_property(wrap, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		for n: Node3D in layers:
			n.visible = false)
	# and the bag lifts off toward the cook
	tw.tween_property(self, "position", position + Vector3(0, 0.3, 0.35), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", Vector3.ONE * 0.4, 0.22)
	tw.tween_callback(queue_free)

func _box(size: Vector3, pos: Vector3, colour: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m

func _mat(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	return mat

func _bun(top: bool) -> Node3D:
	var m := MeshInstance3D.new()
	if top:
		var s := SphereMesh.new()       # a dome
		s.radius = 0.065
		s.height = 0.07
		s.radial_segments = 8
		s.rings = 3
		s.is_hemisphere = true
		m.mesh = s
		m.scale = Vector3(1, 0.75, 1)
	else:
		var c := CylinderMesh.new()
		c.top_radius = 0.063
		c.bottom_radius = 0.06
		c.height = 0.026
		c.radial_segments = 8
		c.rings = 1
		m.mesh = c
	m.material_override = _mat(P.AMBER_GLOW.darkened(0.15))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _patty(kind: String, burnt: bool) -> Node3D:
	var m := MeshInstance3D.new()
	m.mesh = MUSHROOM
	m.scale = Vector3(0.36, 0.16, 0.36)
	var mat := ShaderMaterial.new()
	mat.shader = PATTY_SHADER
	mat.set_shader_parameter("detail", ALBEDO)
	mat.set_shader_parameter("cap_colour", Icons.KIND_COLOUR.get(kind, Icons.KIND_COLOUR["brown"]))
	mat.set_shader_parameter("cook", 0.85)
	mat.set_shader_parameter("burnt", 1.0 if burnt else 0.0)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _topping() -> Node3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()       # a frilly leaf: an 8-sided, slightly wider disc
	c.top_radius = 0.07
	c.bottom_radius = 0.072
	c.height = 0.008
	c.radial_segments = 8
	c.rings = 1
	m.mesh = c
	m.rotation.y = PI / 8.0
	m.material_override = _mat(P.OXIDISED_TEAL)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m
