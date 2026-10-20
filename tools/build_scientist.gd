# Build the owner's scientist as a skinned infected with an independently detachable head.
extends SceneTree
const OUT: String="res://enemies/scientist/"
const CUT: float=.69
const BONES: Array=[
 ["root","",Vector3.ZERO,Vector3(0,.03,0)],
 ["hips","root",Vector3(0,.40,0),Vector3(0,.49,0)],
 ["spine","hips",Vector3(0,.49,0),Vector3(0,.58,0)],
 ["chest","spine",Vector3(0,.58,0),Vector3(0,.66,0)],
 ["neck","chest",Vector3(0,.66,0),Vector3(0,.69,0)],
 ["head","neck",Vector3(0,.69,0),Vector3(0,.97,0)],
 ["arm_r","chest",Vector3(-.13,.64,0),Vector3(-.22,.49,0)],
 ["forearm_r","arm_r",Vector3(-.22,.49,0),Vector3(-.27,.36,.015)],
 ["club_r","forearm_r",Vector3(-.27,.36,.015),Vector3(-.27,.31,.04)],
 ["arm_l","chest",Vector3(.13,.64,0),Vector3(.22,.49,0)],
 ["forearm_l","arm_l",Vector3(.22,.49,0),Vector3(.27,.36,.015)],
 ["hand_l","forearm_l",Vector3(.27,.36,.015),Vector3(.27,.31,.04)],
 ["thigh_r","hips",Vector3(-.09,.40,0),Vector3(-.105,.23,0)],
 ["shin_r","thigh_r",Vector3(-.105,.23,0),Vector3(-.12,.07,0)],
 ["foot_r","shin_r",Vector3(-.12,.07,0),Vector3(-.12,.02,.10)],
 ["thigh_l","hips",Vector3(.09,.40,0),Vector3(.105,.23,0)],
 ["shin_l","thigh_l",Vector3(.105,.23,0),Vector3(.12,.07,0)],
 ["foot_l","shin_l",Vector3(.12,.07,0),Vector3(.12,.02,.10)]
]
const Palette = preload("res://core/palette.gd")
var factor: float=1.0
func final(p: Vector3) -> Vector3:return Vector3(-p.x,p.y,-p.z)*factor
func own(node: Node,owner_node: Node) -> void:
 node.owner=owner_node
 for child: Node in node.get_children():own(child,owner_node)
func rotations(clip: Animation,bone: String,keys: Array) -> void:
 for track in range(clip.get_track_count()-1,-1,-1):
  if str(clip.track_get_path(track))=="Skeleton3D:"+bone:clip.remove_track(track)
 var track: int=clip.add_track(Animation.TYPE_ROTATION_3D)
 clip.track_set_path(track,"Skeleton3D:"+bone)
 for key: Array in keys:clip.rotation_track_insert_key(track,key[0],Quaternion.from_euler((key[1] as Vector3)*PI/180.0))
func weights(point: Vector3,family: int=-1) -> Array:
 var x: float=absf(point.x)
 if point.y>=.69:return [[5,1.0]]
 if point.y>.60 and point.y<.67 and x>.10 and x<.19:
  var shoulder: float=smoothstep(.11,.19,x)
  return [[6 if point.x<0 else 9,shoulder],[3,1.0-shoulder]]
 var candidates: Array=[]
 if point.y>.65 and x<.11:candidates=[4,5]
 elif point.y>.24 and point.y<.66 and x>(.17+(.62-point.y)*.23):candidates=[6,7,8] if point.x<0 else [9,10,11]
 elif point.y<.43:candidates=[12,13,14] if point.x<0 else [15,16,17]
 else:candidates=[1,2,3,4]
 if family>0:candidates=[[1,2,3,4],[6,7,8],[9,10,11],[12,13,14],[15,16,17]][family]
 var ranked: Array=[]
 for index: int in candidates:
  var a: Vector3=BONES[index][2]
  var b: Vector3=BONES[index][3]
  var near: Vector3=a+(b-a)*clampf((point-a).dot(b-a)/(b-a).length_squared(),0,1)
  ranked.append([index,point.distance_to(near)])
 ranked.sort_custom(func(a: Array,b: Array) -> bool:return a[1]<b[1])
 if ranked.size()==1:return [[ranked[0][0],1.0]]
 var first: float=1.0/pow(maxf(.015,ranked[0][1]),3)
 var second: float=1.0/pow(maxf(.015,ranked[1][1]),3)
 return [[ranked[0][0],first/(first+second)],[ranked[1][0],second/(first+second)]]
func families(vertices: PackedVector3Array,triangles: PackedInt32Array) -> Array:
 # UV seams must share a label; isolated mislabelled patches join their neighbours.
 var keys: Dictionary={}
 var weld: Array[int]=[]
 var positions: Array[Vector3]=[]
 for vertex: Vector3 in vertices:
  var key:=Vector3i(roundi(vertex.x*10000),roundi(vertex.y*10000),roundi(vertex.z*10000))
  if not keys.has(key):
   keys[key]=positions.size()
   positions.append(vertex)
  weld.append(keys[key])
 var adjacency: Array=[]
 var labels: Array[int]=[]
 for point: Vector3 in positions:
  adjacency.append({})
  var bone: int=weights(point)[0][0]
  labels.append(1 if bone in [6,7,8] else (2 if bone in [9,10,11] else (3 if bone in [12,13,14] else (4 if bone in [15,16,17] else 0))))
 for t in range(0,triangles.size(),3):
  for k in 3:
   var a: int=weld[triangles[t+k]]
   var b: int=weld[triangles[t+(k+1)%3]]
   adjacency[a][b]=true
   adjacency[b][a]=true
 for pass_index in 4:
  var visited: Dictionary={}
  var components: Array=[]
  var largest: Dictionary={}
  for i in positions.size():
   if visited.has(i):continue
   var component: Array[int]=[i]
   visited[i]=true
   var next: int=0
   while next<component.size():
    for neighbour: int in adjacency[component[next]]:
     if not visited.has(neighbour) and labels[neighbour]==labels[i]:
      visited[neighbour]=true
      component.append(neighbour)
    next+=1
   components.append(component)
   if not largest.has(labels[i]) or component.size()>components[largest[labels[i]]].size():largest[labels[i]]=components.size()-1
  for index in components.size():
   var component: Array=components[index]
   var family: int=labels[component[0]]
   if largest[family]==index:continue
   var votes: Dictionary={}
   for vertex: int in component:
    for neighbour: int in adjacency[vertex]:
     if labels[neighbour]!=family:votes[labels[neighbour]]=votes.get(labels[neighbour],0)+1
   var winner: int=family
   var count: int=0
   for choice: int in votes:
    if votes[choice]>count:winner=choice;count=votes[choice]
   for vertex: int in component:labels[vertex]=winner
 var result: Array=[]
 for index: int in weld:result.append(labels[index])
 return result
func cut_polygon(polygon: Array,above: bool) -> Array:
 var result: Array=[]
 var previous: Array=polygon[-1]
 var pd: float=((previous[0] as Vector3).y-CUT)*(1.0 if above else -1.0)
 for current: Array in polygon:
  var cd: float=((current[0] as Vector3).y-CUT)*(1.0 if above else -1.0)
  if (cd>=0)!=(pd>=0):
   var t: float=pd/(pd-cd)
   result.append([(previous[0] as Vector3).lerp(current[0],t),(previous[1] as Vector3).lerp(current[1],t).normalized(),(previous[2] as Vector2).lerp(current[2],t),previous[3] if t<.5 else current[3]])
  if cd>=0:result.append(current)
  previous=current
  pd=cd
 return result
func append_triangles(points: Array,polygon: Array) -> void:
 for i in range(1,polygon.size()-1):points.append_array([polygon[0],polygon[i],polygon[i+1]])
func make_arrays(points: Array,skinned: bool) -> Array:
 var v:=PackedVector3Array();var n:=PackedVector3Array();var uv:=PackedVector2Array()
 var bones:=PackedInt32Array();var skin_weights:=PackedFloat32Array();var triangles:=PackedInt32Array()
 for point: Array in points:
  v.append(final(point[0])-(Vector3.ZERO if skinned else final(BONES[5][2])))
  n.append(Vector3(-(point[1] as Vector3).x,(point[1] as Vector3).y,-(point[1] as Vector3).z))
  uv.append(point[2])
  triangles.append(triangles.size())
  if skinned:
   var blend: Array=weights(point[0],point[3])
   for k in 4:
    bones.append(blend[k][0] if k<blend.size() else 0)
    skin_weights.append(blend[k][1] if k<blend.size() else 0.0)
 var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=v;arrays[Mesh.ARRAY_NORMAL]=n;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=triangles
 if skinned:
  var smoothed: Array=smooth_skin(v,triangles,bones,skin_weights)
  arrays[Mesh.ARRAY_BONES]=smoothed[0];arrays[Mesh.ARRAY_WEIGHTS]=smoothed[1]
 return arrays
# Smooth across welded topology, never across gaps between the coat and hands.
func smooth_skin(vertices: PackedVector3Array,faces: PackedInt32Array,bones: PackedInt32Array,weights_in: PackedFloat32Array) -> Array:
 var map: Dictionary={};var weld: Array[int]=[];var values: Array=[];var adjacency: Array=[]
 for i in vertices.size():
  var key: Vector3=vertices[i].snapped(Vector3.ONE*.00001)
  if not map.has(key):
   map[key]=values.size()
   var influence:=PackedFloat32Array();influence.resize(BONES.size())
   for k in 4:influence[bones[i*4+k]]+=weights_in[i*4+k]
   values.append(influence);adjacency.append({})
  weld.append(map[key])
 for tri in range(0,faces.size(),3):
  for k in 3:
   var x: int=weld[faces[tri+k]];var y: int=weld[faces[tri+(k+1)%3]]
   if x!=y:adjacency[x][y]=true;adjacency[y][x]=true
 for pass_index in 30:
  var next: Array=[]
  for i in values.size():
   var influence: PackedFloat32Array=values[i].duplicate()
   for bone in BONES.size():
    var mean: float=0
    for neighbour: int in adjacency[i]:mean+=values[neighbour][bone]
    if not adjacency[i].is_empty():influence[bone]=influence[bone]*.45+mean/adjacency[i].size()*.55
   next.append(influence)
  values=next
 var result_bones:=PackedInt32Array();var result_weights:=PackedFloat32Array()
 for i in vertices.size():
  var influence: PackedFloat32Array=values[weld[i]]
  var ranked: Array=[]
  for bone in BONES.size():ranked.append([bone,influence[bone]])
  ranked.sort_custom(func(x: Array,y: Array)->bool:return x[1]>y[1])
  var total: float=0
  for k in 4:total+=ranked[k][1]
  for k in 4:result_bones.append(ranked[k][0]);result_weights.append(ranked[k][1]/total)
 return [result_bones,result_weights]
# Bake contact correction into clips, with no per-enemy vertex work at runtime.
func ground_clips(player: AnimationPlayer,skeleton: Skeleton3D,mesh: ArrayMesh) -> void:
 var arrays: Array=mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var influences: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var unique: Dictionary={};var samples: Array[int]=[]
 for i in vertices.size():
  var key: Vector3=vertices[i].snapped(Vector3.ONE*.00001)
  if not unique.has(key):unique[key]=true;samples.append(i)
 for name: StringName in player.get_animation_list():
  if name=="climb":continue
  var clip: Animation=player.get_animation(name)
  var times: Array=[];var positions: Array=[]
  var count: int=ceili(clip.length*15)
  skeleton.reset_bone_poses()
  player.play(name,0)
  for frame in count+1:
   var time: float=clip.length*frame/maxi(count,1)
   player.seek(time,true);skeleton.force_update_all_bone_transforms()
   var transforms: Array=[]
   for bone in skeleton.get_bone_count():transforms.append(skeleton.get_bone_global_pose(bone)*skeleton.get_bone_global_rest(bone).affine_inverse())
   var low: float=INF
   for i: int in samples:
    if name!="death" and vertices[i].y>.20:continue
    var point:=Vector3.ZERO
    for k in 4:point+=(transforms[bones[i*4+k]]*vertices[i])*influences[i*4+k]
    low=minf(low,point.y)
   times.append(time);positions.append(skeleton.get_bone_pose_position(0)+Vector3.UP*(.005-low))
  var track: int=clip.find_track(NodePath("Skeleton3D:root"),Animation.TYPE_POSITION_3D)
  if track>=0:clip.remove_track(track)
  track=clip.add_track(Animation.TYPE_POSITION_3D)
  clip.track_set_path(track,"Skeleton3D:root")
  for i in times.size():clip.position_track_insert_key(track,times[i],positions[i])
 player.stop();skeleton.reset_bone_poses()
func save_mesh(mesh: ArrayMesh,path: String) -> void:
 assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
 mesh.take_over_path(path)
func _initialize() -> void:
 var doc:=GLTFDocument.new();var state:=GLTFState.new()
 assert(doc.append_from_file(ProjectSettings.globalize_path(OUT+"source/scientist.glb"),state)==OK)
 var input: ImporterMesh=(state.get_meshes()[0] as GLTFMesh).mesh
 var arrays: Array=input.get_surface_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var triangles: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var top: float=0
 for vertex: Vector3 in vertices:top=maxf(top,vertex.y)
 factor=1.85/top
 var labels: Array=families(vertices,triangles)
 var body_points: Array=[];var head_points: Array=[]
 for tri in range(0,triangles.size(),3):
  var polygon: Array=[]
  for k in 3:
   var at: int=triangles[tri+k]
   polygon.append([vertices[at],normals[at],uv[at],labels[at]])
  append_triangles(body_points,cut_polygon(polygon,false))
  append_triangles(head_points,cut_polygon(polygon,true))
 var skeleton:=Skeleton3D.new();skeleton.name="Skeleton3D"
 for bone: Array in BONES:
  var index: int=skeleton.get_bone_count();skeleton.add_bone(bone[0])
  var parent: int=skeleton.find_bone(bone[1])
  if parent>=0:skeleton.set_bone_parent(index,parent)
  skeleton.set_bone_rest(index,Transform3D(Basis.IDENTITY,final(bone[2])-(final(BONES[parent][2]) if parent>=0 else Vector3.ZERO)))
 skeleton.reset_bone_poses()
 var image: Image=(input.get_surface_material(0) as StandardMaterial3D).albedo_texture.get_image()
 image.decompress();image.resize(1024,1024,Image.INTERPOLATE_LANCZOS);image.generate_mipmaps()
 var material:=StandardMaterial3D.new();material.albedo_texture=ImageTexture.create_from_image(image)
 material.roughness=.95;material.metallic_specular=.15;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS;material.cull_mode=BaseMaterial3D.CULL_DISABLED
 assert(ResourceSaver.save(material,OUT+"scientist_material.res",ResourceSaver.FLAG_COMPRESS)==OK)
 material.take_over_path(OUT+"scientist_material.res")
 var importer:=ImporterMesh.new();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,make_arrays(body_points,true),[],{},material)
 var transforms: Array=[]
 for i in skeleton.get_bone_count():transforms.append(skeleton.get_bone_global_rest(i))
 importer.generate_lods(25,60,transforms)
 var body:=MeshInstance3D.new();body.name="Body";body.mesh=importer.get_mesh()
 save_mesh(body.mesh,OUT+"scientist_body.res")
 skeleton.add_child(body);body.skin=skeleton.create_skin_from_rest_transforms();body.skeleton=NodePath("..")
 var head_mesh:=ArrayMesh.new();head_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,make_arrays(head_points,false));head_mesh.surface_set_material(0,material)
 var stump:=StandardMaterial3D.new();stump.albedo_color=Palette.WARM_CHALK;stump.roughness=1.0
 # Cap the detached stem; the remaining neck has a matching closed stump.
 var cap_v:=PackedVector3Array();var cap_n:=PackedVector3Array()
 for k in 16:
  var a: float=TAU*k/16;var b: float=TAU*(k+1)/16
  for v: Vector3 in [Vector3.ZERO,Vector3(cos(a),0,sin(a))*.026*factor,Vector3(cos(b),0,sin(b))*.026*factor]:cap_v.append(v);cap_n.append(Vector3.DOWN)
 var cap_a: Array=[];cap_a.resize(Mesh.ARRAY_MAX);cap_a[Mesh.ARRAY_VERTEX]=cap_v;cap_a[Mesh.ARRAY_NORMAL]=cap_n
 head_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cap_a);head_mesh.surface_set_material(1,stump)
 save_mesh(head_mesh,OUT+"scientist_head.res")
 var attach:=BoneAttachment3D.new();attach.name="DetachableHead";attach.bone_name="head";skeleton.add_child(attach)
 var head:=MeshInstance3D.new();head.name="Head";head.mesh=head_mesh;attach.add_child(head)
 var neck:=BoneAttachment3D.new();neck.name="NeckStump";neck.bone_name="neck";skeleton.add_child(neck)
 var cap:=MeshInstance3D.new();cap.name="ClosedStem"
 var cylinder:=CylinderMesh.new();cylinder.top_radius=.026*factor;cylinder.bottom_radius=.026*factor;cylinder.height=.008;cylinder.radial_segments=12;cylinder.material=stump
 cap.mesh=cylinder;cap.position.y=(CUT-.66)*factor-.004;neck.add_child(cap)
 var original: Node3D=load("res://enemies/shambler/shambler_model.tscn").instantiate()
 var original_skeleton: Skeleton3D=original.get_node("Skeleton3D")
 var library: AnimationLibrary=(original.get_node("AnimationPlayer") as AnimationPlayer).get_animation_library("").duplicate(true)
 for name: StringName in library.get_animation_list():
  var clip: Animation=library.get_animation(name)
  for track in clip.get_track_count():
   if clip.track_get_type(track)!=Animation.TYPE_POSITION_3D:continue
   var bone_name: String=clip.track_get_path(track).get_subname(0)
   var old_index: int=original_skeleton.find_bone(bone_name);var new_index: int=skeleton.find_bone(bone_name)
   for key in clip.track_get_key_count(track):
    var value: Vector3=clip.track_get_key_value(track,key)
    clip.track_set_key_value(track,key,value-original_skeleton.get_bone_rest(old_index).origin+skeleton.get_bone_rest(new_index).origin)
 # Open-handed strike instead of the original Shambler's heavy club sweep.
 var swing: Animation=library.get_animation("swing")
 rotations(swing,"arm_r",[[0.0,Vector3(15,0,0)],[.32,Vector3(75,-15,-15)],[.5,Vector3(95,-25,-10)],[.62,Vector3(45,25,10)],[1.2,Vector3(15,0,0)]])
 rotations(swing,"forearm_r",[[0.0,Vector3(15,0,0)],[.4,Vector3(65,0,0)],[.62,Vector3(10,0,0)],[1.2,Vector3(15,0,0)]])
 original.free()
 var model:=Node3D.new();model.name="ScientistModel";model.add_child(skeleton)
 var player:=AnimationPlayer.new();player.name="AnimationPlayer";player.add_animation_library("",library);player.autoplay="idle";player.playback_default_blend_time=.15;model.add_child(player)
 root.add_child(model)
 ground_clips(player,skeleton,body.mesh)
 for child: Node in model.get_children():own(child,model)
 var packed:=PackedScene.new();assert(packed.pack(model)==OK);assert(ResourceSaver.save(packed,OUT+"scientist_model.tscn")==OK)
 print("Scientist built: ",body_points.size()/3," body triangles, ",head_points.size()/3," head triangles; ",library.get_animation_list())
 model.free();quit()
