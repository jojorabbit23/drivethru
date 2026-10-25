# The service hatch. Customers drive up one at a time and show the burger they
# want as an icon (brown common, blue or red). Hold the right bagged burger,
# look at the hatch, press E: $30 plus a tip for a fresh patty (perfect $6,
# good $3), or $15 for burnt salvage. A missed customer just drives away - no
# penalty, no payment. With the drive-thru bell (shop upgrade) customers wait
# 50% longer, and a brass bell sits on the sill.
extends "res://game/station.gd"

const Car = preload("res://game/customer_car.gd")
const Recipes = preload("res://game/recipes.gd")
const Progression=preload("res://game/order_progression.gd")
var next_orders: Array[String]=[]
var _order_rng:=RandomNumberGenerator.new()
const BurgerItems = preload("res://game/burger_items.gd")
var serving_tray: Node = null
var _tray_check: float = 0.0

signal customer_arrived(car: Node)
signal customer_served(cash: int, tip: int)
signal customer_missed

@export var auto := true             # spawn customers (tests switch this off)
@export var first_delay := 15.0
@export var gap_min := 18.0          # seconds between one car leaving and the next arriving
@export var gap_max := 32.0

var lane_start := Vector3(-38, 0, -8)
var lane_stop := Vector3(-3, 0, -8)
var lane_end := Vector3(38, 0, -8)
var car: Node3D = null
var next_order := ""                 # tests/films can force the next order
var next_vehicle := ""               # ...and vehicle ("school_bus" / "armored_truck")
var last_quality := ""
const ORDER_WEIGHTS := {"brown": 0.55, "blue": 0.3, "red": 0.15}

static func pick_order() -> String:
	var r := randf()
	for k in ORDER_WEIGHTS:
		r -= float(ORDER_WEIGHTS[k])
		if r <= 0.0:
			return k
	return "brown"

var _next := 0.0

var _bell: Node3D

func _ready() -> void:
	_order_rng.randomize()
	add_zone(Vector3(1.8, 1.0, 0.9), Vector3(0, 0.5, 0))
	_next = first_delay
	_bell = Node3D.new()
	_bell.name = "Bell"
	_bell.position = Vector3(0.62, 0.0, 0.12)
	add_child(_bell)
	add_box(Vector3(0.1, 0.012, 0.1), Vector3(0, 0.006, 0), P.WET_CHARCOAL, _bell)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.05
	sm.is_hemisphere = true
	sm.radial_segments = 8
	sm.rings = 3
	dome.mesh = sm
	var bm := flat(P.AMBER_GLOW.darkened(0.2), 0.3)
	bm.metallic = 0.8
	dome.material_override = bm
	dome.position = Vector3(0, 0.012, 0)
	_bell.add_child(dome)
	add_box(Vector3(0.012, 0.02, 0.012), Vector3(0, 0.07, 0), P.WET_CHARCOAL, _bell)
	_show_bell.call_deferred()

func _show_bell() -> void:
	var e := economy()
	if e and not e.changed.is_connected(_show_bell):
		e.changed.connect(_show_bell)
	_bell.visible = e != null and e.has_bell

func patience_scale() -> float:
	var e := economy()
	return Economy.BELL_PATIENCE if e and e.has_bell else 1.0

func set_lane(start: Vector3, stop: Vector3, end: Vector3) -> void:
	lane_start = start
	lane_stop = stop
	lane_end = end

func _physics_process(delta: float) -> void:
	_tray_check-=delta
	if _tray_check<=0.0:
		_tray_check=0.2
		collect_from_tray()
	if car != null and not is_instance_valid(car):
		car = null
	if not auto or car != null:
		return
	_next -= delta
	if _next <= 0.0:
		spawn_customer(0) # automatic wave-scaled demand; explicit quantities remain deterministic

func spawn_customer(quantity: int=1) -> Node3D:
	if car != null and is_instance_valid(car):
		return car
	var c := Node3D.new()
	c.set_script(Car)
	c.name = "CustomerCar"
	get_parent().add_child(c)
	var e := economy()
	var wave: int=int(get_parent().get("wave"))
	var automatic: bool=quantity<=0 and next_order.is_empty() and next_orders.is_empty()
	var kinds: Array[String]=[]
	if not next_orders.is_empty():kinds.assign(next_orders.slice(0,3))
	elif automatic:kinds=Progression.generate(wave,e.served if e else 0,_order_rng)
	else:
		var kind: String=next_order if next_order!="" else Recipes.pick(e.served if e else 0)
		for i in clampi(quantity,1,3):kinds.append(kind)
	c.configure_order(kinds)
	# extra patties buy extra time from the first wave (it used to start at wave 3,
	# so an early two-burger order got no more time than a single)
	if automatic:c.patience+=Progression.patience_bonus(kinds,wave)
	c.patience *= patience_scale()
	next_orders.clear()
	c.vehicle = next_vehicle
	next_order = ""
	next_vehicle = ""
	c.setup(lane_start, lane_stop, lane_end)
	c.arrived.connect(func():
		var stocked: Array=[]
		if serving_tray!=null:
			for b: Dictionary in serving_tray.items:
				if not b.is_empty():BurgerItems.prepare(b);stocked.append(b.burger_id)
		c.set_meta("prepared_ids",stocked)
		customer_arrived.emit(c)
		collect_from_tray())
	c.left.connect(func(served: bool):
		var spacing: Vector2=Progression.gap(int(get_parent().get("wave")),gap_min,gap_max)
		_next = randf_range(spacing.x,spacing.y)
		if not served:
			customer_missed.emit())
	car = c
	return c

func waiting_car() -> Node3D:
	if car != null and is_instance_valid(car) and car.state == "waiting":
		return car
	return null

func prompt(player: Node) -> String:
	var c := waiting_car()
	if c == null:
		if car != null and is_instance_valid(car) and car.state == "arriving":
			return "DRIVE-THRU  ·  customer pulling in"
		return "DRIVE-THRU  ·  no customer yet"
	var left := ceili(c.patience - c.waited)
	var want: String = c.ticket_text(" + ") if not c.order_lines.is_empty() else Recipes.name_of(c.order).to_upper()
	if c.order_lines.is_empty() and c.quantity-c.received>1:want+=" x%d" % (c.quantity-c.received)
	if player.held == "burger":
		var b: Dictionary = player.held_burger
		if BurgerItems.spoiled(b):return "SPOILED BURGER  ·  use the kitchen bin"
		if b.get("quality", "") == "burnt":
			return "E  serve burnt salvage  ·  $%d%s" % [int(BurgerItems.payment(b)[0]),"  COLD (-50%)" if BurgerItems.cold(b) else ""]
		if not c.wants(b.get("kind", "")):
			return "WRONG BURGER  ·  they want %s" % want
		var pay := BurgerItems.payment(b)
		return "E  serve %s burger  ·  %s  $%d%s" % [Recipes.name_of(String(b.get("kind","brown"))).to_upper(), (BurgerItems.state(b)+" (-75%)" if BurgerItems.age(b)>=300.0 else "COLD (-50%)") if BurgerItems.cold(b) else (b["quality"] as String).to_upper(), pay[0], (" + $%d tip" % pay[1]) if pay[1] > 0 else ""]
	return "DRIVE-THRU  ·  wants %s  ·  %ds" % [want, left]

func interact(player: Node) -> void:
	serve(player)

# Pays by the burger's quality (docs/COOKING_DESIGN.md): the right kind earns
# $30 plus a perfect/good tip; burnt salvage earns $15 from anyone.
func serve(player: Node) -> bool:
	var c := waiting_car()
	if c == null or player.held != "burger":
		return false
	var b: Dictionary = player.held_burger
	if BurgerItems.spoiled(b):return false
	var quality: String = b.get("quality", "standard")
	if quality != "burnt" and not c.wants(b.get("kind", "brown")):
		Sfx.play(self, "click", -6.0)
		return false
	player.take_selected_burger()
	_pay(c,b)
	return true

func collect_from_tray() -> int:
	var c: Node3D=waiting_car()
	if c==null or serving_tray==null:return 0
	var taken: int=0
	while c.state=="waiting" and c.received<c.quantity:
		var item: Dictionary={}
		# Look for every requested recipe before allowing discount substitution.
		for line: Dictionary in c.remaining_lines():
			item=serving_tray.take_matching(line.kind,false)
			if not item.is_empty():break
		if item.is_empty():item=serving_tray.take_matching(c.order)
		if item.is_empty():break
		_pay(c,item,true)
		taken+=1
	return taken

func _pay(c: Node3D,b: Dictionary,from_tray: bool=false) -> void:
	if not c.record_delivery(String(b.get("kind","brown")),String(b.get("quality",""))=="burnt" or (from_tray and b.get("discount",false))):return
	var pay: Array=BurgerItems.payment(b)
	BurgerItems.prepare(b)
	if from_tray and not BurgerItems.cold(b) and c.waited<=3.0 and b.burger_id in c.get_meta("prepared_ids",[]):
		pay[1]=roundi(float(pay[1])*1.25)
	var e := economy()
	e.add_cash(int(pay[0]) + int(pay[1]))
	if c.received>=c.quantity:
		e.served += 1
		c.leave(true)
	Sfx.play(self, "till", -6.0)
	last_quality = "cold" if BurgerItems.cold(b) else String(b.get("quality","standard"))
	customer_served.emit(int(pay[0]), int(pay[1]))
