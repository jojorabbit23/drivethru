extends RefCounted
# Mechanical viewmodel rig, built from the owner's single textured mesh.
const SOURCE := "res://weapons/pistol/source/stylized_pistol.glb"
const OUT := "res://weapons/pistol/"
const FACTOR := 0.22
const ORIGIN := Vector3(0, 0.21, -0.30)
const HAMMER := Vector3(0, 0.45, -0.407)
const MAG := Vector3(0, 0.028, -0.347)
const VM_SHADER = preload("res://weapons/crop_duster/viewmodel.gdshader")
const Palette = preload("res://core/palette.gd")
var parts: Dictionary = {}
var finish: ShaderMaterial
func build() -> Node3D:
 var doc:=GLTFDocument.new()
 var state:=GLTFState.new()
 assert(doc.append_from_file(ProjectSettings.globalize_path(SOURCE),state)==OK)
 var source: ImporterMesh=(state.get_meshes()[0] as GLTFMesh).mesh
 var a: Array=source.get_surface_arrays(0)
 var material: StandardMaterial3D=source.get_surface_material(0)
 var image: Image=material.albedo_texture.get_image()
 image.decompress()
 image.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
 assert(image.save_png(OUT+"stylized_albedo.png")==OK)
 image.generate_mipmaps()
 finish=ShaderMaterial.new()
 finish.shader=VM_SHADER
 finish.set_shader_parameter("textured",true)
 finish.set_shader_parameter("albedo_tex",ImageTexture.create_from_image(image))
 finish.set_shader_parameter("colour",Color.WHITE)
 finish.set_shader_parameter("roughness",0.85)
 finish.set_shader_parameter("metallic",0.15)
 assert(ResourceSaver.save(finish,OUT+"stylized_material.res")==OK)
 finish.take_over_path(OUT+"stylized_material.res")
 for name: String in ["frame","slide","hammer","magazine"]:parts[name]=[]
 var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
 var normals: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
 var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV]
 var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX]
 for tri in range(0,indices.size(),3):
  var polygon: Array=[]
  for k in 3:
   var at: int=indices[tri+k]
   polygon.append([vertices[at],normals[at],uv[at]])
  append_polygon("magazine",clip(polygon,Vector3.UP,0.038,false))
  var upper: Array=clip(polygon,Vector3.UP,0.038,true)
  var rear: Array=clip(upper,Vector3.BACK,-0.405,false)
  append_polygon("hammer",clip(rear,Vector3.UP,0.45,true))
  append_polygon("frame",clip(rear,Vector3.UP,0.45,false))
  var front: Array=clip(upper,Vector3.BACK,-0.405,true)
  append_polygon("slide",clip(front,Vector3.UP,0.405,true))
  append_polygon("frame",clip(front,Vector3.UP,0.405,false))
 var rig:=Node3D.new()
 rig.name="StylizedPistol"
 rig.set_meta("source",SOURCE)
 for name: String in parts:
  var pivot: Vector3=HAMMER if name=="hammer" else (MAG if name=="magazine" else ORIGIN)
  var mesh:=make_mesh(parts[name],pivot)
  assert(mesh.get_faces().size()>0,"Missing mechanical part: "+name)
  var mesh_path: String=OUT+"stylized_"+name+".res"
  assert(ResourceSaver.save(mesh,mesh_path)==OK)
  mesh.take_over_path(mesh_path)
  var node:=MeshInstance3D.new()
  node.name="pistol_"+name
  node.mesh=mesh
  node.position=(pivot-ORIGIN)*FACTOR
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  rig.add_child(node)
 # The source only has a magazine floor plate. Add the body concealed inside the grip.
 var mag: Node3D=rig.get_node("pistol_magazine")
 var body:=MeshInstance3D.new()
 body.name="MagazineBody"
 var box:=BoxMesh.new()
 box.size=Vector3(0.021,0.069,0.031)
 body.mesh=box
 body.position=Vector3(0,0.034,0.008)
 body.rotation_degrees.x=14
 body.material_override=metal()
 mag.add_child(body)
 # Dark internal receiver and hammer axle hide the source's cut surfaces when cycling.
 add_box(rig,"ReceiverInterior",Vector3(0,0.047,0.06),Vector3(0.024,0.009,0.16))
 var hammer: Node3D=rig.get_node("pistol_hammer")
 add_box(hammer,"HammerHeel",Vector3(0,-0.001,0.001),Vector3(0.012,0.009,0.008))
 add_box(rig,"GripInterior",Vector3(0,-0.0115,-0.011),Vector3(0.023,0.05,0.026))
 var anim:=AnimationPlayer.new()
 anim.name="AnimationPlayer"
 rig.add_child(anim)
 var library:=AnimationLibrary.new()
 var reset:=Animation.new()
 reset.length=0.001
 var fire:=Animation.new()
 fire.length=0.22
 var reload:=Animation.new()
 reload.length=1.6
 var hammer_pos: Vector3=hammer.position
 var mag_pos: Vector3=mag.position
 var idle:=Animation.new()
 idle.length=1.0
 idle.loop_mode=Animation.LOOP_LINEAR
 track(idle,"pistol_slide:position",[0.0,1.0],[Vector3.ZERO,Vector3.ZERO])
 track(idle,"pistol_hammer:rotation",[0.0,1.0],[Vector3(-0.5,0,0),Vector3(-0.5,0,0)])
 track(idle,"pistol_magazine:position",[0.0,1.0],[mag_pos,mag_pos])
 track(reset,"pistol_slide:position",[0.0],[Vector3.ZERO])
 track(reset,"pistol_hammer:rotation",[0.0],[Vector3(-0.5,0,0)])
 track(reset,"pistol_magazine:position",[0.0],[mag_pos])
 track(fire,"pistol_slide:position",[0.0,0.025,0.075,0.16,0.22],[Vector3.ZERO,Vector3(0,0,-0.033),Vector3(0,0,-0.033),Vector3.ZERO,Vector3.ZERO])
 # Hammer drops at ignition, is drawn back by the returning slide, then remains cocked.
 track(fire,"pistol_hammer:rotation",[0.0,0.012,0.045,0.12,0.22],[Vector3(-0.5,0,0),Vector3.ZERO,Vector3(-0.68,0,0),Vector3(-0.5,0,0),Vector3(-0.5,0,0)])
 track(fire,"pistol_magazine:position",[0.0,0.22],[mag_pos,mag_pos])
 track(reload,"pistol_magazine:position",[0.0,0.16,0.44,0.7,0.98,1.13,1.6],[mag_pos,mag_pos,mag_pos+Vector3(0,-0.12,-0.028),mag_pos+Vector3(0,-0.17,-0.04),mag_pos+Vector3(0,-0.07,-0.015),mag_pos,mag_pos])
 track(reload,"pistol_slide:position",[0.0,1.14,1.26,1.37,1.48,1.6],[Vector3.ZERO,Vector3.ZERO,Vector3(0,0,-0.033),Vector3(0,0,-0.033),Vector3.ZERO,Vector3.ZERO])
 track(reload,"pistol_hammer:rotation",[0.0,1.14,1.3,1.48,1.6],[Vector3(-0.5,0,0),Vector3(-0.5,0,0),Vector3(-0.68,0,0),Vector3(-0.5,0,0),Vector3(-0.5,0,0)])
 var rack:=Animation.new()
 rack.length=0.28
 track(rack,"pistol_slide:position",[0.0,0.08,0.15,0.26],[Vector3.ZERO,Vector3(0,0,-0.033),Vector3(0,0,-0.033),Vector3.ZERO])
 track(rack,"pistol_hammer:rotation",[0.0,0.1,0.26],[Vector3(-0.5,0,0),Vector3(-0.68,0,0),Vector3(-0.5,0,0)])
 library.add_animation("rack",rack)
 library.add_animation("idle",idle)
 library.add_animation("RESET",reset)
 library.add_animation("fire",fire)
 library.add_animation("reload",reload)
 anim.add_animation_library("",library)
 hammer.rotation.x=-0.5
 print("Rigged source parts: ",parts.keys()," hammer pivot ",hammer_pos)
 return rig
func metal() -> ShaderMaterial:
 var mat:=ShaderMaterial.new()
 mat.shader=VM_SHADER
 mat.set_shader_parameter("colour",Palette.WET_CHARCOAL)
 mat.set_shader_parameter("roughness",0.8)
 return mat
func add_box(parent: Node3D,name: String,at: Vector3,size: Vector3) -> void:
 var node:=MeshInstance3D.new()
 node.name=name
 var mesh:=BoxMesh.new()
 mesh.size=size
 node.mesh=mesh
 node.position=at
 node.material_override=metal()
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(node)
func track(animation: Animation,path: String,times: Array,values: Array) -> void:
 var index: int=animation.add_track(Animation.TYPE_VALUE)
 animation.track_set_path(index,NodePath(path))
 animation.track_set_interpolation_type(index,Animation.INTERPOLATION_LINEAR)
 for i in times.size():animation.track_insert_key(index,float(times[i]),values[i])
func clip(polygon: Array,normal: Vector3,distance: float,positive: bool) -> Array:
 var result: Array=[]
 if polygon.is_empty():return result
 var previous: Array=polygon[-1]
 var pd: float=(normal.dot(previous[0])-distance)*(1.0 if positive else -1.0)
 for current: Array in polygon:
  var cd: float=(normal.dot(current[0])-distance)*(1.0 if positive else -1.0)
  if (cd>=0)!=(pd>=0):
   var t: float=pd/(pd-cd)
   result.append([(previous[0] as Vector3).lerp(current[0],t),(previous[1] as Vector3).lerp(current[1],t).normalized(),(previous[2] as Vector2).lerp(current[2],t)])
  if cd>=0:result.append(current)
  previous=current
  pd=cd
 return result
func append_polygon(name: String,polygon: Array) -> void:
 for i in range(1,polygon.size()-1):
  parts[name].append(polygon[0])
  parts[name].append(polygon[i])
  parts[name].append(polygon[i+1])
func make_mesh(points: Array,pivot: Vector3) -> ArrayMesh:
 var v:=PackedVector3Array()
 var n:=PackedVector3Array()
 var uv:=PackedVector2Array()
 for point: Array in points:
  v.append(((point[0] as Vector3)-pivot)*FACTOR)
  n.append(point[1])
  uv.append(point[2])
 var arrays: Array=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=v
 arrays[Mesh.ARRAY_NORMAL]=n
 arrays[Mesh.ARRAY_TEX_UV]=uv
 var mesh:=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 mesh.surface_set_material(0,finish)
 return mesh
