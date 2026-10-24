# The kitchen mushroom grinder: a second drop-off for the mushroom store.
# E grinds every mushroom you're carrying into the same stock the storeroom bin
# fills (one patty each, same yield), then plays the grinder's cosmetic cycle.
#
# The grinder model and animation are Codex's (presentation/kitchen/grinder.gd,
# group "mushroom_grinder"); this station only owns the transaction. Busy policy:
# while the grinder is mid-cycle, E here is refused with a "grinding" prompt, so
# one deposit always gets exactly one animation and nothing is lost or doubled.
# The storeroom bin never waits: it stores immediately and plays the grinder
# only when it's free (see play_grinder).
extends "res://game/station.gd"

var deposits: int = 0

func _ready() -> void:
	# look-zone around the grinder and its receiving tray (hopper at the centre, receiving tray toward +X)
	add_zone(Vector3(0.66, 0.6, 0.42), Vector3(0.1, 0.25, 0))

static func grinder_of(node: Node) -> Node3D:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("mushroom_grinder") as Node3D

static func grinder_busy(node: Node) -> bool:
	var g := grinder_of(node)
	return g != null and bool(g.get("busy"))

# Called after a successful deposit only. Returns true if the cycle started.
static func play_grinder(node: Node, count: int) -> bool:
	var g := grinder_of(node)
	if g == null or count <= 0:
		return false
	return bool(g.call("play_deposit", count))

func prompt(player: Node) -> String:
	var carrying: int = player.mushrooms
	if grinder_busy(self):
		return "GRINDING..."
	if carrying > 0:
		return "E  grind %d mushroom%s into patties" % [carrying, "" if carrying == 1 else "s"]
	var st: Dictionary = economy().stock
	return "GRINDER  ·  %d common  %d blue  %d yellow" % [st["brown"], st["blue"], st["red"]]

func interact(player: Node) -> void:
	var carrying: int = player.mushrooms
	if carrying <= 0 or grinder_busy(self):
		return
	var n: int = economy().store_all(player.drop_carried())
	if n <= 0:
		return
	deposits += 1
	play_grinder(self, n)
