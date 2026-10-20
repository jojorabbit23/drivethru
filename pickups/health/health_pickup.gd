extends "res://pickups/mushroom/mushroom_pickup.gd"
signal healed(amount: float)
const BOTTLE=preload("res://pickups/health/bottle_mesh.res")
const HEAL_AMOUNT: float=50.0
func _ready() -> void:
	add_to_group("health_pickups")
	_model=MeshInstance3D.new()
	_model.mesh=BOTTLE
	_model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_model)
	var label:=Label3D.new()
	label.text="+50 HP"
	label.position.y=0.30
	label.pixel_size=0.003
	label.modulate=Palette.ELECTRIC_TEAL
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	_home=global_position
func _process(delta: float) -> void:
	if _taken:return
	_t+=delta
	rotation.y=wrapf(rotation.y+spin_speed*delta,-PI,PI)
	if not _ready_to_collect:return
	var player: Node3D=get_tree().get_first_node_in_group("player") as Node3D
	var target: Vector3=_home+Vector3(0,bob*sin(_t*2.2),0)
	_magnet=false
	if player and not player.is_dead() and player.health < player.max_health:
		var chest: Vector3=player.global_position+Vector3(0,1.1,0)
		var distance: float=global_position.distance_to(chest)
		if distance < collect_range:
			_collect(player)
			return
		if auto_collect or (distance < magnet_range and _sees(chest)):
			_magnet=true
			target=chest if auto_collect or _clear_line(global_position,chest) else global_position+Vector3.UP
	global_position=global_position.move_toward(target,(5.0 if _magnet else 2.5)*delta)
func _collect(player: Node3D) -> void:
	if _taken:return
	var restored: float=player.heal(HEAL_AMOUNT)
	if restored <= 0.0:return
	_taken=true
	remove_from_group("health_pickups")
	healed.emit(restored)
	collected.emit(self)
	queue_free()
