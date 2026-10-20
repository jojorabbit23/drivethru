# Short-lived cosmetic physics, excluded from combat, rewards and player collisions.
extends RigidBody3D
const MAX_HEADS: int=6
const LANDING = preload("res://enemies/scientist/audio/landing.wav")
var source_mesh: Mesh
var source_pose:=Transform3D.IDENTITY
var launch:=Vector3.ZERO
var impacted: bool=false
func _ready() -> void:
 add_to_group("scientist_heads")
 var heads: Array=get_tree().get_nodes_in_group("scientist_heads")
 if heads.size()>MAX_HEADS:
  heads[0].remove_from_group("scientist_heads")
  heads[0].queue_free()
 collision_layer=0
 collision_mask=1
 mass=.8
 linear_damp=1.2
 angular_damp=1.4
 contact_monitor=true
 max_contacts_reported=2
 var physics_material:=PhysicsMaterial.new()
 physics_material.bounce=.17
 physics_material.friction=.85
 physics_material_override=physics_material
 var bounds: AABB=source_mesh.get_aabb()
 var centre: Vector3=bounds.get_center()
 var model:=MeshInstance3D.new()
 model.name="FallenHead"
 model.mesh=source_mesh
 model.position=-centre
 model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(model)
 var shape:=CollisionShape3D.new()
 var box:=BoxShape3D.new()
 box.size=bounds.size*Vector3(.73,.85,.73)
 shape.shape=box
 add_child(shape)
 global_transform=Transform3D(source_pose.basis,source_pose*centre)
 linear_velocity=launch
 angular_velocity=Vector3(2.3,randf_range(-1.8,1.8),-1.7)
 body_entered.connect(_landed)
 get_tree().create_timer(5.0).timeout.connect(_expire)
func _landed(_body: Node) -> void:
 if impacted:return
 impacted=true
 if DisplayServer.get_name()=="headless":return
 var sound:=AudioStreamPlayer3D.new()
 sound.stream=LANDING
 sound.bus="Effects"
 sound.volume_db=-15
 sound.max_distance=12
 add_child(sound)
 sound.play()
func _expire() -> void:
 freeze=true
 collision_mask=0
 var tween:=create_tween()
 tween.tween_property(self,"scale",Vector3.ONE*.01,.35)
 tween.tween_callback(queue_free)
