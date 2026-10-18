# Rebuild: godot --headless --path . --script res://tools/build_knife_viewmodel.gd
# Source GLB/atlas stay unchanged. Recolour and wristwatch are project additions.
extends SceneTree
const P = preload("res://core/palette.gd")
const OUT := "res://weapons/knife/"
const HD_DIR := OUT + "textures/cleatimus_hd/"
const SOURCE := "res://addons/psx_fps_arms/models/fp_arms_free_v7_model.glb"
func _initialize() -> void:
 build.call_deferred()
func material(texture: Texture2D, regions: bool, tint: Color = Color.WHITE, face: bool = false) -> ShaderMaterial:
 var result := ShaderMaterial.new()
 result.shader = load(OUT + "arms_viewmodel.gdshader")
 result.set_shader_parameter("albedo_tex", texture)
 result.set_shader_parameter("roughness_tex", load(HD_DIR + "hands_roughness.png"))
 result.set_shader_parameter("regions", regions)
 result.set_shader_parameter("watch_face", face)
 result.set_shader_parameter("tint", tint)
 return result
func painted_atlas() -> Image:
 # Use the supplied HD artwork directly; no procedural white speckle overlay.
 var original: Texture2D = load(HD_DIR + "hands_basecolor.png")
 var image: Image = original.get_image().duplicate()
 image.convert(Image.FORMAT_RGBA8)
 return image
func box(parent: Node3D, label: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
 var instance := MeshInstance3D.new()
 instance.name = label
 var mesh := BoxMesh.new()
 mesh.size = size
 instance.mesh = mesh
 instance.position = pos
 instance.material_override = mat
 instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(instance)
 return instance
func own(node: Node, scene: Node) -> void:
 for child in node.get_children():
  child.owner = scene
  own(child,scene)
func build() -> void:
 var image := painted_atlas()
 image.save_png(OUT + "cleatimus_arms_atlas.png")
 image.generate_mipmaps()
 var texture := ImageTexture.create_from_image(image)
 ResourceSaver.save(texture,OUT + "cleatimus_arms_atlas.res")
 texture.take_over_path(OUT + "cleatimus_arms_atlas.res")
 var mat := material(texture,true)
 ResourceSaver.save(mat,OUT + "cleatimus_arms_material.tres")
 mat.take_over_path(OUT + "cleatimus_arms_material.tres")
 var scene := Node3D.new()
 scene.name = "KnifeViewmodel"
 var arms: Node3D = load(SOURCE).instantiate()
 arms.scene_file_path = "" # Flatten before packing; avoid duplicating inherited children.
 arms.name = "Arms"
 arms.rotation.y = PI
 scene.add_child(arms)
 root.add_child(scene)
 var skeleton: Skeleton3D = arms.find_child("Skeleton3D",true,false)
 var mesh: MeshInstance3D = arms.find_child("fp_arms_mesh",true,false)
 var arrays: Array = mesh.mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
 var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
 var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
 var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
 var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
 var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for face_index in range(0,indices.size(),3):
  var first: int = indices[face_index]
  var bind: int = joints[first*4]
  var bone_name: String = mesh.skin.get_bind_name(bind)
  var bone: int = skeleton.find_bone(bone_name)
  var centre: Vector3 = (vertices[indices[face_index]] + vertices[indices[face_index+1]] + vertices[indices[face_index+2]]) / 3.0
  var local: Vector3 = skeleton.get_bone_global_rest(bone).affine_inverse() * centre
  var kind := 2
  if bone_name.begins_with("lowerarm"):
   kind = 1 if local.y > 0.35 else 0
  elif bone_name.contains("_02_") or bone_name.contains("_03_"):
   kind = 3
  for corner in 3:
   var i: int = indices[face_index+corner]
   surface.set_normal(normals[i])
   surface.set_color(colours[i])
   surface.set_uv(uv[i])
   surface.set_uv2(Vector2(kind,0))
   surface.set_bones(PackedInt32Array([joints[i*4],joints[i*4+1],joints[i*4+2],joints[i*4+3]]))
   surface.set_weights(PackedFloat32Array([weights[i*4],weights[i*4+1],weights[i*4+2],weights[i*4+3]]))
   surface.add_vertex(vertices[i])
 var recoloured: ArrayMesh = surface.commit()
 recoloured.surface_set_material(0,mat)
 ResourceSaver.save(recoloured,OUT + "cleatimus_arms_mesh.res")
 recoloured.take_over_path(OUT + "cleatimus_arms_mesh.res")
 mesh.mesh = recoloured
 mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var socket := BoneAttachment3D.new()
 socket.name = "KnifeSocket"
 skeleton.add_child(socket)
 socket.bone_name = "weapon_r"
 var grip := Node3D.new()
 grip.name = "GripOffset"
 socket.add_child(grip)
 var weapon_bone: int = skeleton.find_bone("weapon_r")
 # README rest-axis cancellation. Our knife is -Z forward, pack weapons +Z.
 grip.transform = Transform3D(skeleton.get_bone_global_rest(weapon_bone).basis.inverse() * Basis(Vector3.UP,PI),Vector3.ZERO)
 var knife: Node3D = load(OUT + "knife_model.tscn").instantiate()
 knife.scene_file_path = ""
 knife.name = "Model"
 grip.add_child(knife)
 var watch := BoneAttachment3D.new()
 watch.name = "LeftWatch"
 skeleton.add_child(watch)
 watch.bone_name = "lowerarm_l"
 var band: MeshInstance3D = box(watch,"Band",Vector3(0.069,0.026,0.069),Vector3(0,0.352,0),material(texture,false,P.WET_CHARCOAL))
 var case := Node3D.new()
 case.name = "WatchCase"
 case.position = Vector3(-0.039,0.352,0)
 case.rotation.y = -PI/2
 watch.add_child(case)
 box(case,"Bezel",Vector3(0.051,0.041,0.012),Vector3.ZERO,material(texture,false,P.CONCRETE_GREY))
 var face := MeshInstance3D.new()
 face.name = "Display420"
 var quad := QuadMesh.new()
 quad.size = Vector2(0.044,0.034)
 face.mesh = quad
 face.position.z = 0.0062
 face.material_override = material(texture,false,Color.WHITE,true)
 face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 case.add_child(face)
 var animation: AnimationPlayer = arms.find_child("AnimationPlayer",true,false)
 animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 animation.get_animation("kitchen_knife_idle").loop_mode = Animation.LOOP_LINEAR
 own(scene,scene)
 var packed := PackedScene.new()
 packed.pack(scene)
 var error: Error = ResourceSaver.save(packed,OUT + "knife_viewmodel.tscn")
 print("Knife viewmodel saved: ",error,"; bones=",skeleton.get_bone_count(),"; source blade meshes=0; custom knife only")
 scene.free()
 quit(error)
