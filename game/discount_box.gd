extends "res://game/station.gd"
var tray: Node
func _ready() -> void:
	add_box(Vector3(0.48,0.035,0.18),Vector3.ZERO,P.BURNT_ORANGE)
	add_label("DISCOUNT BOX",Vector3(0,0.13,0),P.AMBER_GLOW,20)
	add_zone(Vector3(0.48,0.12,0.18),Vector3(0,0.035,0))
func prompt(player: Node) -> String:
	return "E  clearance: selected cold burger  50% / very cold 25%" if player.held=="burger" else "DISCOUNT BOX  ·  shares the four tray spaces"
func interact(player: Node) -> void:
	deposit(player)
func deposit(player: Node) -> bool:
	if player.held!="burger" or not tray.Items.cold(player.held_burger) or tray.Items.spoiled(player.held_burger):return false
	var b: Dictionary=player.held_burger
	if not tray.deposit(player):return false
	b.discount=true
	tray.refresh()
	return true
