# A separately purchased garage hatch. Fulfilment/payment are the car hatch's
# implementation, including mixed tickets, fresh-first tray matching and discounts.
extends "res://game/customer_window.gd"
const PhoneOrder=preload("res://game/delivery_order.gd")
const Tray=preload("res://game/serving_tray.gd")
const Bin=preload("res://game/burger_bin.gd")
const PRICE: int=200
const ORDER_SECONDS: float=120.0
signal pickup_ready(ticket: Node)
var unlocked: bool=false
var garage: Node
var bench: Node
var shutter: MeshInstance3D
var shutter_block: StaticBody3D
var status: Label3D
var ring: AudioStreamPlayer3D
var _ring_next: float=0.0
var _acknowledged: bool=false
var prep_selected: bool=false

func _ready() -> void:
	_order_rng.randomize()
	_next=8.0;gap_min=35.0;gap_max=55.0
	# Keep the hatch's interaction volume above all four tray-slot rays.
	add_zone(Vector3(1.18,.85,.30),Vector3(0,1.80,.1))
	# Counter and shutter stay physically closed until purchase; this is never a breach.
	add_solid(Vector3(1.25,1.0,.70),Vector3(0,.5,.28))
	add_box(Vector3(1.25,1.0,.70),Vector3(0,.5,.28),P.OXIDISED_TEAL)
	add_box(Vector3(1.32,.055,.76),Vector3(0,1.0,.28),P.CONCRETE_GREY)
	shutter=add_box(Vector3(1.22,1.27,.12),Vector3(0,1.625,-.05),P.BLUE_SLATE)
	shutter_block=add_solid(Vector3(1.22,1.27,.12),Vector3.ZERO)
	shutter_block.name="ShutterCollision";shutter_block.reparent(shutter,false)
	for y in 8:add_box(Vector3(1.18,.014,.018),Vector3(0,1.08+y*.15,.018),P.WET_CHARCOAL,shutter).position-=shutter.position
	for x: float in [-.65,.65]:add_box(Vector3(.06,1.40,.15),Vector3(x,1.65,-.02),P.BURNT_ORANGE)
	# Wall phone, keypad and chunky handset in the game's existing palette.
	add_box(Vector3(.28,.43,.12),Vector3(.87,1.56,-.015),P.OXIDISED_TEAL)
	add_box(Vector3(.075,.39,.09),Vector3(.79,1.58,.08),P.WET_CHARCOAL)
	for y: float in [1.42,1.74]:add_box(Vector3(.14,.085,.12),Vector3(.8,y,.10),P.WET_CHARCOAL)
	for i in 9:add_box(Vector3(.025,.02,.018),Vector3(.89+(i%3)*.038,1.61-(i/3)*.04,.06),P.WARM_CHALK)
	add_zone(Vector3(.34,.52,.35),Vector3(.87,1.57,.13))
	status=add_label("UNDEAD EATS\nOPEN HATCH $200",Vector3(0,1.72,.08),P.AMBER_GLOW,28)
	ring=AudioStreamPlayer3D.new();ring.name="PhoneRing";ring.stream=Sfx.stream("phone");ring.unit_size=5;ring.max_distance=30;ring.volume_db=-8;add_child(ring);ring.position=Vector3(.87,1.6,.12)
	var stop:=Marker3D.new();stop.name="RiderStop";stop.position=Vector3(0,0,-1.8);add_child(stop)
	_no_shadows(self)

func _no_shadows(node: Node) -> void:
	if node is GeometryInstance3D:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():_no_shadows(child)

func prompt(player: Node) -> String:
	if not garage or not garage.unlocked:return "DELIVERY HATCH  ·  unlock the garage first"
	if not unlocked:return "E  open bike delivery hatch  $200" if economy().cash>=PRICE else "DELIVERY HATCH $200  ·  need $%d more"%(PRICE-economy().cash)
	if player.held=="burger" and waiting_car():return super.prompt(player).replace("DRIVE-THRU","DELIVERY")
	return "E  track delivery ticket  ·  G switch CAR / DELIVERY prep" if waiting_car() else "DELIVERY  ·  waiting for a call  ·  G switch prep ticket"

func interact(player: Node) -> void:
	if player.is_dead() or not garage or not garage.unlocked:return
	if not unlocked:
		if not economy().spend(PRICE):return
		unlocked=true
		var opening:=create_tween();opening.tween_property(shutter,"position:y",2.95,.6).set_trans(Tween.TRANS_SINE)
		opening.finished.connect(func():shutter_block.collision_layer=0;shutter.hide())
		serving_tray=Tray.new();serving_tray.name="DeliveryTray";serving_tray.position=Vector3(0,1.04,.32);add_child(serving_tray)
		var bin:=Bin.new();bin.name="DeliveryBin";bin.position=Vector3(-.92,.2,.45);add_child(bin)
		status.text="UNDEAD EATS\nDELIVERY HATCH";status.position=Vector3(0,.60,.68)
		Sfx.play(self,"till",-8)
		return
	_acknowledged=true;ring.stop()
	if player.held=="burger" and serve(player):return
	bench.select_delivery(true)

func _physics_process(delta: float) -> void:
	if not unlocked or get_parent().player.is_dead():return
	# Shared collection logic, independent arrival clock and tray.
	super._physics_process(delta)
	if waiting_car() and not _acknowledged:
		_ring_next-=delta
		if _ring_next<=0.0:ring.play();_ring_next=8.0
	elif ring.playing:ring.stop()

func spawn_customer(quantity: int=0) -> Node3D:
	if not unlocked:return null
	if is_instance_valid(car):return car
	var c: Node3D=PhoneOrder.new();c.name="DeliveryTicket"
	var e:=economy();var wave: int=int(get_parent().wave)
	var kinds: Array[String]=[]
	if not next_orders.is_empty():kinds.assign(next_orders.slice(0,3))
	elif not next_order.is_empty():
		for i in clampi(quantity,1,3):kinds.append(next_order)
	else:kinds=Progression.generate(wave,e.served,_order_rng)
	c.configure_order(kinds);c.patience=(ORDER_SECONDS+maxf(0,Progression.patience_bonus(kinds,wave)))*patience_scale()
	next_orders.clear();next_order="";add_child(c);c.start();car=c
	var stocked: Array=[]
	for b: Dictionary in serving_tray.items:
		if not b.is_empty():BurgerItems.prepare(b);stocked.append(b.burger_id)
	c.set_meta("prepared_ids",stocked)
	c.left.connect(func(served: bool):
		_next=randf_range(gap_min,gap_max);ring.stop()
		if served:pickup_ready.emit(c)
		else:customer_missed.emit())
	_acknowledged=false;_ring_next=0.0
	customer_arrived.emit(c);collect_from_tray()
	return c
