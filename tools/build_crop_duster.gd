extends SceneTree
const SOURCE="res://addons/psx_firearms/models/fp_pump_shotgun_model.glb"
func _initialize() -> void: build.call_deferred()
static func own_children(node: Node, scene: Node) -> void:
 for child in node.get_children():
  child.owner=scene
  own_children(child,scene)
static func recolour(original: ArrayMesh, kind: int, wrist: Vector3=Vector3.ZERO) -> ArrayMesh:
 var arrays: Array=original.surface_get_arrays(0)
 var uv2:=PackedVector2Array()
 uv2.resize(original.surface_get_array_len(0))
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 for i in uv2.size():
  uv2[i]=Vector2(1 if kind==0 and vertices[i].distance_to(wrist)<0.055 else kind,0)
 arrays[Mesh.ARRAY_TEX_UV2]=uv2
 var mesh:=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 mesh.surface_set_material(0,load("res://weapons/knife/cleatimus_arms_material.tres"))
 return mesh
static func game_texture(source: Texture2D, path: String) -> Texture2D:
 if source==null: return null
 var image: Image=source.get_image()
 if image.is_compressed(): image.decompress()
 image.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
 image.generate_mipmaps()
 var texture:=ImageTexture.create_from_image(image)
 ResourceSaver.save(texture,path,ResourceSaver.FLAG_COMPRESS)
 texture.take_over_path(path)
 return texture
func build() -> void:
 var scene:=Node3D.new()
 scene.name="CropDusterViewmodel"
 var arms: Node3D=load(SOURCE).instantiate()
 arms.scene_file_path=""
 arms.name="Arms"
 arms.rotation.y=PI
 scene.add_child(arms)
 var held: Node3D=arms.find_child("fp_pump_shotgun_held",true,false)
 for mesh: MeshInstance3D in arms.find_children("*","MeshInstance3D",true,false):
  if mesh.name in ["fp_pump_shotgun","fp_pump_shotgun_forearm_l","fp_pump_shotgun_hand_r","fp_pump_shotgun_hand_l"]:
   var wrist: Vector3=Vector3(0.262258,-0.016676,0.301567) if mesh.name=="fp_pump_shotgun" else Vector3.ZERO
   mesh.mesh=recolour(mesh.mesh,0 if mesh.name in ["fp_pump_shotgun","fp_pump_shotgun_forearm_l"] else 2,wrist)
   mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  else:
   mesh.mesh=null # Preserve animation hierarchy; remove the pack's weapon geometry.
 var gun: Node3D=load("res://weapons/crop_duster/source/Crop_Duster_Rigged_Textured.glb").instantiate()
 gun.scene_file_path=""
 gun.name="Gun"
 gun.position=Vector3(0,-0.10,0.14)
 gun.scale=Vector3.ONE*0.65
 held.add_child(gun)
 for mesh: MeshInstance3D in gun.find_children("*","MeshInstance3D",true,false):
  mesh.mesh=mesh.mesh.duplicate()
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var first: StandardMaterial3D=mesh.mesh.surface_get_material(0)
  var albedo: Texture2D=game_texture(first.albedo_texture,"res://weapons/crop_duster/gun_albedo.res")
  var orm: Texture2D=game_texture(first.metallic_texture,"res://weapons/crop_duster/gun_orm.res")
  for i in mesh.mesh.get_surface_count():
   var original: StandardMaterial3D=mesh.mesh.surface_get_material(i)
   var mat:=ShaderMaterial.new()
   mat.shader=load("res://weapons/crop_duster/viewmodel.gdshader")
   mat.set_shader_parameter("colour",original.albedo_color)
   mat.set_shader_parameter("textured",original.albedo_texture!=null)
   mat.set_shader_parameter("albedo_tex",albedo if original.albedo_texture!=null else null)
   mat.set_shader_parameter("roughness",original.roughness)
   mat.set_shader_parameter("metallic",original.metallic)
   mat.set_shader_parameter("orm_tex",orm if original.metallic_texture!=null else null)
   mat.set_shader_parameter("has_orm",original.metallic_texture!=null)
   mesh.mesh.surface_set_material(i,mat)
 root.add_child(scene)
 for ap: AnimationPlayer in scene.find_children("*","AnimationPlayer",true,false):
  ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 own_children(scene,scene)
 var packed:=PackedScene.new()
 packed.pack(scene)
 var err: Error=ResourceSaver.save(packed,"res://weapons/crop_duster/crop_duster_viewmodel.tscn")
 print("Crop Duster viewmodel: ",err)
 scene.free()
 quit(err)
