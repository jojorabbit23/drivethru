# The service hatch. Customers drive up the road one at a time; hold a bagged
# burger, look at the hatch and press E to serve: $30 plus a tip for speed
# ($6 in the first third of their patience, $2 in the second, nothing after).
# A missed customer just drives away - no penalty, no payment.
extends "res://game/station.gd"

const Car = preload("res://game/customer_car.gd")

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
var _next := 0.0

func _ready() -> void:
	add_zone(Vector3(1.8, 1.0, 0.9), Vector3(0, 0.5, 0))
	_next = first_delay

func set_lane(start: Vector3, stop: Vector3, end: Vector3) -> void:
	lane_start = start
	lane_stop = stop
	lane_end = end

func _physics_process(delta: float) -> void:
	if car != null and not is_instance_valid(car):
		car = null
	if not auto or car != null:
		return
	_next -= delta
	if _next <= 0.0:
		spawn_customer()

func spawn_customer() -> Node3D:
	if car != null and is_instance_valid(car):
		return car
	var c := Node3D.new()
	c.set_script(Car)
	c.name = "CustomerCar"
	get_parent().add_child(c)
	c.setup(lane_start, lane_stop, lane_end)
	c.arrived.connect(func(): customer_arrived.emit(c))
	c.left.connect(func(served: bool):
		_next = randf_range(gap_min, gap_max)
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
			return "DRIVE-THRU  ·  car pulling in"
		return "DRIVE-THRU  ·  no customer yet"
	var left := ceili(c.patience - c.waited)
	if player.held == "burger":
		return "E  serve burger  ·  $%d + tip" % Economy.BURGER_PRICE
	return "DRIVE-THRU  ·  wants a burger  ·  %ds" % left

func interact(player: Node) -> void:
	serve(player)

func serve(player: Node) -> bool:
	var c := waiting_car()
	if c == null or player.held != "burger":
		return false
	var tip := Economy.tip_for(c.waited_fraction())
	player.set_held("")
	var e := economy()
	e.add_cash(Economy.BURGER_PRICE + tip)
	e.served += 1
	c.leave(true)
	Sfx.play(self, "till", -6.0)
	customer_served.emit(Economy.BURGER_PRICE, tip)
	return true
