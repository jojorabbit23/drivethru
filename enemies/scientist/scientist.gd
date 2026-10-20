extends "res://enemies/shambler/shambler.gd"
const FallenHead = preload("res://enemies/scientist/fallen_head.gd")
const BREATH = preload("res://enemies/scientist/audio/breath.wav")
const SNAP = preload("res://enemies/scientist/audio/snap.wav")
var _last_hit_direction:=Vector3.ZERO
var _voice: AudioStreamPlayer3D
var _breath_timer: float=4.0
var _old_state: int=-1
func _init() -> void:
 max_health=100
 attack_damage=12
 lane_speed=.95
 hunt_speed=1.15
 head_multiplier=3.0
 corpse_time=8.0
func _ready() -> void:
 super._ready()
 _breath_timer=randf_range(4,8)
 if DisplayServer.get_name()!="headless":
  _voice=AudioStreamPlayer3D.new()
  _voice.stream=BREATH
  _voice.bus="Effects"
  _voice.volume_db=-15
  _voice.max_distance=17
  _voice.position.y=1.3
  add_child(_voice)
func _physics_process(delta: float) -> void:
 super._physics_process(delta)
 if is_dead():return
 _breath_timer-=delta
 if _voice and (state==State.ATTACK and _old_state!=state or _breath_timer<=0 and state in [State.HUNT,State.BREACH]):
  _voice.pitch_scale=randf_range(.88,1.08)
  _voice.play()
  _breath_timer=randf_range(6,10)
 _old_state=state
func take_damage(amount: float,headshot:=false,hit: Dictionary={}) -> void:
 if is_dead():return
 _last_hit_direction=hit.get("dir",-global_basis.z)
 super.take_damage(amount,headshot,hit)
func _add_head_hitbox() -> void:
 super._add_head_hitbox()
 var shape: CollisionShape3D=find_child("HeadHitbox",true,false).get_child(0)
 (shape.shape as SphereShape3D).radius=.38
 shape.position=Vector3(0,.27,0)
func _die() -> void:
 if is_dead():return
 var skeleton: Skeleton3D=model.get_node("Skeleton3D")
 skeleton.force_update_all_bone_transforms()
 var attached: MeshInstance3D=skeleton.get_node("DetachableHead/Head")
 var head:=FallenHead.new()
 head.source_mesh=attached.mesh
 head.source_pose=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("head"))
 var direction:=Vector3(_last_hit_direction.x,0,_last_hit_direction.z)
 if direction.length_squared()<.01:direction=-global_basis.z
 head.launch=direction.normalized()*.9+Vector3.UP*1.0
 attached.hide()
 get_parent().add_child(head)
 if _voice:
  _voice.stop()
  _voice.stream=SNAP
  _voice.pitch_scale=1
  _voice.volume_db=-11
  _voice.play()
 super._die()
