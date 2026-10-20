extends RefCounted
const G: String="Props_Storeroom"
static func material_specs() -> Dictionary:
 var specs: Dictionary={}
 for name: String in ["ceramic_cream","ceramic_navy","floor_charcoal","door_teal","pipe_orange","shelf_steel","rack_navy","crate_wood","carton_brown","fungal_flesh"]:
  var path: String="res://art/fridge_room/pack/textures/"+name+"/"
  specs["cold_"+name]={"texture_path":path+"albedo.png","normal_path":path+"normal_gl.png","roughness_path":path+"roughness.png","metallic_path":path+"metallic.png","uv":"world","roughness":1.0,"metal":1.0}
 specs["cold_floor_charcoal"]["texture_path"]="res://textures/floor_concrete.png"
 specs["cold_floor_charcoal"]["c"]=Color(0.58,0.62,0.64)
 return specs
var b
var d
func box(mat: String,a: Vector3,c: Vector3) -> void:
 b.box(G,mat,a,c,false)
func build(decor) -> void:
 d=decor
 b=d.b
 # Thin finish layers retain all original wall, doorway and player collision.
 var faces: Array=[["x",0.080,0.08,b.IX,[{"at":3.0,"w":1.2,"bottom":0.0,"top":2.2}]],["x",b.IZ-0.005,0.08,b.IX,[b.DELIVERY_DOOR]],["z",0.080,0.08,b.IZ,[{"at":2.4,"w":1.2,"bottom":0.0,"top":2.2}]],["z",b.IX-0.005,0.08,b.IZ,[]]]
 for face: Array in faces:
  b.wall(G,"cold_ceramic_cream",face[0],face[1],0.006,face[2],face[3],face[4],0.0,2.96,false)
  var inner: float=face[1]+(0.009 if face[1]<1.0 else -0.009)
  b.wall(G,"cold_ceramic_navy",face[0],inner,0.006,face[2],face[3],face[4],0.0,0.64,false)
  b.wall(G,"cold_pipe_orange",face[0],inner,0.009,face[2],face[3],face[4],0.64,0.69,false)
 box("cold_floor_charcoal",Vector3(0.08,0.002,0.08),Vector3(b.IX,0.005,b.IZ))
 box("kit_ceiling",Vector3(0.08,2.992,0.08),Vector3(b.IX,2.997,b.IZ))
 # Hanging fungal cuts sit against the wall, clear of the storage station and doors.
 d.pipe_x(G,"cold_shelf_steel",0.35,2.05,2.52,b.IZ-0.18,0.022)
 d.pipe_x(G,"cold_shelf_steel",4.0,5.35,2.52,b.IZ-0.18,0.022)
 for x: float in [0.62,1.53,4.25,5.03]:
  b.prism(G,"cold_shelf_steel",Vector3(x,2.25,b.IZ-0.18),0.018,0.29,6)
  b.obox(G,"cold_fungal_flesh",Vector3(x,1.70,b.IZ-0.20),Vector3(0.43,0.76,0.19),Basis(Vector3.BACK,0.07*(x-2.0)),false)
  for y: float in [1.32,2.08]:
   b.prism(G,"cold_fungal_flesh",Vector3(x,y,b.IZ-0.295),0.215,0.19,8,Basis(Vector3.RIGHT,PI/2))
  for j in 5:
   var at: Vector3=Vector3(x+(-0.21 if j%2 else 0.21),1.25+j*0.20,b.IZ-0.29)
   b.prism(G,"cold_pipe_orange",at,0.10 if j%2 else 0.075,0.065,7)
 # Drain at delivery threshold; flush with floor, no collision lip.
 box("cold_shelf_steel",Vector3(2.32,0.006,b.IZ-0.20),Vector3(3.68,0.009,b.IZ-0.06))
 for i in 20:
  box("cold_rack_navy",Vector3(2.35+i*0.065,0.010,b.IZ-0.18),Vector3(2.37+i*0.065,0.012,b.IZ-0.08))
