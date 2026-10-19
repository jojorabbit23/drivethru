# A drive-through customer: a blocky car that pulls up to the service hatch,
# honks, shows its order as a pixel burger in a speech bubble with a patience
# bar, waits, and drives off - paid or not (a missed order costs nothing).
extends Node3D

const P = preload("res://core/palette.gd")
const Sfx = preload("res://game/sfx.gd")
const Icons = preload("res://game/icons.gd")
const Station = preload("res://game/station.gd")

signal arrived
signal left(served: bool)

const DRIVE_IN := 5.0
const DRIVE_OUT := 4.0
const BODY_COLOURS := [P.OXIDISED_TEAL, P.BURNT_ORANGE, P.BLUE_SLATE, P.CONCRETE_GREY]

@export var patience := 50.0
var order := "burger"
var state := "arriving"     # arriving | waiting | leaving
var waited := 0.0
var _t := 0.0
var _from := Vector3.ZERO
var _stop := Vector3.ZERO
var _to := Vector3.ZERO
var _bubble: Node3D
var _bar: MeshInstance3D
var _wheels: Array[MeshInstance3D] = []

func setup(from: Vector3, stop: Vector3, to: Vector3, colour_index := -1) -> void:
	_from = from
	_stop = stop
	_to = to
	var colour: Color = BODY_COLOURS[colour_index if colour_index >= 0 else randi() % BODY_COLOURS.size()]
	_build(colour)
	position = from
	rotation.y = -PI / 2.0      # faces +X: its right side (driver, UK) faces the hatch

func _build(colour: Color) -> void:
	# local: -Z forward, +X right
	_box(Vector3(1.7, 0.55, 3.9), Vector3(0, 0.62, 0), colour)                 # body
	_box(Vector3(1.55, 0.5, 1.9), Vector3(0, 1.14, 0.25), colour.darkened(0.15)) # cabin
	_box(Vector3(1.5, 0.42, 0.06), Vector3(0, 1.15, -0.72), P.MIDNIGHT_TYNE)     # windscreen
	_box(Vector3(1.5, 0.38, 0.06), Vector3(0, 1.15, 1.22), P.MIDNIGHT_TYNE)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.06, 0.36, 1.6), Vector3(side * 0.79, 1.16, 0.25), P.MIDNIGHT_TYNE)
	_box(Vector3(1.72, 0.12, 0.12), Vector3(0, 0.45, -1.98), P.WET_CHARCOAL)    # bumpers
	_box(Vector3(1.72, 0.12, 0.12), Vector3(0, 0.45, 1.98), P.WET_CHARCOAL)
	for lx in [-0.6, 0.6]:
		_box(Vector3(0.3, 0.12, 0.04), Vector3(lx, 0.72, -1.96), P.WARM_CHALK)    # lamps (unlit paint)
		_box(Vector3(0.3, 0.1, 0.04), Vector3(lx, 0.72, 1.96), P.BURNT_ORANGE)
	for wx in [-0.82, 0.82]:
		for wz in [-1.25, 1.25]:
			var w := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.33
			c.bottom_radius = 0.33
			c.height = 0.24
			c.radial_segments = 8
			w.mesh = c
			w.rotation.z = PI / 2.0
			w.position = Vector3(wx, 0.33, wz)
			w.material_override = Station.flat(P.WET_CHARCOAL)
			add_child(w)
			_wheels.append(w)
	var body := StaticBody3D.new()       # so bullets stop on it rather than passing through
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.7, 1.4, 3.9)
	cs.shape = bs
	cs.position = Vector3(0, 0.8, 0)
	body.add_child(cs)
	add_child(body)
	# speech bubble with the order, over the driver's side
	_bubble = Node3D.new()
	_bubble.position = Vector3(1.1, 2.15, 0.2)
	add_child(_bubble)
	var back := Icons.sprite("burger", 0.03)
	back.texture = _bubble_texture()
	back.render_priority = 0
	_bubble.add_child(back)
	var icon := Icons.sprite(order, 0.026)
	icon.position = Vector3(0, 0.04, 0.0)
	icon.render_priority = 1
	_bubble.add_child(icon)
	_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.06)
	_bar.mesh = q
	var bm := Station.flat(P.ELECTRIC_TEAL)
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_bar.material_override = bm
	_bar.position = Vector3(0, -0.36, 0)
	_bubble.add_child(_bar)
	_bubble.visible = false

static func _bubble_texture() -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 20:
		for x in 24:
			var corner := (x < 2 or x > 21) and (y < 2 or y > 17)
			if not corner:
				img.set_pixel(x, y, P.WARM_CHALK if (x > 0 and x < 23 and y > 0 and y < 19) else P.MIDNIGHT_TYNE)
	for y in range(20, 24):            # tail
		for x in range(6, 6 + (24 - y)):
			img.set_pixel(x, y, P.WARM_CHALK)
	return ImageTexture.create_from_image(img)

func _box(size: Vector3, at: Vector3, colour: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = at
	m.material_override = Station.flat(colour)
	add_child(m)

func _process(delta: float) -> void:
	_t += delta
	match state:
		"arriving":
			var k := clampf(_t / DRIVE_IN, 0.0, 1.0)
			position = _from.lerp(_stop, 1.0 - pow(1.0 - k, 2.5))
			_roll(delta, 1.0 - k)
			if k >= 1.0:
				state = "waiting"
				_t = 0.0
				_bubble.visible = true
				Sfx.play_at(self, "horn", global_position + Vector3(0, 1, 0))
				Sfx.play(self, "order", -10.0)
				arrived.emit()
		"waiting":
			waited = _t
			var left_frac := clampf(1.0 - waited / patience, 0.0, 1.0)
			_bar.scale.x = maxf(left_frac, 0.02)
			var bm := _bar.material_override as StandardMaterial3D
			bm.albedo_color = P.ELECTRIC_TEAL if left_frac > 0.66 else (P.AMBER_GLOW if left_frac > 0.33 else P.BURNT_ORANGE)
			_bubble.position.y = 2.15 + sin(_t * 3.0) * 0.03
			if waited >= patience:
				leave(false)
		"leaving":
			var k := clampf(_t / DRIVE_OUT, 0.0, 1.0)
			position = _stop.lerp(_to, k * k)
			_roll(delta, k)
			if k >= 1.0:
				queue_free()

func _roll(delta: float, speed: float) -> void:
	for w in _wheels:
		w.rotate_object_local(Vector3.UP, -delta * 12.0 * speed)

func waited_fraction() -> float:
	return clampf(waited / patience, 0.0, 1.0)

func leave(served: bool) -> void:
	if state == "leaving":
		return
	state = "leaving"
	_t = 0.0
	_bubble.visible = false
	left.emit(served)
