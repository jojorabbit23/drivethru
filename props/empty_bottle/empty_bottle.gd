extends StaticBody3D
const SOUND=preload("res://props/empty_bottle/glass_break.wav")
var broken: bool=false
func _ready() -> void:
 add_to_group("destructible_props")
func take_prop_damage(amount: float) -> void:
 if broken or amount<=0.0:return
 broken=true
 collision_layer=0
 for child: Node in get_children():
  if child is MeshInstance3D:child.hide()
 var sound:=AudioStreamPlayer3D.new();sound.stream=SOUND;sound.bus="Effects";sound.volume_db=-8.0;sound.max_distance=15.0
 get_tree().root.add_child(sound);sound.global_position=global_position;sound.finished.connect(sound.queue_free);sound.play()
 if DisplayServer.get_name()!="headless":
  var mat:=StandardMaterial3D.new();mat.albedo_color=preload("res://core/palette.gd").OXIDISED_TEAL;mat.roughness=0.3
  var shards:=Node3D.new();get_tree().root.add_child(shards);shards.global_position=global_position+Vector3(0,0.12,0)
  for i in 7:
   var shard:=MeshInstance3D.new();var mesh:=PrismMesh.new();mesh.size=Vector3(0.018,0.035,0.009);mesh.material=mat;shard.mesh=mesh;shards.add_child(shard)
   shard.rotation=Vector3(i*1.7,i*0.9,i*2.1)
   var direction:=Vector3(cos(i*2.4)*0.20,0.06+float(i%3)*0.04,sin(i*2.4)*0.20)
   var tween:=shard.create_tween();tween.tween_property(shard,"position",direction,0.14);tween.tween_property(shard,"position",Vector3(direction.x,-0.11,direction.z),0.26);tween.tween_property(shard,"scale",Vector3.ZERO,0.20)
  get_tree().create_timer(0.7).timeout.connect(shards.queue_free)
 get_tree().create_timer(0.8).timeout.connect(queue_free)
