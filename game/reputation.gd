# The shop's reputation (0-100) and serve streak: what ties the drive-thru to
# the fight. Good service raises it; missed customers and cold or burnt food
# drop it. It sets the tip multiplier and how often cars come, so ignoring the
# hatch to fight costs money twice over. A streak of completed orders without a
# miss pays a bonus every STREAK_EVERY orders. One per game, a child of main
# (group "reputation"); attach() also adds the order HUD (game/order_hud.gd).
extends Node

const P = preload("res://core/palette.gd")
const OrderHud = preload("res://game/order_hud.gd")

signal changed
signal tier_changed(name: String, up: bool)
signal streak_bonus(streak: int, cash: int)

const START := 50.0
# [floor, name, tip multiplier, car gap multiplier]: higher tiers tip more and
# send cars more often (more money, more pressure); low tiers send fewer.
const TIERS := [
	[90.0, "LEGENDARY", 1.5, 0.85],
	[70.0, "GOOD", 1.25, 0.92],
	[40.0, "DECENT", 1.0, 1.0],
	[20.0, "SHAKY", 0.75, 1.15],
	[0.0, "TERRIBLE", 0.5, 1.3],
]
const ORDER_DONE := 4.0        # a completed order
const PER_PERFECT := 1.0       # each perfect burger in it
const PER_COLD := -1.0         # each cold burger
const PER_BURNT := -2.0        # each burnt salvage burger
const MISSED := -10.0          # a car drove off unserved
const MISSED_EARLY := -5.0     # ...in waves 1-3, while the player learns the kitchen
const EARLY_WAVES := 3
# Each new wave brings a new crowd: a reputation under DECENT climbs back this
# far towards it, so one bad stretch can't lock the shop at half tips for good.
const RECOVER_TO := 40.0
const RECOVER_PER_WAVE := 6.0
const DELIVERY_MISSED := -6.0  # a phone order cancelled
const STREAK_EVERY := 3
const STREAK_CASH := 10        # x (streak / STREAK_EVERY), capped
const STREAK_CAP := 30

var value := START
var streak := 0
var best_streak := 0
var main: Node

static func of(node: Node) -> Node:
	return node.get_tree().get_first_node_in_group("reputation")

# Called once from main._ready() after the hatches exist.
static func attach(m: Node) -> Node:
	var r: Node = load("res://game/reputation.gd").new()
	r.name = "Reputation"
	r.main = m
	m.add_child(r)
	var hud: CanvasLayer = OrderHud.new()
	hud.name = "OrderHUD"
	m.add_child(hud)
	return r

func _ready() -> void:
	add_to_group("reputation")
	if main == null:
		return
	var hatch: Node = main.get("hatch")
	if hatch:
		hatch.customer_served.connect(func(_c: int, _t: int): _on_burger(String(hatch.last_quality)))
		hatch.order_completed.connect(func(_car: Node): _on_order_done())
		hatch.customer_missed.connect(func(): _on_missed(MISSED_EARLY if int(main.get("wave")) <= EARLY_WAVES else MISSED))
		hatch.customer_impatient.connect(func(_car: Node): _toast("CUSTOMER LOSING PATIENCE", P.BURNT_ORANGE))
		hatch.customer_queued.connect(func(_car: Node): _toast("RUSH HOUR  ·  ANOTHER CAR IN LINE", P.AMBER_GLOW))
	if main.has_signal("wave_started"):
		main.wave_started.connect(func(_n: int): recover())
	var delivery: Node = main.get("delivery")
	if delivery:
		delivery.customer_served.connect(func(_c: int, _t: int): _on_burger(String(delivery.last_quality)))
		delivery.order_completed.connect(func(_car: Node): _on_order_done())
		delivery.customer_missed.connect(func(): _on_missed(DELIVERY_MISSED))

func tier() -> Array:
	for t in TIERS:
		if value >= float(t[0]):
			return t
	return TIERS[-1]

func tier_name() -> String:
	return String(tier()[1])

func tip_scale() -> float:
	return float(tier()[2])

func gap_scale() -> float:
	return float(tier()[3])

func add(delta: float) -> void:
	var before := tier_name()
	var before_floor := float(tier()[0])
	value = clampf(value + delta, 0.0, 100.0)
	if tier_name() != before:
		var up := float(tier()[0]) > before_floor
		tier_changed.emit(tier_name(), up)
		_toast("REPUTATION %s  ·  TIPS x%s" % [tier_name(), str(tip_scale())], P.ELECTRIC_TEAL if up else P.BURNT_ORANGE)
	changed.emit()

func recover() -> void:
	if value < RECOVER_TO:
		add(minf(RECOVER_PER_WAVE, RECOVER_TO - value))

func _on_burger(quality: String) -> void:
	match quality:
		"perfect": add(PER_PERFECT)
		"cold": add(PER_COLD)
		"burnt": add(PER_BURNT)

func _on_order_done() -> void:
	streak += 1
	best_streak = maxi(best_streak, streak)
	add(ORDER_DONE)
	if streak % STREAK_EVERY == 0:
		var cash := mini(STREAK_CAP, STREAK_CASH * (streak / STREAK_EVERY))
		var e: Node = main.get("economy") if main else null
		if e:
			e.add_cash(cash)
		streak_bonus.emit(streak, cash)
		_toast("%d ORDERS IN A ROW  ·  STREAK BONUS +$%d" % [streak, cash], P.AMBER_GLOW)
	changed.emit()

func _on_missed(amount: float) -> void:
	streak = 0
	add(amount)

func _toast(text: String, colour: Color) -> void:
	if main and main.has_method("_toast"):
		main._toast(text, colour)
