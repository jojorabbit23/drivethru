extends "res://game/station.gd"
var discarded: int=0
func _ready() -> void:
	add_zone(Vector3(0.48,0.8,0.48),Vector3(0,0.4,0))
	# Slim counter-mounted bin: existing cabinet collision keeps the aisle clear.
	add_box(Vector3(0.40,0.62,0.18),Vector3(0,0.31,0),P.OXIDISED_TEAL)
	add_box(Vector3(0.43,0.04,0.21),Vector3(0,0.64,0),P.BURNT_ORANGE)
	add_box(Vector3(0.32,0.01,0.13),Vector3(0,0.665,0),P.WET_CHARCOAL)
	add_label("BIN",Vector3(0,0.85,0),P.WARM_CHALK,24)
	for child in get_children():
		if child is MeshInstance3D:child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func prompt(player: Node) -> String:
	return "E  discard selected burger  ·  V changes selection" if player.held=="burger" else "BURGER BIN  ·  no burger selected"
func interact(player: Node) -> void:discard(player)
func discard(player: Node) -> bool:
	if player.held!="burger":return false
	player.take_selected_burger()
	discarded+=1
	Sfx.play(self,"thunk",-10)
	return true
