extends "res://pickups/mushroom/mushroom_pickup.gd"
signal healed(amount: float)
const BOTTLE=preload("res://pickups/health/bottle_mesh.res")
const HEAL_AMOUNT: float=25.0
var _zone: Area3D
func _ready() -> void:
	add_to_group("health_pickups")
	_model=MeshInstance3D.new()
	_model.mesh=BOTTLE
	_model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_model)
	var label:=Label3D.new()
	label.text="+25 HP"
	label.position.y=0.30
	label.pixel_size=0.003
	label.modulate=Palette.ELECTRIC_TEAL
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	_zone=Area3D.new()
	_zone.name="UseZone"
	_zone.collision_layer=32
	_zone.collision_mask=0
	_zone.monitoring=false
	_zone.monitorable=false
	_zone.set_meta("station",self)
	var shape:=CollisionShape3D.new()
	var sphere:=SphereShape3D.new()
	sphere.radius=0.24
	shape.shape=sphere
	_zone.add_child(shape)
	add_child(_zone)
	_home=global_position
func _process(delta: float) -> void:
	if _taken:return
	_t+=delta
	rotation.y=wrapf(rotation.y+spin_speed*delta,-PI,PI)
	if not _ready_to_collect:return
	# Health stays where it landed: proximity and F2 never consume it.
	_magnet=false
	var target: Vector3=_home+Vector3(0,bob*sin(_t*2.2),0)
	global_position=global_position.move_toward(target,2.5*delta)

func prompt(player: Node) -> String:
	if _taken or not _ready_to_collect or player.is_dead():return ""
	if player.health >= player.max_health:return "HEALTH FULL"
	return "E  USE HEALTH BOTTLE (+25 HP)"

func interact(player: Node) -> void:
	if _taken or not _ready_to_collect or player.is_dead():return
	# Recheck the look ray so a stale focus cannot use a bottle through a wall or at range.
	var camera: Camera3D=player.get_node("Head/Camera3D")
	var query:=PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*float(player.interact_reach),1|32,[player.get_rid()])
	query.collide_with_areas=true
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit["collider"]!=_zone:return
	_collect(player)

func _collect(player: Node3D) -> void:
	if _taken:return
	var restored: float=player.heal(HEAL_AMOUNT)
	if restored <= 0.0:return
	_taken=true
	_zone.collision_layer=0
	remove_from_group("health_pickups")
	if player.focus==self:
		player.focus=null
		player.focus_changed.emit(null)
	healed.emit(restored)
	collected.emit(self)
	queue_free()
