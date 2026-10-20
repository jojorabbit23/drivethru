# Deterministic, collision-free scenery. Run headlessly; no purchased/generated art needed.
extends SceneTree
const P=preload("res://core/palette.gd")
const OUT="res://levels/exterior/generated/surroundings.tscn"
var rng:=RandomNumberGenerator.new()
var scene: Node3D
var vertices:=PackedVector3Array()
var normals:=PackedVector3Array()
var colours:=PackedColorArray()
var material: StandardMaterial3D
var placements: Dictionary={}
func _initialize() -> void:
 rng.seed=20261020
 material=StandardMaterial3D.new()
 material.vertex_color_use_as_albedo=true
 material.vertex_color_is_srgb=true
 material.roughness=1.0
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 scene=Node3D.new()
 scene.name="ExteriorSurroundings"
 scene.set_meta("visual_only",true)
 build()
 own(scene)
 var packed:=PackedScene.new()
 assert(packed.pack(scene)==OK)
 assert(ResourceSaver.save(packed,OUT)==OK)
 print("Exterior saved; batches=",scene.get_child_count()," placements=",placements)
 scene.free()
 quit()
func own(n: Node) -> void:
 for child in n.get_children():child.owner=scene;own(child)
func tri(a: Vector3,b: Vector3,c: Vector3,colour: Color) -> void:
 var normal: Vector3=(c-a).cross(b-a).normalized()
 for point in [a,b,c]:vertices.append(point);normals.append(normal);colours.append(colour)
func append(mesh: Mesh,at: Vector3,size: Vector3,colour: Color,yaw: float=0.0) -> void:
 var arrays: Array=mesh.surface_get_arrays(0)
 var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var transform:=Transform3D(Basis(Vector3.UP,yaw).scaled(size),at)
 if indices.is_empty():
  for i in range(0,points.size(),3):tri(transform*points[i],transform*points[i+1],transform*points[i+2],colour)
 else:
  for i in range(0,indices.size(),3):tri(transform*points[indices[i]],transform*points[indices[i+1]],transform*points[indices[i+2]],colour)
func box(at: Vector3,size: Vector3,colour: Color,yaw: float=0.0) -> void:
 append(BoxMesh.new(),at,size,colour,yaw)
func cylinder(at: Vector3,top: float,bottom: float,height: float,colour: Color,sides: int=6) -> void:
 var mesh:=CylinderMesh.new()
 mesh.top_radius=top;mesh.bottom_radius=bottom;mesh.height=height;mesh.radial_segments=sides;mesh.rings=1
 append(mesh,at,Vector3.ONE,colour)
func finish() -> ArrayMesh:
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colours
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,material)
 vertices=PackedVector3Array();normals=PackedVector3Array();colours=PackedColorArray()
 return mesh
func node_mesh(name: String,mesh: Mesh) -> void:
 var node:=MeshInstance3D.new();node.name=name;node.mesh=mesh
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 scene.add_child(node)
func batch(name: String,mesh: Mesh,transforms: Array) -> void:
 # Bake repeated shared prop meshes into one surface. Unlike server-backed
 # MultiMesh buffers, these arrays also serialize reliably in a headless build.
 var arrays: Array=mesh.surface_get_arrays(0)
 var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var source_colours: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
 var positions:=PackedVector3Array()
 for transform: Transform3D in transforms:
  positions.append(transform.origin)
  var tint: Color=Color.WHITE.lerp(P.BLUE_SLATE,rng.randf_range(0,.12))
  for i in range(0,points.size(),3):
   tri(transform*points[i],transform*points[i+1],transform*points[i+2],source_colours[i]*tint)
 node_mesh(name,finish())
 var node: Node3D=scene.get_child(scene.get_child_count()-1)
 node.set_meta("placements",positions)
 placements[name]=positions.size()
func pose(at: Vector3,size: Vector3,yaw: float) -> Transform3D:
 return Transform3D(Basis(Vector3.UP,yaw).scaled(size),at)
func clear_routes(p: Vector3,radius: float=2.0) -> bool:
 # Preserve the entire site, all approach lanes, garage and delivery apron.
 if absf(p.x)<20.0+radius and p.z>-16.0-radius and p.z<20.0+radius:return false
 # Both customer travel directions, including offscreen approach/departure.
 if absf(p.z+8.0)<5.0+radius:return false
 # Petrol station forecourt and sheds remain readable.
 if p.distance_to(Vector3(16,0,-29))<13.0+radius:return false
 if p.distance_to(Vector3(-31,0,0))<10.0+radius:return false
 return true
func build() -> void:
 # Shared low-poly pine: three overlapping tapered crowns and a bare trunk.
 cylinder(Vector3(0,1.6,0),.16,.24,3.2,P.BURNT_ORANGE)
 cylinder(Vector3(0,2.8,0),0,1.65,3.0,P.BLUE_SLATE)
 cylinder(Vector3(0,4.3,0),0,1.25,2.8,P.BLUE_SLATE.lerp(P.OXIDISED_TEAL,.18))
 cylinder(Vector3(0,5.6,0),0,.8,2.7,P.MIDNIGHT_TYNE.lerp(P.OXIDISED_TEAL,.25))
 var pine: Mesh=finish()
 var rock_primitive:=SphereMesh.new();rock_primitive.radial_segments=7;rock_primitive.rings=3;rock_primitive.radius=1;rock_primitive.height=2
 append(rock_primitive,Vector3(0,.55,0),Vector3(1.25,.9,1),P.BLUE_SLATE.lerp(P.CONCRETE_GREY,.22))
 var rock: Mesh=finish()
 cylinder(Vector3(0,.26,0),.08,.11,.52,P.WARM_CHALK)
 cylinder(Vector3(0,.58,0),.05,.48,.24,P.BURNT_ORANGE,7)
 cylinder(Vector3(0,.72,0),0,.32,.16,P.AMBER_GLOW,7)
 var mushroom: Mesh=finish()
 # Weathered car silhouette: crushed hood, cabin, dark windows, exposed tyres.
 box(Vector3(0,.56,0),Vector3(1.65,.5,3.5),P.BURNT_ORANGE)
 box(Vector3(0,1.02,.25),Vector3(1.5,.58,1.65),P.BLUE_SLATE)
 box(Vector3(0,1.36,.22),Vector3(1.54,.1,1.8),P.BURNT_ORANGE)
 box(Vector3(0,.79,-1.26),Vector3(1.65,.12,1),P.BURNT_ORANGE.lerp(P.WET_CHARCOAL,.4),.07)
 for x in [-.87,.87]:
  for z in [-1.02,1.02]:
   box(Vector3(x,.33,z),Vector3(.24,.58,.6),P.WET_CHARCOAL)
   box(Vector3(x*1.02,.33,z),Vector3(.25,.22,.24),P.CONCRETE_GREY)
 box(Vector3(0,.5,-1.8),Vector3(1.7,.15,.12),P.CONCRETE_GREY)
 box(Vector3(0,.62,-1.87),Vector3(.8,.15,.03),P.WET_CHARCOAL)
 for x in [-.58,.58]:box(Vector3(x,.68,-1.77),Vector3(.3,.16,.05),P.WARM_CHALK.lerp(P.WET_CHARCOAL,.4))
 var wreck: Mesh=finish()
 var trees: Array=[];var rocks: Array=[];var shrooms: Array=[]
 for i in 390:
  var p:=Vector3(rng.randf_range(-115,115),-.03,rng.randf_range(-110,115))
  if not clear_routes(p,2.5):continue
  var scale: float=rng.randf_range(.65,1.6)
  trees.append(pose(p,Vector3.ONE*scale,rng.randf()*TAU))
 for i in 85:
  var p:=Vector3(rng.randf_range(-90,90),-.1,rng.randf_range(-85,90))
  if not clear_routes(p,3.0):continue
  rocks.append(pose(p,Vector3(rng.randf_range(1.5,3.6),rng.randf_range(1.2,2.7),rng.randf_range(1.3,3)),rng.randf()*TAU))
 for centre: Vector3 in [Vector3(23,0,7),Vector3(-24,0,16),Vector3(24,0,-20),Vector3(-28,0,-19),Vector3(-12,0,26),Vector3(14,0,29),Vector3(36,0,3)]:
  for i in 7:
   var p: Vector3=centre+Vector3(rng.randf_range(-2.5,2.5),0,rng.randf_range(-2.5,2.5))
   if clear_routes(p,.5):shrooms.append(pose(p,Vector3.ONE*rng.randf_range(.45,1.2),rng.randf()*TAU))
 batch("NearbyPines",pine,trees);batch("ChunkyRocks",rock,rocks);batch("MushroomClusters",mushroom,shrooms)
 var cars: Array=[]
 for item: Array in [[Vector3(-24,0,20),.7],[Vector3(27,0,18),-1.0],[Vector3(-38,0,-20),.3],[Vector3(23,0,-28),-.6],[Vector3(-30,0,8),1.2]]:
  cars.append(pose(item[0],Vector3.ONE,float(item[1])))
 batch("WreckedCars",wreck,cars)
 terrain()
 landmarks()
 backdrop()
func terrain() -> void:
 box(Vector3(0,-.38,0),Vector3(390,.2,390),Color.WHITE)
 # Modest distant slopes: texture continuity hides the original site's square edge.
 for i in 64:
  var a: float=TAU*i/64;var b: float=TAU*(i+1)/64
  var inner_a:=Vector3(cos(a)*48,-.08,sin(a)*48)
  var inner_b:=Vector3(cos(b)*48,-.08,sin(b)*48)
  var outer_a:=Vector3(cos(a)*160,2+sin(a*5)*1.8,sin(a)*160)
  var outer_b:=Vector3(cos(b)*160,2+sin(b*5)*1.8,sin(b)*160)
  if absf(sin(a))<.16:outer_a.y=-.1
  if absf(sin(b))<.16:outer_b.y=-.1
  tri(inner_a,outer_a,outer_b,Color.WHITE);tri(inner_a,outer_b,inner_b,Color.WHITE)
 var terrain_mesh: ArrayMesh=finish()
 var ground: StandardMaterial3D=load("res://materials/ground.tres").duplicate()
 ground.uv1_triplanar=true;ground.uv1_world_triplanar=true;ground.uv1_scale=Vector3(.5,.5,.5)
 terrain_mesh.surface_set_material(0,ground)
 node_mesh("TexturedTerrainSkirt",terrain_mesh)
 for side in [-1.0,1.0]:
  box(Vector3(side*95,-.04,-8),Vector3(110,.08,4),P.WET_CHARCOAL)
  for i in 35:box(Vector3(side*(41+i*3),.009,-8),Vector3(1.4,.01,.1),P.WARM_CHALK.lerp(P.WET_CHARCOAL,.3))
 node_mesh("RoadExtension",finish())
func landmarks() -> void:
 # Across-road petrol forecourt, all merged into a single decorative mesh.
 box(Vector3(16,0,-29),Vector3(23,.12,15),P.CONCRETE_GREY.lerp(P.BLUE_SLATE,.5))
 box(Vector3(15,4.6,-26),Vector3(16,.55,6),P.BURNT_ORANGE)
 box(Vector3(15,4.26,-26),Vector3(15.7,.13,5.8),P.WARM_CHALK)
 for x in [9.0,21.0]:
  box(Vector3(x,2.1,-26),Vector3(.3,4.2,.3),P.WARM_CHALK)
  box(Vector3(x,.7,-26),Vector3(1.8,1.4,.8),P.OXIDISED_TEAL)
  box(Vector3(x,1.05,-25.57),Vector3(1.3,.5,.03),P.MIDNIGHT_TYNE)
  box(Vector3(x,1.05,-25.54),Vector3(.65,.16,.02),P.ELECTRIC_TEAL)
  box(Vector3(x,.2,-26),Vector3(2.3,.3,1.8),P.WARM_CHALK)
 box(Vector3(23,1.65,-33),Vector3(7,3.3,4.5),P.CONCRETE_GREY)
 box(Vector3(23,3.4,-33),Vector3(7.4,.22,4.9),P.BURNT_ORANGE)
 box(Vector3(21.6,1.4,-30.72),Vector3(1.3,2.7,.06),P.OXIDISED_TEAL)
 box(Vector3(24.2,1.8,-30.7),Vector3(2.3,1.2,.06),P.MIDNIGHT_TYNE)
 for x in [10,12,14,16,18,20]:box(Vector3(x,4.62,-22.96),Vector3(.12,.25,.03),P.WARM_CHALK)
 # Weathered utility sheds to the west; corrugated ribs reuse boxes.
 for offset: Vector3 in [Vector3(-32,0,0),Vector3(-39,0,2)]:
  box(offset+Vector3(0,2,0),Vector3(6,4,6),P.BLUE_SLATE)
  box(offset+Vector3(0,4.1,0),Vector3(6.6,.2,6.6),P.CONCRETE_GREY)
  box(offset+Vector3(0,1.5,3.03),Vector3(3,3,.06),P.BURNT_ORANGE)
  for i in 12:box(offset+Vector3(-2.8+i*.5,2,3.08),Vector3(.055,3.9,.05),P.CONCRETE_GREY.lerp(P.BLUE_SLATE,.7))
 # Water tower, thin supports and cross-bracing, no simulation or lights.
 var c:=Vector3(-28,0,-48)
 for x in [-1.7,1.7]:
  for z in [-1.7,1.7]:box(c+Vector3(x,5,z),Vector3(.22,10,.22),P.BURNT_ORANGE.lerp(P.WET_CHARCOAL,.3))
 for y in [2.5,6.5,9.8]:box(c+Vector3(0,y,0),Vector3(3.8,.16,3.8),P.WET_CHARCOAL)
 for x in [-1.7,1.7]:
  beam(c+Vector3(x,1,-1.7),c+Vector3(x,9,1.7),.13,P.BURNT_ORANGE)
  beam(c+Vector3(x,1,1.7),c+Vector3(x,9,-1.7),.13,P.BURNT_ORANGE)
 cylinder(c+Vector3(0,11.3,0),2.25,2.25,3.2,P.CONCRETE_GREY,8)
 cylinder(c+Vector3(0,13.25,0),0,2.6,.9,P.BLUE_SLATE,8)
 box(c+Vector3(0,11.4,2.27),Vector3(1.1,1.6,.03),P.BURNT_ORANGE)
 # Roadside power poles read at distance without simulated cable physics.
 for x in [-56.0,-30.0,40.0,66.0]:
  cylinder(Vector3(x,3.7,-14.5),.13,.18,7.4,P.BURNT_ORANGE)
  box(Vector3(x,6.5,-14.5),Vector3(.18,.18,2.6),P.WET_CHARCOAL)
 for x in [-56.0,-30.0,40.0]:
  for z in [-15.5,-13.5]:beam(Vector3(x,6.6,z),Vector3(x+26,6.6,z),.035,P.WET_CHARCOAL)
 node_mesh("PetrolStationShedsWaterTower",finish())
 var sign:=Label3D.new()
 sign.name="FuelSign";sign.text="FUEL";sign.font_size=64;sign.pixel_size=.022
 sign.position=Vector3(15,4.6,-22.69)
 sign.modulate=P.WARM_CHALK;sign.outline_size=0
 sign.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 sign.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 scene.get_node("PetrolStationShedsWaterTower").add_child(sign)
func beam(a: Vector3,b: Vector3,width: float,colour: Color) -> void:
 var mesh:=BoxMesh.new();mesh.size=Vector3(width,a.distance_to(b),width)
 var basis: Basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
 var arrays: Array=mesh.surface_get_arrays(0)
 var v: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 for i in range(0,ids.size(),3):tri(basis*v[ids[i]]+(a+b)*.5,basis*v[ids[i+1]]+(a+b)*.5,basis*v[ids[i+2]]+(a+b)*.5,colour)
func backdrop() -> void:
 # Flat vertical cards in three rings; no textures, alpha overdraw, collision or shadows.
 for layer in 3:
  var radius: float=125.0+layer*32.0
  var colour: Color=P.BLUE_SLATE.lerp(P.CONCRETE_GREY,.12+layer*.15)
  for i in 360:
   var angle: float=TAU*i/360+rng.randf_range(-.004,.004)
   var side:=Vector3(-sin(angle),0,cos(angle))
   var c:=Vector3(cos(angle)*radius,0,sin(angle)*radius)
   var height: float=rng.randf_range(8,16)+layer*2
   var width: float=rng.randf_range(1.2,2.5)
   for tier in 3:
    var y: float=height*float(tier)*.22
    var w: float=width*(1.0-float(tier)*.25)
    tri(c+Vector3(0,y-2,0)-side*w,c+Vector3(0,y+height*.65,0),c+Vector3(0,y-2,0)+side*w,colour)
  var heights:=PackedFloat32Array()
  for i in 49:heights.append(34+layer*12+sin(float(i)*.7)*13+sin(float(i)*1.9)*8)
  heights[48]=heights[0]
  for i in 48:
   var a: float=TAU*i/48;var b: float=TAU*(i+1)/48
   var r: float=280+layer*32
   var va:=Vector3(cos(a)*r,-3,sin(a)*r);var vb:=Vector3(cos(b)*r,-3,sin(b)*r)
   var top_a:=Vector3(va.x,heights[i],va.z);var top_b:=Vector3(vb.x,heights[i+1],vb.z)
   var ridge_colour: Color=colour.lerp(P.CONCRETE_GREY,.15)
   tri(va,top_a,top_b,ridge_colour);tri(va,top_b,vb,ridge_colour)
 var backdrop_mesh: ArrayMesh=finish()
 var flat: StandardMaterial3D=material.duplicate()
 flat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 backdrop_mesh.surface_set_material(0,flat)
 node_mesh("FlatForestAndMountainBackdrops",backdrop_mesh)
