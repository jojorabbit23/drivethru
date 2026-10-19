# Visual-only props. Claude owns station actions and successful-deposit wiring.
extends Node3D
var grinder: Node3D
func _ready() -> void:
 top_level=true
 global_transform=Transform3D.IDENTITY
 name="KitchenPresentation"
 grinder=preload("res://presentation/kitchen/grinder.gd").new()
 grinder.name="MushroomGrinder"
 add_child(grinder)
 grinder.position=Vector3(5.42,0.95,-0.42)
 grinder.rotation.y=PI
 # Bin rests beside the sink; clear of the kitchen window and both doors.
 var holder:=Node3D.new()
 holder.name="ColdBurgerBinVisual"
 holder.add_to_group("cold_burger_bin_visual")
 add_child(holder)
 holder.position=Vector3(5.72,0,-1.25)
 var factory: Node3D=grinder
 factory.box(Vector3(0,0.025,0),Vector3(0.36,0.05,0.38),"metal",holder)
 for x in [-0.17,0.17]:factory.box(Vector3(x,0.32,0),Vector3(0.025,0.59,0.38),"kit_teal",holder)
 for z in [-0.18,0.18]:factory.box(Vector3(0,0.32,z),Vector3(0.36,0.59,0.025),"kit_teal",holder)
 factory.box(Vector3(0,0.57,0),Vector3(0.30,0.008,0.32),"ink",holder)
 for z in [-0.20,0.20]:factory.box(Vector3(0,0.63,z),Vector3(0.40,0.04,0.025),"paint_orange",holder)
 for x in [-0.19,0.19]:factory.box(Vector3(x,0.63,0),Vector3(0.025,0.04,0.40),"paint_orange",holder)
 factory.box(Vector3(0,0.04,0.23),Vector3(0.18,0.025,0.10),"metal",holder)
 var body:=StaticBody3D.new()
 body.collision_layer=16
 body.collision_mask=0
 holder.add_child(body)
 var collider:=CollisionShape3D.new()
 var shape:=BoxShape3D.new()
 shape.size=Vector3(0.40,2.3,0.43)
 collider.shape=shape
 collider.position.y=1.15
 body.add_child(collider)
