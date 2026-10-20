extends "res://game/station.gd"
# The rear fridge door is the only purchase point. The far door stays closed.
const PRICE: int=250
var unlocked: bool=false
var _door: StaticBody3D
func _ready() -> void:
 _door=get_parent().get_node("Doors/Delivery_Door")
 get_node("Window_C").remove_from_group("windows")
 add_zone(Vector3(1.28,2.15,.22),Vector3(3,1.08,4.72))
func prompt(_player: Node) -> String:
 if unlocked:return "GARAGE UNLOCKED"
 return "E  unlock garage / storeroom  $250" if economy().cash>=PRICE else "GARAGE LOCKED  $250  (need $%d more)" % (PRICE-economy().cash)
func interact(player: Node) -> void:
 if player.is_dead() or unlocked or not economy().spend(PRICE):return
 unlocked=true
 get_node("GaragePlaque").hide()
 _door.collision_layer=0
 var opening:=create_tween()
 opening.tween_property(_door,"rotation:y",deg_to_rad(-105),.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 opening.finished.connect(_activate_window)
 get_node("Zone").queue_free()
 Sfx.play(self,"till",-8)

func _activate_window() -> void:
 get_node("Window_C").add_to_group("windows")
