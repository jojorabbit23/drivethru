# Visual integration invariants; gameplay remains covered by knife_test.gd.
extends SceneTree
var failures := 0
func _initialize() -> void:
 run.call_deferred()
func check(ok: bool, label: String) -> void:
 print(("PASS " if ok else "FAIL ") + label)
 if not ok: failures += 1
func run() -> void:
 var main: Node3D = load("res://main.tscn").instantiate()
 main.set("auto_spawn",false)
 root.add_child(main)
 await physics_frame
 var player: CharacterBody3D = main.get_node("Player")
 var knife: Node3D = player.get_node("Head/Camera3D/Knife")
 knife.set_physics_process(false)
 var animation: AnimationPlayer = knife.get("_arms_anim")
 var pivot: Node3D = knife.get("_pivot")
 var skeleton: Skeleton3D = pivot.find_child("Skeleton3D",true,false)
 check(skeleton.get_bone_count() == 36, "corrected knife skeleton retained")
 check(pivot.find_children("*","CollisionObject3D",true,false).is_empty(), "viewmodel adds no gameplay colliders")
 var shadows_off := true
 for mesh: MeshInstance3D in pivot.find_children("*","MeshInstance3D",true,false):
  shadows_off = shadows_off and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 check(shadows_off,"all viewmodel meshes stop casting world shadows")
 player.call("switch_weapon",1)
 knife.call("_update",0.32)
 knife.call("request","stab")
 knife.call("_update",0.24)
 check(animation.current_animation == "kitchen_knife_stab", "stab uses authored skeleton clip")
 check(absf(animation.current_animation_position - 7.0/30.0) < 0.0001,"full extension matches unchanged 0.24 second hit")
 knife.call("_update",0.48)
 knife.call("request","slash")
 knife.call("_update",0.15)
 check(animation.current_animation == "kitchen_knife_idle", "procedural slash carries the closed knife grip")
 player.call("switch_weapon",0)
 check(not pivot.is_visible_in_tree(),"holstering hides arms, blade and watch together")
 var hand_index: int = skeleton.find_bone("hand_r")
 var arm_index: int = skeleton.find_bone("lowerarm_r")
 var socket_index: int = skeleton.find_bone("weapon_r")
 var grip_preserved := true
 var length_preserved := true
 var max_bend := 0.0
 for clip in ["kitchen_knife_draw","kitchen_knife_idle","kitchen_knife_stab"]:
  var frame_count: int = ceili(animation.get_animation(clip).length * 30.0) + 1
  for frame in frame_count:
   knife.call("_sample_clip",clip,float(frame)/30.0)
   var hand_before: Transform3D = skeleton.get_bone_global_pose(hand_index)
   var socket_before: Transform3D = skeleton.get_bone_global_pose(socket_index)
   knife.call("_set_pose",knife.REST_POS,knife.REST_ROT)
   var hand_after: Transform3D = skeleton.get_bone_global_pose(hand_index)
   var socket_after: Transform3D = skeleton.get_bone_global_pose(socket_index)
   grip_preserved = grip_preserved and hand_before.origin.is_equal_approx(hand_after.origin) and (hand_before.affine_inverse() * socket_before).is_equal_approx(hand_after.affine_inverse() * socket_after)
   # the forearm pivots about the sculpted hand's wrist (top of the cuff)
   var wrist: Vector3 = skeleton.get_bone_global_pose(hand_index) * (knife.get("_hand_wrist") as Vector3)
   var length: float = wrist.distance_to(skeleton.get_bone_global_pose(arm_index).origin)
   length_preserved = length_preserved and absf(length - 0.4) < 0.0001
   max_bend = maxf(max_bend, knife.call("wrist_bend"))
 check(grip_preserved,"upright hold preserves wrist position and knife attachment throughout native clips")
 check(length_preserved,"forearm keeps its original length")
 check(max_bend < 30.0,"wrist bends at most %.1f degrees beyond the pre-bent sculpt (no skin collapse)" % max_bend)
 knife.call("_sample_clip","kitchen_knife_idle",0.0)
 knife.call("_set_pose",knife.REST_POS,knife.REST_ROT)
 var camera: Camera3D = player.get_node("Head/Camera3D")
 var shared: Node = knife.get_node("FpsArms")
 shared._solve()
 var shared_sk: Skeleton3D = shared.skeleton
 var elbow_eye: Vector3 = camera.to_local(shared_sk.to_global(shared_sk.get_bone_global_pose(shared._arms.r.fore).origin))
 var hand_eye: Vector3 = camera.to_local(shared.hand_global("r").origin)
 check(elbow_eye.x > hand_eye.x + 0.08,"visible resting forearm enters from screen-right")
 pivot.transform = Transform3D(Basis.IDENTITY,knife.VIEW_OFFSET)
 knife.call("_sample_clip","kitchen_knife_idle",0.0)
 var up_axis: Vector3 = camera.global_basis.y
 var direction_before: Vector3 = (skeleton.global_basis * skeleton.get_bone_global_pose(socket_index).basis.y).normalized()
 knife.call("_set_pose",knife.REST_POS,knife.REST_ROT)
 var direction_after: Vector3 = (skeleton.global_basis * skeleton.get_bone_global_pose(socket_index).basis.y).normalized()
 # Our -Z knife tip is the socket's -Y axis after the rest-axis correction.
 check((-direction_after).dot(up_axis) > (-direction_before).dot(up_axis) + 0.1,"resting knife is visibly more upright")
 var rolled: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
 var grip_offset: Vector3 = knife.FpsArms.FITS["knife"]["r"][0]
 knife._roll_grip(-knife.KNIFE_WRIST_ROLL)
 var neutral: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
 var neutral_axis: Vector3 = (skeleton.global_basis * skeleton.get_bone_global_pose(socket_index).basis.y).normalized()
 check((rolled*grip_offset).distance_to(neutral*grip_offset)<0.0001 and absf(rad_to_deg(neutral.basis.get_rotation_quaternion().angle_to(rolled.basis.get_rotation_quaternion()))-100.0)<0.01,"100-degree grip roll keeps the visible shared wrist planted")
 check(neutral_axis.dot(direction_after)>0.9999,"grip roll keeps the blade pointing along its original axis")
 knife._roll_grip(knife.KNIFE_WRIST_ROLL)
 var right_hand: MeshInstance3D = pivot.find_child("RightHand",true,false)
 var right_ok: bool = right_hand != null and right_hand.skin != null and right_hand.skin.get_bind_count() == 2
 var psx_right_faces := 0
 var psx_mesh: MeshInstance3D = pivot.find_child("fp_arms_mesh",true,false)
 var psx_bones: PackedInt32Array = psx_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES]
 for i in range(0, psx_bones.size(), 4):
  if psx_mesh.skin.get_bind_name(psx_bones[i]).ends_with("_r"): psx_right_faces += 1
 check(right_ok and psx_right_faces == 0,"sculpted right hand replaces the PSX right arm (skinned to hand_r + lowerarm_r)")
 var hand_box: AABB = right_hand.get_aabb()
 check(hand_box.size.length() > 0.2 and pivot.find_children("*","MeshInstance3D",true,false).filter(func(m: MeshInstance3D) -> bool: return m.mesh != null and m.mesh.resource_path.contains("dagger")).is_empty(),"the supplied dagger is not in the viewmodel")
 # alternative viewmodel: the sculpt's own dagger in its own hand (slot 3)
 var dagger_weapon: Node3D = player.get_node("Head/Camera3D/Dagger")
 var dagger_pivot: Node3D = dagger_weapon.get("_pivot")
 dagger_weapon._sample_clip("kitchen_knife_idle",0.0)
 dagger_weapon._set_pose(dagger_weapon.REST_POS,dagger_weapon.REST_ROT)
 check(dagger_pivot.basis.is_equal_approx(Basis.IDENTITY),"alternative dagger is excluded from the new wrist roll")
 var dagger_hand: MeshInstance3D = dagger_pivot.find_child("RightHand",true,false)
 var native := false
 for k: Vector2 in (dagger_hand.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2] as PackedVector2Array):
  if k.x > 3.5:
   native = true
   break
 check(native and dagger_pivot.find_child("Model",true,false) == null and dagger_weapon.get("_attack_kind") != null,"dagger alternative keeps the sculpt's own blade and uses the same knife gameplay script")
 var arms_mesh: MeshInstance3D = pivot.find_child("fp_arms_mesh",true,false)
 var active_material: ShaderMaterial = arms_mesh.mesh.surface_get_material(0)
 var active_albedo: Texture2D = active_material.get_shader_parameter("albedo_tex")
 var active_roughness: Texture2D = active_material.get_shader_parameter("roughness_tex")
 check(active_albedo.get_width() == 1774 and active_albedo.get_height() == 887 and active_albedo.get_image().has_mipmaps() and active_roughness != null,"HD atlas and roughness are actively assigned with mipmaps")
 main.queue_free()
 for i in 3: await process_frame
 print("%d failure(s)" % failures)
 quit(1 if failures else 0)
