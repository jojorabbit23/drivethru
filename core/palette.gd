# The Drive Thru — shared palette (sRGB hex).
# Single source of truth for colours. Change values here, then rebuild the
# shop (see README) so the materials in res://materials/ pick them up.
extends RefCounted

const MIDNIGHT_TYNE  := Color("#101C2C") # deepest navy, darkest surroundings
const BLUE_SLATE     := Color("#24384B") # shaded surfaces, secondary darks
const WET_CHARCOAL   := Color("#272D32") # roads, metal, dark clothing
const CONCRETE_GREY  := Color("#626D73") # neutral materials, worn metal
const OXIDISED_TEAL  := Color("#287E83") # identity colour, painted trim
const ELECTRIC_TEAL  := Color("#65C9C2") # restrained bright accents
const BURNT_ORANGE   := Color("#C96B35") # worn surfaces, boards
const AMBER_GLOW     := Color("#F3A34D") # warm practical lighting
const WARM_CHALK     := Color("#E9E1D1") # text, worn highlights

const ALL := {
	"midnight_tyne": MIDNIGHT_TYNE,
	"blue_slate": BLUE_SLATE,
	"wet_charcoal": WET_CHARCOAL,
	"concrete_grey": CONCRETE_GREY,
	"oxidised_teal": OXIDISED_TEAL,
	"electric_teal": ELECTRIC_TEAL,
	"burnt_orange": BURNT_ORANGE,
	"amber_glow": AMBER_GLOW,
	"warm_chalk": WARM_CHALK,
}
