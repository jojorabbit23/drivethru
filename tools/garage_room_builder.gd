# Garage structure reuses shop materials; motorcycle uses the retained owner GLB.
extends RefCounted
const WINDOW: Dictionary={"id":"C","side":"east","at":8.0,"w":1.4,"bottom":.9,"top":2.1,"room":"Garage","origin":Vector3(6,1.5,8)}
var b
func build(builder,decor) -> void:
 b=builder
 var g: String="GarageShell"
 b.box(g,"floor_concrete",Vector3(0,-.1,5),Vector3(6,0,11.5))
 b.wall(g,"ext_wall","z",.09,.18,5,11.5,[])
 b.wall(g,"int_wall","z",.215,.07,5,11.5,[])
 b.wall(g,"ext_wall","z",5.91,.18,5,11.5,[WINDOW])
 b.wall(g,"int_wall","z",5.785,.07,5,11.5,[WINDOW])
 var opening: Dictionary={"at":3.0,"w":1.4,"bottom":0.0,"top":2.3}
 b.wall(g,"ext_wall","x",11.41,.18,0,6,[opening])
 b.wall(g,"int_wall","x",11.285,.07,0,6,[opening])
 b.box("GarageCeiling","ceiling",Vector3(0,3,5),Vector3(6,3.05,11.5))
 b.box("GarageRoof","roof",Vector3(-.3,3.05,5),Vector3(6.3,3.25,11.8))
 b.box("Decor_Garage","metal",Vector3(.3,2.72,5.3),Vector3(5.7,2.8,5.4),false)
 b.box("Decor_Garage","paint_orange",Vector3(.3,2.77,5.41),Vector3(5.7,2.8,5.44),false)
 b.box("Decor_Garage","metal",Vector3(2.3,2.92,7.5),Vector3(3.7,2.99,8.0),false)
 b.box("Decor_Garage","panel_light",Vector3(2.35,2.90,7.55),Vector3(3.65,2.92,7.95),false)
 # Reuse the fridge shelving and its cardboard texture, with open spaces for parts.
 for x: float in [.3,.9]:
  for z: float in [5.8,8.7]:b.box("Props_Garage","metal",Vector3(x-.025,0,z-.025),Vector3(x+.025,2,z+.025),false)
 for level in 4:
  var y: float=.08+level*.475
  b.box("Props_Garage","steel",Vector3(.3,y,5.8),Vector3(.9,y+.03,8.7),false)
  decor.carton("Props_Garage",Transform3D.IDENTITY,Vector3(.6,y+.03,6.9),Vector3(.42,.3,.5))
 b.col("Props_Garage",Vector3(.28,0,5.78),Vector3(.93,2,8.72))
 for row in 3:
  for column in 2:
   decor.carton("Props_Garage",Transform3D.IDENTITY,Vector3(4.4+column*.65,row*.48,10.4),Vector3(.6,.48,.65),float(column*4-row*3))
 decor.carton("Props_Garage",Transform3D.IDENTITY,Vector3(4.7,1.44,10.45),Vector3(.55,.4,.5),-8)
 b.build_window_lane(WINDOW)
func add_live_nodes(shop: Node3D) -> Node3D:
 var garage:=Node3D.new();garage.name="Garage";shop.add_child(garage)
 b.make_windows(garage,[WINDOW])
 var bike:=StaticBody3D.new();bike.name="Motorcycle";bike.position=Vector3(1.5,0,10);bike.rotation_degrees.y=135
 var bike_mesh:=MeshInstance3D.new();bike_mesh.name="SuppliedModel";bike_mesh.mesh=load("res://props/motorcycle/motorcycle_mesh.res");bike.add_child(bike_mesh)
 var bike_shape:=CollisionShape3D.new();var bike_box:=BoxShape3D.new();bike_box.size=Vector3(.85,1.15,2.25);bike_shape.shape=bike_box;bike_shape.position.y=.575;bike.add_child(bike_shape);garage.add_child(bike)
 var far_door:=StaticBody3D.new();far_door.name="RearDoorClosed";far_door.position=Vector3(3,1.14,11.4)
 var mesh:=MeshInstance3D.new();mesh.mesh=b.single_box_mesh("door",Vector3(1.36,2.28,.08));far_door.add_child(mesh)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.36,2.28,.08);collision.shape=shape;far_door.add_child(collision);garage.add_child(far_door)
 for x: float in [2.27,3.73]:
  var jamb:=MeshInstance3D.new();jamb.mesh=b.single_box_mesh("trim",Vector3(.08,2.38,.12));jamb.position=Vector3(x,1.19,11.36);garage.add_child(jamb)
 var parts:=Node3D.new();parts.name="FungalStock";garage.add_child(parts)
 for i in 5:
  var item:=MeshInstance3D.new();item.name="FungalCut_%d"%i;item.mesh=load("res://props/fungal_stock/cut_%d.res"%i)
  item.position=Vector3(.59,.11+(i%4)*.475,6.15+(i/4)*1.85);item.rotation_degrees.y=-90;item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parts.add_child(item)
 var bottles:=Node3D.new();bottles.name="EmptyBottles";garage.add_child(bottles)
 for at: Vector3 in [Vector3(5.16,1.44,10.45),Vector3(.57,1.535,8.30),Vector3(.57,1.06,7.5)]:
  var bottle:=StaticBody3D.new();bottle.name="Bottle_%d"%bottles.get_child_count();bottle.position=at;bottle.set_script(load("res://props/empty_bottle/empty_bottle.gd"))
  var bm:=MeshInstance3D.new();bm.mesh=load("res://props/empty_bottle/bottle_mesh.res");bottle.add_child(bm)
  var cs:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.045;cylinder.height=.27;cs.shape=cylinder;cs.position.y=.135;bottle.add_child(cs);bottles.add_child(bottle)
 b.add_omni(garage,"GarageLamp",Vector3(3,2.65,8),preload("res://core/palette.gd").WARM_CHALK,1.15,5,false)
 var plaque:=Label3D.new();plaque.name="GaragePlaque";plaque.text="GARAGE $250";plaque.font_size=36;plaque.pixel_size=.003;plaque.position=Vector3(3,1.55,4.855);plaque.rotation.y=PI;plaque.modulate=preload("res://core/palette.gd").AMBER_GLOW;garage.add_child(plaque)
 return garage

