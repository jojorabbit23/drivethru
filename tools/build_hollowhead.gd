# Skin the owner's static mesh and retarget the existing authored infected clips.
extends SceneTree
const OUT: String="res://enemies/hollowhead/"
const BONES: Array=[
	["root","",Vector3.ZERO,Vector3(0,0.03,0)],
	["hips","root",Vector3(0,.43,0),Vector3(0,.50,0)],
	["spine","hips",Vector3(0,.50,0),Vector3(0,.58,0)],
	["chest","spine",Vector3(0,.58,0),Vector3(0,.70,0)],
	["neck","chest",Vector3(0,.72,0),Vector3(0,.78,0)],
	["head","neck",Vector3(0,.78,0),Vector3(0,.97,0)],
	["arm_r","chest",Vector3(-.12,.69,0),Vector3(-.22,.55,0)],
	["forearm_r","arm_r",Vector3(-.22,.55,0),Vector3(-.26,.41,0)],
	["club_r","forearm_r",Vector3(-.26,.41,0),Vector3(-.26,.33,.02)],
	["arm_l","chest",Vector3(.12,.69,0),Vector3(.22,.55,0)],
	["forearm_l","arm_l",Vector3(.22,.55,0),Vector3(.26,.41,0)],
	["hand_l","forearm_l",Vector3(.26,.41,0),Vector3(.26,.33,.02)],
	["thigh_r","hips",Vector3(-.09,.43,0),Vector3(-.12,.24,0)],
	["shin_r","thigh_r",Vector3(-.12,.24,0),Vector3(-.13,.07,0)],
	["foot_r","shin_r",Vector3(-.13,.07,0),Vector3(-.13,.02,.10)],
	["thigh_l","hips",Vector3(.09,.43,0),Vector3(.12,.24,0)],
	["shin_l","thigh_l",Vector3(.12,.24,0),Vector3(.13,.07,0)],
	["foot_l","shin_l",Vector3(.13,.07,0),Vector3(.13,.02,.10)]
]
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
	if point.y>.64 and point.y<.72 and absf(point.x)>.09 and absf(point.x)<.19:
		var shoulder: float=smoothstep(.11,.18,absf(point.x))
		return [[6 if point.x<0 else 9,shoulder],[3,1.0-shoulder]]
	var candidates: Array=[]
	if point.y>.77:candidates=[5]
	elif point.y>.71 and absf(point.x)<.11:candidates=[4,5]
	elif absf(point.x)>.16 and point.y>.20 and point.y<.65:candidates=[6,7,8] if point.x<0 else [9,10,11]
	elif point.y<.43:candidates=[12,13,14] if point.x<0 else [15,16,17]
	elif absf(point.x)>.14 and point.y<.72:candidates=[6,7,8] if point.x<0 else [9,10,11]
	else:candidates=[1,2,3,4]
	if family>=0:candidates=[[1,2,3,4,5],[6,7,8],[9,10,11],[12,13,14],[15,16,17]][family]
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
func _initialize() -> void:
	var doc:=GLTFDocument.new()
	var state:=GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path(OUT+"source/hollowhead.glb"),state)==OK)
	var input: ImporterMesh=(state.get_meshes()[0] as GLTFMesh).mesh
	var arrays: Array=input.get_surface_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var top: float=0
	for vertex: Vector3 in vertices:top=maxf(top,vertex.y)
	factor=1.80/top
	var indices:=PackedInt32Array()
	var influences:=PackedFloat32Array()
	var labels: Array=families(vertices,arrays[Mesh.ARRAY_INDEX])
	for i in vertices.size():
		var blend: Array=weights(vertices[i],labels[i] if labels[i]>0 else -1)
		for j in 4:
			indices.append(blend[j][0] if j<blend.size() else 0)
			influences.append(blend[j][1] if j<blend.size() else 0.0)
		vertices[i]=final(vertices[i])
		normals[i]=Vector3(-normals[i].x,normals[i].y,-normals[i].z)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_BONES]=indices
	arrays[Mesh.ARRAY_WEIGHTS]=influences
	var skeleton:=Skeleton3D.new()
	skeleton.name="Skeleton3D"
	for bone: Array in BONES:
		var index: int=skeleton.get_bone_count()
		skeleton.add_bone(bone[0])
		var parent: int=skeleton.find_bone(bone[1])
		if parent>=0:skeleton.set_bone_parent(index,parent)
		var origin: Vector3=final(bone[2])-(final(BONES[parent][2]) if parent>=0 else Vector3.ZERO)
		skeleton.set_bone_rest(index,Transform3D(Basis.IDENTITY,origin))
	skeleton.reset_bone_poses()
	var image: Image=(input.get_surface_material(0) as StandardMaterial3D).albedo_texture.get_image()
	image.decompress()
	image.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var material:=StandardMaterial3D.new()
	material.albedo_texture=ImageTexture.create_from_image(image)
	material.roughness=.95
	material.metallic_specular=.15
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var importer:=ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},material)
	var transforms: Array=[]
	for i in skeleton.get_bone_count():transforms.append(skeleton.get_bone_global_rest(i))
	importer.generate_lods(25,60,transforms)
	var body:=MeshInstance3D.new()
	body.name="Body"
	body.mesh=importer.get_mesh()
	assert(ResourceSaver.save(body.mesh,OUT+"hollowhead_mesh.res",ResourceSaver.FLAG_COMPRESS)==OK)
	body.mesh.take_over_path(OUT+"hollowhead_mesh.res")
	skeleton.add_child(body)
	body.skin=skeleton.create_skin_from_rest_transforms()
	body.skeleton=NodePath("..")
	var original: Node3D=load("res://enemies/shambler/shambler_model.tscn").instantiate()
	var original_skeleton: Skeleton3D=original.get_node("Skeleton3D")
	var original_player: AnimationPlayer=original.get_node("AnimationPlayer")
	var library: AnimationLibrary=original_player.get_animation_library("").duplicate(true)
	for name: StringName in library.get_animation_list():
		var clip: Animation=library.get_animation(name)
		for track in clip.get_track_count():
			if clip.track_get_type(track)!=Animation.TYPE_POSITION_3D:continue
			var bone_name: String=clip.track_get_path(track).get_subname(0)
			var old_index: int=original_skeleton.find_bone(bone_name)
			var new_index: int=skeleton.find_bone(bone_name)
			for key in clip.track_get_key_count(track):
				var value: Vector3=clip.track_get_key_value(track,key)
				clip.track_set_key_value(track,key,value-original_skeleton.get_bone_rest(old_index).origin+skeleton.get_bone_rest(new_index).origin)
	var left: Animation=library.get_animation("swing").duplicate(true)
	for track in left.get_track_count():
		var path: String=str(left.track_get_path(track))
		path=path.replace("club_r","TEMP_HAND").replace("hand_l","club_r").replace("TEMP_HAND","hand_l")
		path=path.replace("_r","TEMP_SIDE").replace("_l","_r").replace("TEMP_SIDE","_l")
		# club/hand names already mirrored; repair them after the generic side swap.
		path=path.replace("club_l","club_r").replace("hand_r","hand_l")
		left.track_set_path(track,NodePath(path))
		if left.track_get_type(track)==Animation.TYPE_ROTATION_3D:
			for key in left.track_get_key_count(track):
				var q: Quaternion=left.track_get_key_value(track,key)
				left.track_set_key_value(track,key,Quaternion(q.x,-q.y,-q.z,q.w))
	library.add_animation("swing_left",left)
	var slam: Animation=library.get_animation("swing").duplicate(true)
	for bone_name: String in ["arm_l","forearm_l","hand_l"]:
		for track in range(slam.get_track_count()-1,-1,-1):
			if str(slam.track_get_path(track)).ends_with(":"+bone_name):slam.remove_track(track)
	for track in left.get_track_count():
		var path: String=str(left.track_get_path(track))
		if path.ends_with(":arm_l") or path.ends_with(":forearm_l") or path.ends_with(":hand_l"):
			var added: int=slam.add_track(left.track_get_type(track))
			slam.track_set_path(added,left.track_get_path(track))
			for key in left.track_get_key_count(track):slam.track_insert_key(added,left.track_get_key_time(track,key),left.track_get_key_value(track,key))
	for side: String in ["r","l"]:
		rotations(slam,"arm_"+side,[[0.0,Vector3(20,0,0)],[.35,Vector3(145,0,0)],[.5,Vector3(160,0,0)],[.62,Vector3(55,0,0)],[1.2,Vector3(20,0,0)]])
		rotations(slam,"forearm_"+side,[[0.0,Vector3(15,0,0)],[.5,Vector3(30,0,0)],[.62,Vector3(10,0,0)],[1.2,Vector3(15,0,0)]])
	rotations(slam,"chest",[[0.0,Vector3(-8,0,0)],[.5,Vector3(-15,0,0)],[.62,Vector3(25,0,0)],[1.2,Vector3(-8,0,0)]])
	rotations(slam,"spine",[[0.0,Vector3.ZERO],[.5,Vector3(-8,0,0)],[.62,Vector3(10,0,0)],[1.2,Vector3.ZERO]])
	library.add_animation("slam",slam)
	original.free()
	var model:=Node3D.new()
	model.name="HollowheadModel"
	model.add_child(skeleton)
	var player:=AnimationPlayer.new()
	player.name="AnimationPlayer"
	player.add_animation_library("",library)
	player.autoplay="idle"
	player.playback_default_blend_time=.15
	model.add_child(player)
	for child: Node in model.get_children():own(child,model)
	var packed:=PackedScene.new()
	assert(packed.pack(model)==OK)
	assert(ResourceSaver.save(packed,OUT+"hollowhead_model.tscn")==OK)
	print("Hollowhead built: ",vertices.size()," vertices, ",library.get_animation_list())
	model.free()
	quit()
