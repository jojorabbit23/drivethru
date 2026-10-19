extends "res://game/station.gd"
var tray: Node
var index: int
func _ready() -> void:
	add_zone(Vector3(0.38,0.10,0.22),Vector3(0,0.04,0))
func prompt(player: Node) -> String:
	var item: Dictionary = tray.items[index]
	if not item.is_empty():
		if not player.can_carry_burger():return "INVENTORY FULL  ·  make room to retrieve this burger"
		return "E  pick up %s burger  ·  %s" % [tray.recipe_name(item),tray.Items.timer(item)]
	return "E  place selected burger in tray slot %d" % (index+1) if player.held=="burger" else "SERVING TRAY  ·  empty slot %d" % (index+1)
func interact(player: Node) -> void:
	if tray.items[index].is_empty():tray.deposit(player,index)
	else:tray.pick_up(player,index)
