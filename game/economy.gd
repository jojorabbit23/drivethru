# The shop's books: cash and storage. One per game, a child of main
# (group "economy"). Values follow docs/GAME_DESIGN.md "prototype values".
extends Node

signal changed

const KILL_CASH := 2           # every kill
const BURGER_PRICE := 30       # basic mushroom burger
const TIP_QUICK := 6           # served in the first third of the customer's patience
const TIP_NORMAL := 2          # served in the second third
const AMMO_PACK := 24          # pistol rounds per purchase
const AMMO_PRICE := 12
const BUN_PACK := 10           # buns per supply order (each burger uses one)
const BUN_PRICE := 40

var cash := 0
var mushrooms := 0             # stored mushroom units; one makes one common patty
var buns := 12
var earned := 0                # lifetime cash, for the HUD/tests
var served := 0

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

func store_mushrooms(n: int) -> void:
	mushrooms += n
	changed.emit()

func take_mushroom() -> bool:
	if mushrooms <= 0:
		return false
	mushrooms -= 1
	changed.emit()
	return true

func take_bun() -> bool:
	if buns <= 0:
		return false
	buns -= 1
	changed.emit()
	return true

func add_buns(n: int) -> void:
	buns += n
	changed.emit()

# Payment for a correct burger: price plus a tip for speed.
# waited_frac: 0 = just arrived, 1 = about to leave.
static func tip_for(waited_frac: float) -> int:
	if waited_frac < 1.0 / 3.0:
		return TIP_QUICK
	if waited_frac < 2.0 / 3.0:
		return TIP_NORMAL
	return 0
