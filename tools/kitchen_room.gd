# Owner-reference kitchen rework. Geometry is merged by the shop builder.
extends RefCounted
const P=preload("res://core/palette.gd")
const G: String="Props_Kitchen"
static func material_specs() -> Dictionary:
 var files: Dictionary={"kit_wall":"splattered_wall_tiles","kit_teal":"chipped_teal_metal","kit_towel":"orange_towel","kit_mat":"rubber_mat","kit_floor":"dirty_checker_floor","kit_spores":"label_spores","kit_cap":"mushroom_cap","kit_steel":"scratched_steel","kit_stalk":"mushroom_stalk","kit_stalk_label":"label_stalks","kit_box":"packaging_graphic","kit_ceiling":"stained_ceiling","kit_griddle":"scorched_griddle","kit_board":"chopping_board","kit_caps":"label_caps","kit_recipe":"recipe_board"}
 var specs: Dictionary={}
 for key: String in files:
  specs[key]={"texture_path":"res://art/kitchen/pack/"+files[key]+".png","uv":"face"}
 for key in ["kit_wall","kit_floor","kit_ceiling","kit_steel","kit_mat"]:specs[key]["uv"]="world"
 # The owner requested the calmer serving-room finishes for the kitchen.
 specs["kit_wall"]["texture_path"]="res://art/serving_room/pack/wall_tiles.png"
 specs["kit_floor"]["texture_path"]="res://art/serving_room/pack/checker_floor.png"
 specs["kit_ceiling"]["texture_path"]="res://art/serving_room/pack/ceiling_tiles.png"
 specs["kit_steel"]["texture_path"]="res://art/serving_room/pack/steel_counter.png"
 specs["kit_wall"]["repeat"]=2.0
 specs["kit_mat"]["repeat"]=4.0
 specs["kit_steel"]["roughness"]=0.78
 specs["kit_steel"]["metal"]=0.05
 specs["kit_wall"]["c"]=P.WARM_CHALK.lerp(P.CONCRETE_GREY,0.18)
 specs["kit_ceiling"]["c"]=P.WARM_CHALK.lerp(P.CONCRETE_GREY,0.12)
 # Cheese uses the shared palette; tomato red follows the owner-supplied food reference.
 var tomato_red:=Color("#C9432D")
 specs["kit_cheese_gold"]={"c":P.AMBER_GLOW,"roughness":0.8}
 specs["kit_tomato_skin"]={"c":tomato_red.darkened(0.20),"roughness":0.55}
 specs["kit_tomato_flesh"]={"c":tomato_red,"roughness":0.65}
 specs["kit_tomato_chamber"]={"c":tomato_red.darkened(0.38)}
 specs["kit_tomato_pith"]={"c":tomato_red.lerp(P.WARM_CHALK,0.45)}
 specs["kit_tomato_seed"]={"c":P.AMBER_GLOW.lerp(P.WARM_CHALK,0.35)}
 specs["kit_owner_poster"]={"texture_path":"res://art/posters/kitchen_misery_sermon.png","uv":"face","roughness":1.0}
 specs["kit_morel_drivers"]={"texture_path":"res://art/posters/kitchen_morel_drivers_worn.png","uv":"face","roughness":1.0}
 return specs
var b
var d
func box(mat: String, low: Vector3, high: Vector3, collide: bool=false) -> void:
 b.box(G,mat,low,high,collide)
func build(decor) -> void:
 d=decor
 b=d.b
 finishes()
 cooking_line()
 cold_storage()
 sink()
 ingredient_rack()
 wall_details()
func finishes() -> void:
 var ix: float=b.IX
 var iz: float=b.IZ
 b.wall(G,"kit_wall","x",-iz+0.005,0.006,0.075,ix,[],0.0,2.96,false)
 # Keep the real repair/breach window unobstructed.
 var opening: Array=[{"at":-2.4,"w":1.4,"bottom":0.9,"top":2.1}]
 b.wall(G,"kit_wall","z",ix-0.005,0.006,-iz,-0.075,opening,0.0,2.96,false)
 var west: Array=[{"at":-2.4,"w":1.2,"bottom":0.0,"top":2.2}]
 var south: Array=[{"at":3.0,"w":1.2,"bottom":0.0,"top":2.2}]
 b.wall(G,"kit_wall","z",0.080,0.006,-iz,-0.075,west,0.0,2.96,false)
 b.wall(G,"kit_wall","x",-0.080,0.006,0.075,ix,south,0.0,2.96,false)
 box("kit_floor",Vector3(0.08,0.001,-iz),Vector3(ix,0.004,-0.08))
 box("kit_ceiling",Vector3(0.08,2.992,-iz),Vector3(ix,2.997,-0.08))
 box("kit_mat",Vector3(1.40,0.005,-4.05),Vector3(3.80,0.012,-3.40))
 # A small flush floor drain cannot catch the movement capsule.
 box("metal",Vector3(3.95,0.005,-1.20),Vector3(4.20,0.010,-0.95))
 for i in 4:box("kit_steel",Vector3(3.99+i*0.05,0.011,-1.17),Vector3(4.012+i*0.05,0.013,-0.98))
func cooking_line() -> void:
 var z0: float=-b.IZ
 var z1: float=z0+0.65
 # Original prep/griddle/fryer collision extents and live patty height retained.
 box("kit_steel",Vector3(0.075,0,z0),Vector3(1.5,0.92,z1),true)
 b.clip(G,Vector3(0.075,0,z0),Vector3(4.85,2.4,z1))
 b.clip(G,Vector3(5.4,0,-3.95),Vector3(b.IX,2.4,-3.37))
 box("kit_board",Vector3(0.38,0.92,z0+0.12),Vector3(1.02,0.95,z0+0.52))
 for i in 4:mushroom(Vector3(0.48+i*0.12,0.95,z0+0.25),0.045)
 box("kit_steel",Vector3(1.5,0,z0),Vector3(2.7,0.85,z1),true)
 box("kit_griddle",Vector3(1.52,0.85,z0+0.02),Vector3(2.68,0.92,z1-0.02),true)
 box("kit_steel",Vector3(1.5,0.92,z0),Vector3(2.7,1.15,z0+0.05))
 # All patties on this surface are still owned by game/grill.gd.
 box("kit_steel",Vector3(2.7,0,z0),Vector3(3.6,0.92,z1),true)
 for i in 2:
  var x: float=2.78+i*0.42
  box("metal",Vector3(x,0.88,z0+0.1),Vector3(x+0.34,0.925,z1-0.12))
  box("fries",Vector3(x+0.05,0.9,z0+0.18),Vector3(x+0.29,0.98,z1-0.2))
  box("metal",Vector3(x+0.15,0.95,z1-0.2),Vector3(x+0.19,0.98,z1+0.08))
 box("kit_steel",Vector3(3.6,0,z0),Vector3(4.4,0.92,z1),true)
 # Shallow ingredient trays: square cheese slices and seeded tomato rounds.
 for x: float in [3.79,4.17]:
  box("metal",Vector3(x-0.175,0.921,z0+0.10),Vector3(x+0.175,0.930,z0+0.64))
  for z: float in [z0+0.10,z0+0.64]:box("kit_steel",Vector3(x-0.18,0.930,z-0.007),Vector3(x+0.18,0.943,z+0.007))
 for row in 2:
  for layer in 3:
   var centre:=Vector3(3.79+0.010*(layer%2),0.935+layer*0.007,z0+0.26+row*0.24)
   var basis:=Basis(Vector3.UP,deg_to_rad(-9.0+layer*9.0+row*4.0))
   b.obox(G,"kit_cheese_gold",centre,Vector3(0.205,0.006,0.185),basis,false)
 tomato(Vector3(4.11,0.932,z0+0.35),0.10)
 tomato(Vector3(4.23,0.947,z0+0.45),-0.25)
 tomato(Vector3(4.10,0.963,z0+0.535),0.30)
 # Cabinet-front seams, ventilation and actual orange handles.
 for x in [0.15,0.80,1.55,2.15,2.75,3.30,3.85]:
  box("metal",Vector3(x,0.10,z1+0.002),Vector3(x+0.012,0.83,z1+0.008))
  box("paint_orange",Vector3(x+0.13,0.70,z1+0.009),Vector3(x+0.36,0.73,z1+0.04))
 for i in 3:box("metal",Vector3(0.18,0.16+i*0.06,z1+0.004),Vector3(0.60,0.18+i*0.06,z1+0.015))
 box("kit_towel",Vector3(0.82,0.40,z1+0.045),Vector3(1.12,0.89,z1+0.06))
 # Hood: steel shell, deep vent slots and warm task light underneath.
 box("kit_steel",Vector3(1.35,2.15,z0),Vector3(3.75,2.55,z0+0.85))
 box("metal",Vector3(1.40,2.145,z0+0.12),Vector3(3.70,2.15,z0+0.77))
 for i in 25:
  var x: float=1.44+i*0.09
  box("kit_steel",Vector3(x,2.13,z0+0.13),Vector3(x+0.022,2.15,z0+0.76))
 box("kit_steel",Vector3(1.35,2.05,z0+0.80),Vector3(3.75,2.15,z0+0.85))
 box("metal",Vector3(1.40,2.065,z0+0.86),Vector3(3.70,2.27,z0+0.872))
 for i in 30:
  var vent_x: float=1.44+i*0.075
  b.obox(G,"kit_steel",Vector3(vent_x,2.17,z0+0.881),Vector3(0.018,0.19,0.014),d.rotz(-12),false)
 box("lamp",Vector3(1.5,2.14,z0+0.60),Vector3(3.6,2.15,z0+0.70))
 box("kit_steel",Vector3(2.25,2.55,-4.4),Vector3(2.85,3.0,-4.0))
 b.light("HoodLight",Vector3(2.55,1.9,z0+0.5),P.AMBER_GLOW.lerp(P.WARM_CHALK,0.4),0.65,2.7)
 utensils()
 # Ingredients on open shelves, above the left prep bench.
 for y in [1.30,1.89]:
  box("metal",Vector3(0.17,y,-4.73),Vector3(1.23,y+0.035,-4.38))
 for i in 3:jar(Vector3(0.36+i*0.32,1.925,-4.57),["kit_caps","kit_stalk_label","kit_spores"][i])
 for i in 4:
  bottle(Vector3(0.30+i*0.16,1.335,-4.55),i%2==0)
 box("kit_recipe",Vector3(3.91,1.52,-4.736),Vector3(4.65,2.32,-4.715))
 # Knife and ingredients remain on the prep board, clear of the live griddle slots.
 box("metal",Vector3(0.86,0.957,-4.52),Vector3(1.10,0.97,-4.47))
 box("paint_orange",Vector3(1.10,0.957,-4.52),Vector3(1.24,0.98,-4.47))
func cold_storage() -> void:
 box("kit_steel",Vector3(4.85,0,-b.IZ+0.05),Vector3(5.7,2.0,-3.95),true)
 for span: Vector2 in [Vector2(0.12,1.23),Vector2(1.29,1.93)]:
  box("kit_teal",Vector3(4.89,span.x,-3.947),Vector3(5.66,span.y,-3.93))
 for span: Vector2 in [Vector2(0.65,1.1),Vector2(1.45,1.80)]:
  box("paint_orange",Vector3(4.96,span.x,-3.91),Vector3(5.0,span.y,-3.86))
 for i in 3:box("metal",Vector3(5.12,0.16+i*0.055,-3.92),Vector3(5.55,0.178+i*0.055,-3.91))
 box("kit_box",Vector3(4.94,2.0,-4.57),Vector3(5.52,2.26,-4.10))
 for i in 3:mushroom(Vector3(5.02+i*0.15,2.26,-4.35),0.07)
func sink() -> void:
 # New sink stays against the south-east wall, outside door and breach approaches.
 var x0: float=4.18
 var x1: float=5.55
 var z0: float=-0.70
 var z1: float=-0.12
 for x in [x0+0.03,x1-0.07]:
  for z in [z0+0.03,z1-0.06]:box("kit_steel",Vector3(x,0,z),Vector3(x+0.04,0.87,z+0.04))
 box("kit_steel",Vector3(x0,0.84,z0),Vector3(x1,0.89,z1))
 box("metal",Vector3(x0+0.12,0.892,z0+0.08),Vector3(x0+0.73,0.897,z1-0.08))
 for x in [x0+0.09,x0+0.73]:box("kit_steel",Vector3(x,0.89,z0+0.06),Vector3(x+0.03,0.94,z1-0.05))
 for z in [z0+0.05,z1-0.07]:box("kit_steel",Vector3(x0+0.09,0.89,z),Vector3(x0+0.76,0.94,z+0.03))
 box("kit_steel",Vector3(x0,0.89,z1-0.04),Vector3(x1,1.08,z1))
 b.prism(G,"kit_steel",Vector3(4.74,0.94,-0.22),0.022,0.30,8)
 d.pipe_z(G,"kit_steel",-0.40,-0.22,1.24,4.74,0.022)
 b.prism(G,"kit_steel",Vector3(4.74,1.15,-0.40),0.022,0.09,8)
 box("kit_towel",Vector3(4.35,0.42,-0.727),Vector3(4.66,0.89,-0.711))
 box("kit_box",Vector3(5.0,0.04,-0.58),Vector3(5.4,0.55,-0.20))
 b.col(G,Vector3(x0,0,z0),Vector3(x1,0.94,z1))
 b.clip(G,Vector3(x0,0,z0),Vector3(x1,2.4,z1))
 box("kit_mat",Vector3(4.13,0.005,-1.38),Vector3(5.60,0.012,-0.75))
 for i in 2:
  var x: float=5.02+i*0.23
  box("kit_steel",Vector3(x-0.08,0.90,-0.55),Vector3(x+0.08,0.95,-0.28))
  for j in 3:mushroom(Vector3(x,0.95,-0.47+j*0.07),0.035)
func ingredient_rack() -> void:
 # Same footprint and collision as the previous bun rack.
 for x in [0.37,1.33]:
  for z in [-0.60,-0.12]:box("metal",Vector3(x-0.02,0,z-0.02),Vector3(x+0.02,1.95,z+0.02))
 for i in 4:
  var y: float=0.25+i*0.42
  box("kit_steel",Vector3(0.35,y,-0.62),Vector3(1.35,y+0.025,-0.10))
  if i==3:
   for j in 3:jar(Vector3(0.53+j*0.30,y+0.025,-0.36),["kit_caps","kit_stalk_label","kit_spores"][j])
  elif i==0:
   for j in 2:box("kit_box",Vector3(0.42+j*0.43,y+0.025,-0.55),Vector3(0.80+j*0.43,y+0.30,-0.17))
  else:
   for j in 4:
    for row in 2:b.prism(G,"bun",Vector3(0.50+j*0.22,y+0.025,-0.46+row*0.20),0.08,0.06,8)
 b.col(G,Vector3(0.35,0,-0.62),Vector3(1.35,1.75,-0.10))
func wall_details() -> void:
 # Worn landscape poster above the ingredient rack, below the overhead pipes.
 box("serve_dark",Vector3(0.275,1.955,-0.131),Vector3(1.325,2.687,-0.09))
 box("kit_morel_drivers",Vector3(0.30,1.98,-0.145),Vector3(1.30,2.662,-0.132))
 # Original portrait proportions; mounted beside the doorway, clear of the rack.
 var poster_height: float=0.82*1457.0/1079.0
 box("serve_dark",Vector3(1.415,1.225,-0.131),Vector3(2.285,1.275+poster_height,-0.09))
 box("kit_owner_poster",Vector3(1.44,1.25,-0.145),Vector3(2.26,1.25+poster_height,-0.132))
 d.pipe_x(G,"metal",0.12,5.70,2.85,-0.15,0.045)
 d.pipe_x(G,"paint_orange",0.12,5.70,2.74,-0.20,0.025)
 for x in [0.4,1.4,2.4,3.4,4.4,5.4]:box("metal",Vector3(x,2.68,-0.24),Vector3(x+0.07,2.91,-0.08))
 box("kit_recipe",Vector3(4.03,1.40,-0.112),Vector3(4.73,2.20,-0.093))
 # A real polygon clock with hands, rather than extra raster lettering.
 b.prism(G,"metal",Vector3(3.0,2.47,-0.115),0.18,0.03,12,Basis(Vector3.RIGHT,PI/2))
 b.prism(G,"chalk",Vector3(3.0,2.47,-0.12),0.16,0.008,12,Basis(Vector3.RIGHT,PI/2))
 for i in 12:
  var angle: float=TAU*float(i)/12.0
  var position: Vector3=Vector3(3.0+sin(angle)*0.135,2.47+cos(angle)*0.135,-0.129)
  d.rbox(G,"metal",d.T(position),Vector3.ZERO,Vector3(0.008,0.021 if i%3==0 else 0.012,0.006),d.rotz(-rad_to_deg(angle)))
 d.rbox(G,"metal",d.T(Vector3(3.0,2.47,-0.125)),Vector3(0,0.035,0),Vector3(0.013,0.09,0.008),d.rotz(40))
 d.rbox(G,"metal",d.T(Vector3(3.0,2.47,-0.13)),Vector3(0,0.055,0),Vector3(0.01,0.13,0.008),d.rotz(-55))
func jar(pos: Vector3, label: String) -> void:
 b.prism(G,"kit_steel",pos,0.105,0.24,10)
 b.prism(G,"kit_teal",pos+Vector3(0,0.24,0),0.11,0.04,10)
 # Only the front label carries the graphic.
 box(label,pos+Vector3(-0.084,0.025,0.101),pos+Vector3(0.084,0.215,0.105))
 # A second face makes south-facing rack labels readable as well.
 box(label,pos+Vector3(-0.084,0.025,-0.105),pos+Vector3(0.084,0.215,-0.101))
func bottle(pos: Vector3, orange: bool) -> void:
 b.prism(G,"paint_orange" if orange else "kit_teal",pos,0.035,0.19,8)
 b.prism(G,"chalk",pos+Vector3(0,0.19,0),0.016,0.055,6)
func mushroom(pos: Vector3, radius: float) -> void:
 b.prism(G,"kit_stalk",pos,radius*0.30,radius*0.85,6)
 b.prism(G,"kit_cap",pos+Vector3(0,radius*0.65,0),radius,radius*0.38,8)
func utensils() -> void:
 d.pipe_x(G,"metal",1.25,3.55,1.85,-4.62,0.018)
 for i in 6:
  var x: float=1.43+i*0.36
  box("paint_orange" if i%2==0 else "metal",Vector3(x-0.016,1.65,-4.62),Vector3(x+0.016,1.86,-4.59))
  if i==0:
   b.prism(G,"metal",Vector3(x,1.52,-4.61),0.13,0.03,12,Basis(Vector3.RIGHT,PI/2))
  else:
   box("kit_steel",Vector3(x-0.055,1.46,-4.62),Vector3(x+0.055,1.65,-4.59))
   if i%2==0:
    for j in 3:box("metal",Vector3(x-0.035+j*0.03,1.48,-4.586),Vector3(x-0.025+j*0.03,1.59,-4.581))

# Decorative sliced tomato: skin ring, flesh, four seed chambers and pale core.
func tomato(at: Vector3,yaw: float) -> void:
 b.prism(G,"kit_tomato_skin",at,0.095,0.014,16)
 b.prism(G,"kit_tomato_flesh",at+Vector3(0,0.014,0),0.087,0.001,16)
 b.prism(G,"kit_tomato_pith",at+Vector3(0,0.0155,0),0.018,0.001,8)
 for section in 4:
  var angle: float=yaw+section*PI/2.0
  var direction:=Vector3(cos(angle),0,sin(angle))
  var centre: Vector3=at+direction*0.047+Vector3(0,0.0155,0)
  b.prism(G,"kit_tomato_chamber",centre,0.029,0.001,3,Basis(Vector3.UP,-angle))
  var spoke: Vector3=at+Vector3(cos(angle+PI/4),0,sin(angle+PI/4))*0.040+Vector3(0,0.016,0)
  b.obox(G,"kit_tomato_pith",spoke,Vector3(0.065,0.001,0.007),Basis(Vector3.UP,-angle-PI/4),false)
  for seed in 2:
   var side:=Vector3(-direction.z,0,direction.x)*(0.009 if seed==0 else -0.009)
   b.prism(G,"kit_tomato_seed",centre+side+Vector3(0,0.0015,0),0.0045,0.001,5,Basis.IDENTITY.scaled(Vector3(0.75,1,1.4)))
