# Serving-room presentation from the owner's reference and 4x4 material atlas.
# Called by shop_decor.gd; retains service-counter collision and all working paths.
extends RefCounted
const P=preload("res://core/palette.gd")
static func material_specs() -> Dictionary:
 var regions: Dictionary={
  "serve_wall":Rect2i(2,2,309,309), "serve_floor":Rect2i(315,2,310,309),
  "serve_ceiling":Rect2i(629,2,310,309), "serve_mat":Rect2i(943,2,309,309),
  "serve_cabinet":Rect2i(2,315,309,283), "serve_steel":Rect2i(315,315,310,283),
  "serve_dark":Rect2i(629,315,310,283), "serve_orange":Rect2i(943,315,309,283),
  "serve_shroom_girl":Rect2i(2,602,309,330), "serve_cap_daddy":Rect2i(315,602,310,330),
  "serve_local":Rect2i(629,602,310,330), "serve_refunds":Rect2i(943,602,309,330),
  "serve_carton":Rect2i(2,936,309,316), "serve_bag":Rect2i(315,936,310,316),
  "serve_magazine":Rect2i(629,936,310,316), "serve_hill":Rect2i(943,936,309,316)}
 var files: Dictionary={
  "serve_wall":"wall_tiles", "serve_floor":"checker_floor", "serve_ceiling":"ceiling_tiles", "serve_mat":"rubber_mat",
  "serve_cabinet":"teal_cabinet", "serve_steel":"steel_counter", "serve_dark":"navy_metal", "serve_orange":"orange_conduit",
  "serve_shroom_girl":"poster_shroom_girl", "serve_cap_daddy":"poster_cap_daddy", "serve_local":"sign_eat_local", "serve_refunds":"sign_no_refunds",
  "serve_carton":"burger_box_graphic", "serve_bag":"paper_bag_graphic", "serve_magazine":"magazine_shroom", "serve_hill":"magazine_hill_climb"}
 var specs: Dictionary={}
 for key: String in regions:
  specs[key]={"atlas":regions[key],"texture_path":"res://art/serving_room/pack/"+files[key]+".png","uv":"face"}
 specs["serve_wall"]["uv"]="world"
 specs["serve_wall"]["repeat"]=2.0
 specs["serve_floor"]["uv"]="world"
 specs["serve_ceiling"]["uv"]="world"
 specs["serve_mat"]["uv"]="world"
 specs["serve_mat"]["repeat"]=4.0
 specs["serve_steel"]["uv"]="world"
 specs["serve_steel"]["metal"]=0.45
 specs["serve_steel"]["roughness"]=0.75
 specs["serve_owner_pinup"]={"texture_path":"res://art/posters/service_yeasty_pinup.png","uv":"face","roughness":1.0}
 specs["serve_owner_selection"]={"texture_path":"res://art/posters/service_last_selection.png","uv":"face","roughness":1.0}
 return specs
var d
var b
const G: String="Props_Shop"
func box(mat: String, low: Vector3, high: Vector3) -> void:
 b.box(G,mat,low,high,false)
func build(decor) -> void:
 d=decor
 b=d.b
 var iz: float=b.IZ
 var ix: float=b.IX
 # Thin finish skins are visual only, sharing the original room boundaries.
 b.wall(G,"serve_wall","x",-iz+0.005,0.006,-ix,-0.075,[b.HATCH],0.0,2.96,false)
 b.wall(G,"serve_wall","z",-ix+0.005,0.006,-iz,-0.075,[],0.0,2.96,false)
 var east_door: Array=[{"at":-2.4,"w":1.2,"bottom":0.0,"top":2.2}]
 b.wall(G,"serve_wall","z",-0.080,0.006,-iz,-0.075,east_door,0.0,2.96,false)
 var south_door: Array=[{"at":-3.0,"w":1.2,"bottom":0.0,"top":2.2}]
 b.wall(G,"serve_wall","x",-0.080,0.006,-ix,-0.075,south_door,0.0,2.96,false)
 box("serve_floor",Vector3(-ix,0.001,-iz),Vector3(-0.08,0.004,-0.08))
 box("serve_ceiling",Vector3(-ix,2.992,-iz),Vector3(-0.08,2.997,-0.08))
 # Same footprint, counter height, clip and collision as the original service desk.
 for i in 7:
  var x0: float=-5.6+i*0.8
  var x1: float=minf(x0+0.8,-0.075)
  box("serve_dark",Vector3(x0,0,-iz),Vector3(x1,0.93,-iz+0.65))
  box("serve_cabinet",Vector3(x0+0.02,0.06,-iz+0.65),Vector3(x1-0.02,0.87,-iz+0.665))
  box("paint_orange",Vector3(x1-0.12,0.48,-iz+0.668),Vector3(x1-0.09,0.69,-iz+0.69))
 box("serve_steel",Vector3(-5.65,0.93,-iz),Vector3(-0.075,1.0,-iz+0.70))
 box("paint_orange",Vector3(-5.65,0.90,-iz+0.70),Vector3(-0.075,0.93,-iz+0.72))
 b.col(G,Vector3(-5.65,0,-iz),Vector3(-0.075,1.0,-iz+0.70))
 b.clip(G,Vector3(-ix,0,-iz),Vector3(-0.075,2.4,-iz+0.70))
 box("serve_steel",Vector3(-3.88,1.0,-5.30),Vector3(-2.12,1.04,-iz+0.2))
 box("serve_mat",Vector3(-4.60,0.005,-iz+0.80),Vector3(-1.40,0.012,-iz+1.50))
 register()
 stock_shelf()
 fridge()
 counter_props()
 posters()
 # Existing bin/clip remain at the kitchen corner, leaving both doors open.
 b.prism(G,"serve_dark",Vector3(-0.33,0,-0.33),0.22,0.75,8,Basis.IDENTITY,true)
 b.prism(G,"paint_orange",Vector3(-0.33,0.75,-0.33),0.23,0.04,8)
 b.clip(G,Vector3(-0.6,0,-0.6),Vector3(-0.075,2.4,-0.075))
func register() -> void:
 box("serve_dark",Vector3(-4.65,1.0,-4.60),Vector3(-4.20,1.10,-4.25))
 var t: Transform3D=d.T(Vector3(-4.42,1.10,-4.5))
 d.rbox(G,"serve_dark",t,Vector3(0,0.15,0),Vector3(0.34,0.26,0.04),d.rotx(-15))
 d.rbox(G,"screen",t,Vector3(0,0.15,0.023),Vector3(0.28,0.20,0.01),d.rotx(-15))
 b.prism(G,"metal",Vector3(-4.42,1.10,-4.53),0.02,0.05,6)
func stock_shelf() -> void:
 # Match the original shelf's collider instead of expanding into the walking lane.
 var x0: float=-b.IX
 var x1: float=x0+0.48
 for x in [x0+0.02,x1-0.02]:
  for z in [-3.93,-1.87]:box("serve_dark",Vector3(x-0.02,0,z-0.02),Vector3(x+0.02,1.9,z+0.02))
 for level in 4:
  var y: float=0.08+level*0.45
  box("serve_steel",Vector3(x0,y,-3.95),Vector3(x1,y+0.03,-1.85))
  for item in 6:
   var z: float=-3.76+item*0.32
   var mat: String="serve_carton" if (item+level)%3!=0 else "serve_bag"
   box(mat,Vector3(x0+0.07,y+0.03,z-0.12),Vector3(x1-0.025,y+0.30,z+0.12))
   if (item+level)%2==0:
    b.prism(G,"paint_orange",Vector3(x1-0.03,y+0.03,z+0.03),0.045,0.16,8)
    b.prism(G,"metal",Vector3(x1-0.03,y+0.19,z+0.03),0.045,0.012,8)
 b.col(G,Vector3(x0,0,-3.95),Vector3(x1,1.9,-1.85))
func fridge() -> void:
 box("serve_dark",Vector3(-5.60,0,-0.95),Vector3(-4.70,1.95,-0.10))
 b.col(G,Vector3(-5.60,0,-0.95),Vector3(-4.70,1.95,-0.10))
 # Door faces into the room; no bright glass on the closed industrial fridge.
 box("serve_cabinet",Vector3(-4.695,0.12,-0.89),Vector3(-4.68,1.87,-0.16))
 box("paint_orange",Vector3(-4.66,0.65,-0.80),Vector3(-4.62,1.30,-0.76))
 box("serve_orange",Vector3(-5.6,1.95,-0.95),Vector3(-4.7,2.15,-0.10))
 box("serve_carton",Vector3(-5.48,2.15,-0.84),Vector3(-5.04,2.38,-0.40))
 box("serve_bag",Vector3(-5.0,2.15,-0.78),Vector3(-4.76,2.40,-0.40))
func counter_props() -> void:
 for i in 3:
  for row in 2:
   b.prism(G,"paint_orange" if row==0 else "paint_amber",Vector3(-2.0+i*0.10,1.0,-4.60+row*0.11),0.035,0.19-row*0.03,8)
 box("serve_steel",Vector3(-1.72,1.0,-4.62),Vector3(-1.52,1.16,-4.48))
 for i in 2:
  var x: float=-1.3+i*0.27
  box("serve_bag",Vector3(x,1.0,-4.56),Vector3(x+0.22,1.31,-4.40))
 box("serve_carton",Vector3(-2.05,1.0,-4.3),Vector3(-1.72,1.12,-4.08))
 for i in 6:b.prism(G,"chalk",Vector3(-5.35,1.0+i*0.025,-4.50),0.085,0.02,10)
 for x in [-5.12,-4.95]:b.prism(G,"serve_steel",Vector3(x,1.0,-4.50),0.055,0.18,8)
 # Two magazines, with their cover tiles face-up under the customer's side light.
 b.obox(G,"serve_magazine",Vector3(-0.77,1.015,-4.30),Vector3(0.28,0.018,0.37),d.roty(12),false)
 b.obox(G,"serve_hill",Vector3(-0.38,1.015,-4.30),Vector3(0.28,0.018,0.37),d.roty(-8),false)
 # Small food warmer at the far end; only its real lamp emits light.
 box("serve_dark",Vector3(-0.80,1.0,-4.70),Vector3(-0.12,1.08,-4.40))
 for x in [-0.77,-0.15]:box("serve_steel",Vector3(x,1.08,-4.68),Vector3(x+0.018,1.52,-4.43))
 box("serve_dark",Vector3(-0.82,1.52,-4.72),Vector3(-0.10,1.61,-4.39))
 box("lamp",Vector3(-0.73,1.515,-4.65),Vector3(-0.19,1.52,-4.45))
 b.light("ServingWarmer",Vector3(-0.46,1.35,-4.38),P.AMBER_GLOW,0.28,1.5)
 for i in 2:box("serve_carton",Vector3(-0.68+i*0.25,1.08,-4.66),Vector3(-0.48+i*0.25,1.17,-4.48))
 # Fire extinguisher mounted outside the hatch opening.
 b.prism(G,"paint_orange",Vector3(-1.55,1.50,-4.65),0.075,0.34,10)
 box("metal",Vector3(-1.62,1.85,-4.68),Vector3(-1.48,1.90,-4.63))
func posters() -> void:
 # Owner's portrait and square prints on the back wall, beside the office door.
 box("serve_dark",Vector3(-2.205,1.225,-0.131),Vector3(-1.455,2.325,-0.09))
 box("serve_owner_pinup",Vector3(-2.18,1.25,-0.145),Vector3(-1.48,2.30,-0.132))
 box("serve_dark",Vector3(-1.325,1.355,-0.131),Vector3(-0.355,2.325,-0.09))
 box("serve_owner_selection",Vector3(-1.30,1.38,-0.145),Vector3(-0.38,2.30,-0.132))
 # Posters are thin boxes with complete face UVs and no extra collision.
 box("serve_shroom_girl",Vector3(-5.735,1.99,-2.77),Vector3(-5.719,2.76,-2.04))
 box("serve_cap_daddy",Vector3(-5.735,2.17,-1.70),Vector3(-5.719,2.77,-1.14))
 box("serve_local",Vector3(-3.53,2.12,-4.738),Vector3(-2.53,2.65,-4.72))
 box("serve_refunds",Vector3(-1.64,2.13,-4.738),Vector3(-0.68,2.65,-4.72))
