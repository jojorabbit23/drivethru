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
 for clip in ["kitchen_knife_draw","kitchen_knife_idle","kitchen_knife_stab"]:
  var frame_count: int = ceili(animation.get_animation(clip).length * 30.0) + 1
  for frame in frame_count:
   knife.call("_sample_clip",clip,float(frame)/30.0)
   var hand_before: Transform3D = skeleton.get_bone_global_pose(hand_index)
   var socket_before: Transform3D = skeleton.get_bone_global_pose(socket_index)
   knife.call("_set_pose",knife.REST_POS,knife.REST_ROT)
   grip_preserved = grip_preserved and hand_before.is_equal_approx(skeleton.get_bone_global_pose(hand_index)) and socket_before.is_equal_approx(skeleton.get_bone_global_pose(socket_index))
   var length: float = skeleton.get_bone_global_pose(hand_index).origin.distance_to(skeleton.get_bone_global_pose(arm_index).origin)
   length_preserved = length_preserved and absf(length - 0.4) < 0.0001
 check(grip_preserved,"elbow adjustment preserves hand and knife socket throughout native clips")
 check(length_preserved,"forearm keeps its original length")
 knife.call("_sample_clip","kitchen_knife_idle",0.0)
 knife.call("_set_pose",knife.REST_POS,knife.REST_ROT)
 var camera: Camera3D = player.get_node("Head/Camera3D")
 var elbow_eye: Vector3 = camera.to_local(skeleton.to_global(skeleton.get_bone_global_pose(arm_index).origin))
 var hand_eye: Vector3 = camera.to_local(skeleton.to_global(skeleton.get_bone_global_pose(hand_index).origin))
 check(elbow_eye.x > hand_eye.x + 0.25 and elbow_eye.z < 0.0,"resting forearm enters from the right, in front of the eye")
 main.queue_free()
 for i in 3: await process_frame
 print("%d failure(s)" % failures)
 quit(1 if failures else 0)
