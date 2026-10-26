# A drive-through customer: the armoured school bus or the armoured truck
# (vehicles/, built by tools/build_vehicles.gd) pulls up to the hatch with its cab
# beside it,
# honks, shows its order as a pixel burger in a speech bubble with a patience
# bar, waits (honking again with a quarter of its patience left), and drives
# off - paid or not (a missed order costs reputation, game/reputation.gd).
extends Node3D

const Recipes = preload("res://game/recipes.gd")
const P = preload("res://core/palette.gd")
const Sfx = preload("res://game/sfx.gd")
const Icons = preload("res://game/icons.gd")
const CubeDriver = preload("res://game/cube_driver.gd")
const Station = preload("res://game/station.gd")

signal arrived
signal left(served: bool)
signal impatient                 # a quarter of its patience left: honks and the bubble shakes

const IMPATIENT_AT := 0.25       # fraction of patience left

const DRIVE_IN := 5.0
const DRIVE_OUT := 4.0
const BODY_COLOURS := [P.OXIDISED_TEAL, P.BURNT_ORANGE, P.BLUE_SLATE, P.CONCRETE_GREY]
# Customer vehicles (tools/build_vehicles.gd). cab: the driver's window,
# metres ahead of the vehicle's middle; side: half-width to the hatch side.
const VEHICLES := {
	"rugged_truck": {"scene": preload("res://vehicles/rugged_truck/rugged_model.tscn"), "cab": -0.20, "side": 1.35},
	"school_bus": {"scene": preload("res://vehicles/school_bus/bus_model.tscn"), "cab": 1.6, "side": 1.9},
	"armored_truck": {"scene": preload("res://vehicles/armored_truck/truck_model.tscn"), "cab": 1.9, "side": 1.65},
}
var vehicle := ""                 # key of VEHICLES; random if left empty
var CAB_FROM_CENTRE := 1.6

@export var patience := 50.0
var order := "brown"        # which burger: brown (common) | blue | red
var quantity: int=1
var received: int=0
# Empty retains the original single-recipe quantity API used by saved scenarios.
var order_lines: Array[Dictionary]=[]
var _mixed_rows: Array[Dictionary]=[]
var _mixed_back: Sprite3D
var _quantity_label: Label3D
var state := "arriving"     # arriving | queued | waiting | leaving
var waited := 0.0
# Rush hour (game/customer_window.gd): a second car pulls up behind the one at
# the hatch and waits in line ("queued") until it is moved up with advance_to().
var hold_in_queue := false
var queue_waited := 0.0
var _warned := false
var _t := 0.0
var _from := Vector3.ZERO
var _stop := Vector3.ZERO
var _to := Vector3.ZERO
var _bubble: Node3D
var _bar: MeshInstance3D
var _wheels: Array[MeshInstance3D] = []

func setup(from: Vector3, stop: Vector3, to: Vector3, colour_index := -1) -> void:
	# it travels +X, so stop with the cab (not the middle) at the hatch
	_from = from
	if vehicle == "":
		vehicle = VEHICLES.keys()[randi() % VEHICLES.size()]
	CAB_FROM_CENTRE = VEHICLES[vehicle]["cab"]
	_stop = stop - Vector3(CAB_FROM_CENTRE, 0, 0)
	_to = to
	_build_bus()
	position = from
	rotation.y = -PI / 2.0      # faces +X: its right side (driver, UK) faces the hatch

var _body: Node3D

var _bus_wheels: Array[Node3D] = []
var _wheel_r := 0.7
var _last_pos := Vector3.ZERO

func _build_bus() -> void:
	_body = (VEHICLES[vehicle]["scene"] as PackedScene).instantiate()
	add_child(_body)
	_wheel_r = _body.get_meta("wheel_radius", 0.7)
	for w in _body.get_children():
		if w.name.begins_with("Wheel"):
			_bus_wheels.append(w)
	if vehicle=="rugged_truck":
		var driver: Node3D=CubeDriver.new()
		driver.name="CubeDriver"
		_body.add_child(driver)
		driver.position=Vector3(0.68,1.40,0.20)
	_add_bubble(Vector3(VEHICLES[vehicle]["side"], 1.60, -CAB_FROM_CENTRE))   # by the cab, on the hatch side (+X faces the shop)

# Old placeholder car (kept for reference; unused).
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
	_add_bubble(Vector3(1.1, 2.15, 0.2))

var _bubble_y := 2.15
var _bubble_x := 0.0

func _add_bubble(at: Vector3) -> void:
	if not order_lines.is_empty():
		_add_mixed_bubble(at)
		return
	_bubble = Node3D.new()
	_bubble.position = at
	_bubble_y = at.y
	_bubble_x = at.x
	add_child(_bubble)
	var back := Icons.sprite("burger", 0.03)
	back.texture = _bubble_texture(order)
	back.pixel_size = 0.035
	back.render_priority = 0
	_bubble.add_child(back)
	var icon := Icons.sprite("burger_" + order, 0.035)
	icon.position = Vector3(0, -0.04, 0.01)
	icon.render_priority = 1
	_bubble.add_child(icon)
	var title:=Label3D.new()
	title.name="BurgerColour"
	title.text=Recipes.ticket_text(order,quantity)
	_quantity_label=title
	title.position=Vector3(0,0.32,0.02)
	title.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	title.font_size=34
	title.pixel_size=0.004
	title.modulate=Recipes.colour(order)
	title.render_priority=2
	title.outline_size=3
	title.outline_modulate=P.MIDNIGHT_TYNE
	_bubble.add_child(title)
	var caption:=Label3D.new()
	caption.name="MushroomName"
	caption.text="BLUE + YELLOW" if order=="special" else String(Station.Economy.KIND_NAME[Recipes.patties(order)[0]]).to_upper()
	caption.position=Vector3(0,-0.265,0.025)
	caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	caption.font_size=18;caption.pixel_size=.0036
	caption.modulate=P.MIDNIGHT_TYNE;caption.outline_size=0;caption.render_priority=2
	_bubble.add_child(caption)
	_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.06)
	_bar.mesh = q
	var bm := Station.flat(P.ELECTRIC_TEAL)
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.render_priority = 3
	_bar.material_override = bm
	_bar.position = Vector3(0, -0.59, 0.03)
	_bubble.add_child(_bar)
	_bubble.visible = false

func refresh_order_quantity() -> void:
	if not order_lines.is_empty():
		var pending: Array[Dictionary]=remaining_lines()
		var active: int=0
		for i in _mixed_rows.size():
			var left_count: int=order_lines[i].quantity-order_lines[i].received
			_mixed_rows[i].root.visible=left_count>0
			_mixed_rows[i].label.text=Recipes.ticket_text(order_lines[i].kind,left_count)
			if left_count>0:
				_mixed_rows[i].root.position.y=(pending.size()-1)*.18-active*.36+.07
				active+=1
		if _mixed_back and not pending.is_empty():
			var height: int=18 if pending.size()==1 else 26 if pending.size()==2 else 34
			_mixed_back.texture=_mixed_background(pending,height)
			_bar.position.y=-height*.035*.5-.12
		return
	if _quantity_label:_quantity_label.text=Recipes.ticket_text(order,maxi(0,quantity-received))

static func _bubble_texture(kind: String="brown") -> Texture2D:
	var img := Image.create(32, 30, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var colour: Color=Recipes.colour(kind)
	for y in 26:
		for x in 32:
			var corner := (x < 2 or x > 29) and (y < 2 or y > 23)
			if not corner:
				var border_colour: Color=colour
				if kind=="special":border_colour=P.ELECTRIC_TEAL if x<16 else P.AMBER_GLOW
				img.set_pixel(x,y,P.MIDNIGHT_TYNE if x==0 or x==31 or y==0 or y==25 else (border_colour if x<3 or x>28 or y<3 or y>22 or y>22 else P.WARM_CHALK))
	for y in range(26, 30):            # tail
		for x in range(8, 8 + (30 - y)):
			img.set_pixel(x, y, colour)
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
	# Lay out the entire card in screen-facing space, including icon/count offsets.
	var viewer: Camera3D=get_viewport().get_camera_3d()
	if _bubble and viewer:_bubble.global_basis=viewer.global_basis
	_t += delta
	_spin_wheels()
	match state:
		"arriving":
			var k := clampf(_t / DRIVE_IN, 0.0, 1.0)
			position = _from.lerp(_stop, 1.0 - pow(1.0 - k, 2.5))
			_roll(delta, 1.0 - k)
			if k >= 1.0 and hold_in_queue:
				state = "queued"
				_t = 0.0
				Sfx.play_at(self, "horn", global_position + Vector3(0, 1, 0), -8.0)
			elif k >= 1.0:
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
			_bubble.position.y = _bubble_y + sin(_t * 3.0) * 0.03
			_body.position.y = absf(sin(_t * 23.0)) * 0.012     # engine idling
			if left_frac <= IMPATIENT_AT and not _warned:
				_warned = true
				Sfx.play_at(self, "horn", global_position + Vector3(0, 1, 0))
				impatient.emit()
			if _warned:   # shake the bubble and blink the bar: last call
				_bubble.position.x = _bubble_x + sin(_t * 31.0) * 0.025
				_bar.visible = fmod(_t, 0.5) < 0.35
			if waited >= patience:
				leave(false)
		"queued":
			queue_waited += delta
			_body.position.y = absf(sin(_t * 23.0)) * 0.012
		"leaving":
			var k := clampf(_t / DRIVE_OUT, 0.0, 1.0)
			position = _stop.lerp(_to, k * k)
			_roll(delta, k)
			if k >= 1.0:
				queue_free()

# Wheels roll exactly as far as the bus moved: angle = distance / radius.
# The bus drives forward (local -Z), so the tops of the wheels turn forward:
# a negative turn about local X.
func _spin_wheels() -> void:
	var moved := (position - _last_pos).length()
	if _last_pos == Vector3.ZERO:
		moved = 0.0
	_last_pos = position
	if moved <= 0.0 or moved > 5.0:
		return
	for w in _bus_wheels:
		w.rotation.x = wrapf(w.rotation.x - moved / _wheel_r, -PI, PI)

func wheel_angle() -> float:
	return _bus_wheels[0].rotation.x if not _bus_wheels.is_empty() else 0.0

func _roll(delta: float, speed: float) -> void:
	if _body:
		_body.position.y = absf(sin(_t * 9.0)) * 0.03 * speed
		_body.rotation.z = sin(_t * 4.0) * 0.012 * speed
	for w in _wheels:
		w.rotate_object_local(Vector3.UP, -delta * 12.0 * speed)

# Move up from the queue spot to the hatch (`stop`: where the cab should be).
func advance_to(stop: Vector3) -> void:
	hold_in_queue = false
	_from = position
	_stop = stop - Vector3(CAB_FROM_CENTRE, 0, 0)
	state = "arriving"
	_t = 0.0

func waited_fraction() -> float:
	return clampf(waited / patience, 0.0, 1.0)

func leave(served: bool) -> void:
	if state == "leaving":
		return
	# from the queue spot it never reached the hatch: drive out from where it is
	if state == "queued" or state == "arriving":
		_stop = position
	state = "leaving"
	_t = 0.0
	_bubble.visible = false
	left.emit(served)

func configure_order(kinds: Array[String]) -> void:
	order_lines.clear();received=0;quantity=kinds.size();order=kinds[0]
	var unique: Dictionary={}
	for kind: String in kinds:unique[kind]=int(unique.get(kind,0))+1
	if unique.size()<=1:return
	for kind: String in unique:order_lines.append({"kind":kind,"quantity":unique[kind],"received":0})
func remaining_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary]=[]
	if order_lines.is_empty():
		if received<quantity:lines.append({"kind":order,"quantity":quantity-received})
	else:
		for line: Dictionary in order_lines:
			var count: int=line.quantity-line.received
			if count>0:lines.append({"kind":line.kind,"quantity":count})
	return lines
func wants(kind: String) -> bool:
	for line: Dictionary in remaining_lines():
		if line.kind==kind:return true
	return false
func ticket_text(separator: String="\n") -> String:
	var parts:=PackedStringArray()
	for line: Dictionary in remaining_lines():parts.append(Recipes.ticket_text(line.kind,line.quantity))
	return separator.join(parts)
func record_delivery(kind: String,substitute: bool=false) -> bool:
	var index: int=-1
	if order_lines.is_empty():
		if received>=quantity or (kind!=order and not substitute):return false
	else:
		for i in order_lines.size():
			var line: Dictionary=order_lines[i]
			if line.received<line.quantity and line.kind==kind:index=i;break
		if index<0 and substitute:
			for i in order_lines.size():
				if order_lines[i].received<order_lines[i].quantity:index=i;break
		if index<0:return false
		order_lines[index].received+=1
	received+=1
	var left: Array[Dictionary]=remaining_lines()
	if not left.is_empty():order=left[0].kind
	refresh_order_quantity()
	return true
func _add_mixed_bubble(at: Vector3) -> void:
	_bubble=Node3D.new();_bubble.position=at;_bubble_y=at.y;_bubble_x=at.x;add_child(_bubble)
	var rows: int=order_lines.size()
	var height: int=26 if rows==2 else 34
	_mixed_back=Icons.sprite("burger",.035);_mixed_back.texture=_mixed_background(order_lines,height);_bubble.add_child(_mixed_back)
	for i in rows:
		var line: Dictionary=order_lines[i]
		var row:=Node3D.new();row.position.y=(rows-1)*.18-i*.36+.07;_bubble.add_child(row)
		var icon:=Icons.sprite("burger_"+String(line.kind),.017);icon.position=Vector3(-.34,.02,.015);icon.render_priority=1;row.add_child(icon)
		var label:=Label3D.new();label.text=Recipes.ticket_text(line.kind,line.quantity);label.position=Vector3(.08,.07,.025);label.font_size=18;label.pixel_size=.0055;label.modulate=Recipes.colour(line.kind);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.outline_size=3;label.outline_modulate=P.MIDNIGHT_TYNE;label.render_priority=2;row.add_child(label)
		var caption:=Label3D.new();caption.text=Recipes.name_of(line.kind).to_upper();caption.position=Vector3(.08,-.065,.025);caption.font_size=18;caption.pixel_size=.0032;caption.modulate=P.MIDNIGHT_TYNE;caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED;caption.outline_size=0;caption.render_priority=2;row.add_child(caption)
		_mixed_rows.append({"root":row,"label":label})
	_bar=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.8,.06);_bar.mesh=quad
	var mat:=Station.flat(P.ELECTRIC_TEAL);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;mat.render_priority=3;_bar.material_override=mat;_bar.position=Vector3(0,-height*.035*.5-.12,.03);_bubble.add_child(_bar)
	_bubble.visible=false

# Regenerated only on a delivered item, never in the frame update.
func _mixed_background(lines: Array[Dictionary],height: int) -> Texture2D:
	var image:=Image.create(32,height+4,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
	for y in height:
		var row_index: int=mini(lines.size()-1,y*lines.size()/height)
		for x in 32:
			var rim: bool=x<3 or x>28 or y<3 or y>height-4
			image.set_pixel(x,y,(P.MIDNIGHT_TYNE if x==0 or x==31 or y==0 or y==height-1 else Recipes.colour(lines[row_index].kind)) if rim else P.WARM_CHALK)
	for y in range(height,height+4):
		for x in range(8,8+height+4-y):image.set_pixel(x,y,Recipes.colour(lines[0].kind))
	return ImageTexture.create_from_image(image)
