# The shop's books: cash, mushroom stock by kind, buns and toppings, and the
# prices from docs/GAME_DESIGN.md and docs/COOKING_DESIGN.md. One per game, a
# child of main (group "economy").
extends Node

const Recipes = preload("res://game/recipes.gd")

signal changed

# Mushroom kinds. Each makes its own patty and its own burger order.
# Legacy "red" IDs are retained for saved stock/orders; the player-facing name is Yellow.
const KINDS := ["brown", "blue", "red"]
const KIND_NAME := {"brown": "Regular", "blue": "Blue", "red": "Yellow"}

const KILL_CASH := 2           # every kill
const BURGER_PRICE := 30       # every correct burger
# Quality depends on how long the patty sat READY before the burger was served
# (docs/COOKING_DESIGN.md "Burger Quality System").
# The ready window is 12 s (20 s on the Apocalypse Grill), so:
const PERFECT_WITHIN := 4.0    # s ready: $30 + $6 tip
const GOOD_WITHIN := 8.0       # s ready: $30 + $3 tip; later, until it burns: $30 standard
const TIP := {"perfect": 6, "good": 3, "standard": 0}
const SALVAGE_PRICE := 15      # a burnt patty, bagged anyway: some survivors take it
const AMMO_PACK := 24          # pistol rounds per purchase
const AMMO_PRICE := 12
const SUPPLY_PACK := 5         # buns + toppings per order: $8 a burger, as designed
const SUPPLY_PRICE := 40
const BULK_PACK := 15          # the big box: a little cheaper per burger
const BULK_PRICE := 110
const SHOTGUN_PRICE := 150     # weapon 4
const DESERT_EAGLE_PRICE := 180
const EAGLE_AMMO_PRICE := 20
const EAGLE_AMMO_PACK := 14
const SAWN_OFF_PRICE := 90
const SMG_PRICE := 220          # full-auto AKS-74U, 30-round mag
const SMG_AMMO_PRICE := 18
const SMG_AMMO_PACK := 30
const SHELL_PACK := 12         # docs/GAME_DESIGN.md: 12 shells = $30
const SHELL_PRICE := 30
# Kitchen upgrades (docs/COOKING_DESIGN.md "Kitchen Upgrades")
const TRAY_PRICE := 120        # Heated Holding Tray: keeps 2 cooked patties at their quality
const TRAY_SLOTS := 2
const BELL_PRICE := 100        # Drive-Through Bell System: customers wait 50% longer
const BELL_PATIENCE := 1.5
# Grill upgrades, in order: [name, slots, price, ready window s, burn delay x]
const GRILLS := [
	["Starter Grill", 2, 0, 12.0],
	["Reinforced Grill", 3, 90, 12.0],
	["Restaurant Grill", 4, 180, 12.0],
	["Apocalypse Grill", 4, 300, 20.0],
]

var cash := 0
var stock := {"brown": 0, "blue": 0, "red": 0}   # stored mushrooms; one makes one patty
var buns := 8
var toppings := 8
var grill_level := 0
const SERVING_HEATER_PRICE := 180
var has_serving_heater := false
var has_tray := false
var has_bell := false
var earned := 0
var served := 0

# total stored, all kinds
var mushrooms: int:
	get:
		return stock["brown"] + stock["blue"] + stock["red"]

static func of(node: Node) -> Node:
	return node.get_tree().get_first_node_in_group("economy")

func _ready() -> void:
	add_to_group("economy")

func add_cash(n: int) -> void:
	cash += n
	if n > 0:
		earned += n
	changed.emit()

func spend(n: int) -> bool:
	if cash < n:
		return false
	cash -= n
	changed.emit()
	return true

func store_mushrooms(n: int, kind := "brown") -> void:
	stock[kind] = int(stock[kind]) + n
	changed.emit()

func store_all(carried: Dictionary) -> int:
	var n := 0
	for k in KINDS:
		n += int(carried.get(k, 0))
		stock[k] = int(stock[k]) + int(carried.get(k, 0))
	changed.emit()
	return n

func take_mushroom(kind := "brown") -> bool:
	if int(stock[kind]) <= 0:
		return false
	stock[kind] = int(stock[kind]) - 1
	changed.emit()
	return true

func can_bag() -> bool:
	return buns > 0 and toppings > 0

func take_bun_and_topping() -> bool:
	if not can_bag():
		return false
	buns -= 1
	toppings -= 1
	changed.emit()
	return true

func add_supplies(n: int) -> void:
	buns += n
	toppings += n
	changed.emit()

# kept for older callers: buns only
func take_bun() -> bool:
	return take_bun_and_topping()

func add_buns(n: int) -> void:
	add_supplies(n)

func grill() -> Array:
	return GRILLS[grill_level]

func next_grill() -> Array:
	return GRILLS[grill_level + 1] if grill_level + 1 < GRILLS.size() else []

func upgrade_grill() -> bool:
	var next := next_grill()
	if next.is_empty() or not spend(int(next[2])):
		return false
	grill_level += 1
	changed.emit()
	return true

func buy_tray() -> bool:
	if has_tray or not spend(TRAY_PRICE):
		return false
	has_tray = true
	changed.emit()
	return true

func buy_bell() -> bool:
	if has_bell or not spend(BELL_PRICE):
		return false
	has_bell = true
	changed.emit()
	return true

# Quality of a bagged patty: how long it sat READY (s), or burnt.
static func quality_for(ready_for: float, burnt: bool) -> String:
	if burnt:
		return "burnt"
	if ready_for <= PERFECT_WITHIN:
		return "perfect"
	if ready_for <= GOOD_WITHIN:
		return "good"
	return "standard"

# Payment for a burger of `quality` (and recipe, game/recipes.gd): [price, tip]
static func payment(quality: String, order := "brown") -> Array:
	if quality == "burnt":
		return [SALVAGE_PRICE, 0]
	return [Recipes.price(order), int(TIP.get(quality, 0))]
