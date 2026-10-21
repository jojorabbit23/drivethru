# The burgers customers order (docs/COOKING_DESIGN.md "Later Recipes").
# An order is one of these keys; the bagged burger carries the same key, so
# serving just compares the two.
#   brown / blue / red      one patty of that kind               $30
#   double_<kind>           two patties of one kind              $50
#   special                 a red patty and a blue patty         $60
# One bun and one topping each. Tips come from the patty quality as before;
# a two-patty burger is only as good as its older patty.
# Doubles and the Special start turning up once you've served a few burgers.
extends RefCounted

const RECIPES := {
	"brown": {"name": "Regular", "patties": ["brown"], "price": 30},
	"blue": {"name": "Blue", "patties": ["blue"], "price": 30},
	"red": {"name": "Yellow", "patties": ["red"], "price": 30},
	"double_brown": {"name": "Double Regular", "patties": ["brown", "brown"], "price": 50},
	"double_blue": {"name": "Double Blue", "patties": ["blue", "blue"], "price": 50},
	"double_red": {"name": "Double Yellow", "patties": ["red", "red"], "price": 50},
	"special": {"name": "Special", "patties": ["red", "blue"], "price": 60},
}

const UNLOCK_AFTER := 3        # burgers served before doubles and specials appear
const WEIGHTS := {"brown": 0.55, "blue": 0.3, "red": 0.15}
const WEIGHTS_LATER := {
	"brown": 0.36, "blue": 0.2, "red": 0.1,
	"double_brown": 0.14, "double_blue": 0.08, "double_red": 0.04,
	"special": 0.08,
}

static func name_of(order: String) -> String:
	return String(RECIPES.get(order, RECIPES["brown"])["name"])

const CODES := {"brown":"R", "blue":"B", "red":"Y", "double_brown":"DBL R", "double_blue":"DBL B", "double_red":"DBL Y", "special":"SP"}
static func code(order: String) -> String:
	return String(CODES.get(order,"R"))
static func ticket_text(order: String, quantity: int=1) -> String:
	return "%s X%d" % [code(order),maxi(0,quantity)]
static func colour(order: String) -> Color:
	var palette=preload("res://core/palette.gd")
	if order=="special": return palette.ELECTRIC_TEAL
	if "blue" in order: return palette.ELECTRIC_TEAL
	if "red" in order: return palette.AMBER_GLOW
	return Color(0.52,0.31,0.18)

static func patties(order: String) -> Array:
	return RECIPES.get(order, RECIPES["brown"])["patties"]

static func price(order: String) -> int:
	return int(RECIPES.get(order, RECIPES["brown"])["price"])

static func is_single(order: String) -> bool:
	return patties(order).size() == 1

# A random order; doubles and specials once `served` reaches UNLOCK_AFTER.
static func pick(served: int) -> String:
	var w: Dictionary = WEIGHTS_LATER if served >= UNLOCK_AFTER else WEIGHTS
	var r := randf()
	for k in w:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return "brown"
