# Rebuild: godot --headless --path . --script res://tools/build_knife_viewmodel.gd
# Source GLB/atlas stay unchanged. Recolour and wristwatch are project additions.
extends SceneTree
const P = preload("res://core/palette.gd")
const OUT := "res://weapons/knife/"
const HD_DIR := OUT + "textures/cleatimus_hd/"
const SOURCE := "res://addons/psx_fps_arms/models/fp_arms_free_v7_model.glb"
const HandMesh = preload("res://tools/knife_hand_mesh.gd")
const BlockyMesh = preload("res://tools/blocky_mesh.gd")
const HAND_KEEP := 0.5 # simplify the sculpted hand to about half its triangles
const Weapon = preload("res://weapons/knife/knife_weapon.gd")
const FOREARM_LENGTH := 0.4 # elbow to the sculpt's wrist pivot
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
 var error: Error = assemble(false, texture, mat)
 if error == OK:
  error = assemble(true, texture, mat)
 quit(error)

# keep_dagger = false: our survival knife in the derived hand -> knife_viewmodel.tscn
# keep_dagger = true: the sculpt's own dagger in its own hand -> dagger_viewmodel.tscn
func assemble(keep_dagger: bool, texture: Texture2D, mat: Material) -> Error:
 var scene := Node3D.new()
 scene.name = "DaggerViewmodel" if keep_dagger else "KnifeViewmodel"
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
  if bone_name.ends_with("_r"):
   continue # the right arm is replaced by the derived sculpted hand below
  var kind := 2
  if bone_name.begins_with("lowerarm"):
   kind = 1 if local.y > 0.35 else 0
  elif bone_name.contains("_02_") or bone_name.contains("_03_"):
   kind = 2 # Reference grip has continuous teal glove coverage over the fingers.
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
 if keep_dagger:
  recoloured = load(OUT + "cleatimus_arms_mesh.res") # identical; share the knife build's copy
 else:
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
 var hand_info: Dictionary = build_right_hand(arms, skeleton, grip, knife, mat, keep_dagger)
 if keep_dagger:
  knife.free() # only its frame was needed; the sculpt's dagger is the blade
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
 for key in hand_info:
  scene.set_meta(key, hand_info[key])
 own(scene,scene)
 var packed := PackedScene.new()
 packed.pack(scene)
 var out_path := OUT + ("dagger_viewmodel.tscn" if keep_dagger else "knife_viewmodel.tscn")
 var error: Error = ResourceSaver.save(packed,out_path)
 print(out_path, " saved: ",error,"; bones=",skeleton.get_bone_count(),"; ", "the sculpt's own dagger" if keep_dagger else "supplied dagger removed; our knife only")
 scene.free()
 return error

# Handle cross-section of OUR knife, in knife space, between guard and pommel.
func handle_profile(knife: Node3D) -> Array:
 var mesh: ArrayMesh = (knife.get_node("Mesh") as MeshInstance3D).mesh
 var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var z_min := INF
 var z_max := -INF
 for p in verts:
  if absf(p.x) < 0.0155: # the guard is wider than the handle
   pass
  z_max = maxf(z_max, p.z)
 # guard: the widest slice; handle runs from just past it to the pommel
 var guard_z := -INF
 for p in verts:
  if absf(p.x) > 0.0155 and p.z < 0.0 and p.z > -0.12:
   guard_z = maxf(guard_z, p.z)
 z_min = guard_z + 0.002
 var lo := Vector2(INF, INF)
 var hi := Vector2(-INF, -INF)
 for p in verts:
  if p.z > z_min and p.z < z_max:
   lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
   hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
 var centre := (lo + hi) * 0.5
 var rows := []
 var z := z_min
 while z <= z_max:
  var half := Vector2.ZERO
  for p in verts:
   if absf(p.z - z) <= 0.003:
    half = Vector2(maxf(half.x, absf(p.x - centre.x)), maxf(half.y, absf(p.y - centre.y)))
  if half != Vector2.ZERO:
   rows.append([z, half.x, half.y])
  z += 0.004
 return [centre, rows]

# Builds the sculpted right hand, skinned to hand_r (fist) and lowerarm_r
# (sleeve), blended across the cuff. Returns metadata knife_weapon.gd uses to
# place the forearm about the sculpt's own wrist.
func build_right_hand(arms: Node3D, skeleton: Skeleton3D, grip: Node3D, knife: Node3D, mat: Material, keep_dagger := false) -> Dictionary:
 var anim: AnimationPlayer = arms.find_child("AnimationPlayer", true, false)
 anim.play("kitchen_knife_idle", 0.0)
 anim.seek(0.0, true)
 var hand_bone := skeleton.find_bone("hand_r")
 var arm_bone := skeleton.find_bone("lowerarm_r")
 var weapon_bone := skeleton.find_bone("weapon_r")
 var hand0: Transform3D = skeleton.get_bone_global_pose(hand_bone)
 var knife0: Transform3D = skeleton.get_bone_global_pose(weapon_bone) * grip.transform * knife.transform
 # the camera's +Z, expressed in knife space at the corrected idle pose
 # (knife_weapon.gd turns the whole hand upright and rolls it about the knife)
 var skel_to_view: Transform3D = skeleton.global_transform
 var wrist_axis: Vector3 = (skel_to_view.basis.inverse() * Vector3.RIGHT).normalized()
 var socket_axis: Vector3 = skeleton.get_bone_global_pose(weapon_bone).basis.y.normalized()
 var turn := Basis(wrist_axis, Weapon.UPRIGHT_ANGLE) * Basis(socket_axis, Weapon.GRIP_ROLL)
 var face_dir: Vector3 = (turn * knife0.basis).inverse() * (skel_to_view.basis.inverse() * Vector3(0, 0, 1))
 # where knife_weapon.gd will aim the forearm at idle: halfway between the
 # authored elbow and the lower-right screen direction (see _position_right_forearm)
 var arm0: Transform3D = skeleton.get_bone_global_pose(arm_bone)
 var eye_dir: Vector3 = (skel_to_view.basis.inverse() * Weapon.RIGHT_ELBOW_DIRECTION).normalized()
 var idle_dir: Vector3 = (arm0.origin - hand0.origin).normalized().slerp(eye_dir, 0.5).normalized()
 # ...seen from the turned hand, then put back into the unturned bind pose
 var bind_dir: Vector3 = hand0.basis * ((turn * hand0.basis).inverse() * idle_dir)
 var fit: Dictionary = HandMesh.build(face_dir.normalized(), handle_profile(knife), knife0.basis.inverse() * bind_dir, keep_dagger)
 var wrist: Vector3 = knife0 * (fit["wrist"] as Vector3)
 var out_dir: Vector3 = (knife0.basis * (fit["forearm"] as Vector3)).normalized()
 # lowerarm bind frame: Y runs elbow -> wrist, no twist relative to the hand
 var y_axis := -out_dir
 var x_axis: Vector3 = hand0.basis.x.slide(y_axis).normalized()
 var arm_bind := Transform3D(Basis(x_axis, y_axis, x_axis.cross(y_axis)).orthonormalized(), wrist + out_dir * FOREARM_LENGTH)
 var verts: PackedVector3Array = fit["vertices"]
 var bones := PackedInt32Array()
 var weights := PackedFloat32Array()
 var cuff_end: float = fit["cuff_end"]
 var skel_verts := PackedVector3Array()
 var skel_norms := PackedVector3Array()
 var normals: PackedVector3Array = fit["normals"]
 for i in verts.size():
  var p: Vector3 = knife0 * verts[i]
  skel_verts.append(p)
  skel_norms.append((knife0.basis * normals[i]).normalized())
  var a := (p - wrist).dot(out_dir)
  var w := smoothstep(-0.004, cuff_end * 0.8, a)
  bones.append_array([0, 1, 0, 0])
  weights.append_array([1.0 - w, w, 0.0, 0.0])
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = skel_verts
 arrays[Mesh.ARRAY_NORMAL] = skel_norms
 arrays[Mesh.ARRAY_TEX_UV] = fit["uv"]
 arrays[Mesh.ARRAY_TEX_UV2] = fit["uv2"]
 arrays[Mesh.ARRAY_COLOR] = fit["colors"]
 arrays[Mesh.ARRAY_BONES] = bones
 arrays[Mesh.ARRAY_WEIGHTS] = weights
 # a little blockier, to sit with the voxel Shambler: fewer triangles, faceted
 var before := BlockyMesh.triangle_count(arrays)
 arrays = BlockyMesh.flat(BlockyMesh.simplify(BlockyMesh.weld(arrays), HAND_KEEP))
 print("Right hand blocky: %d -> %d triangles, flat shaded" % [before, BlockyMesh.triangle_count(arrays)])
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 mesh.surface_set_material(0, mat)
 var mesh_path := OUT + ("cleatimus_dagger_hand_mesh.res" if keep_dagger else "cleatimus_right_hand_mesh.res")
 ResourceSaver.save(mesh, mesh_path)
 mesh.take_over_path(mesh_path)
 var skin := Skin.new()
 skin.add_named_bind("hand_r", hand0.affine_inverse())
 skin.add_named_bind("lowerarm_r", arm_bind.affine_inverse())
 var instance := MeshInstance3D.new()
 instance.name = "RightHand"
 instance.mesh = mesh
 instance.skin = skin
 instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 skeleton.add_child(instance)
 instance.skeleton = NodePath("..")
 print("Right hand: %d sculpt triangles kept, %d dagger triangles removed, %d vertices fitted to our handle, sleeve x%.2f, wrist pre-bent %.1f deg" % [fit["kept"], fit["removed"], fit["opened"], fit["stretch"], fit["pre_bend"]])
 # hand-local data for knife_weapon.gd
 return {
  "hand_wrist": hand0.affine_inverse() * wrist,
  "hand_forearm_bind": hand0.affine_inverse() * arm_bind,
 }
