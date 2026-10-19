# Behavioural checks for the two-barrel reload and camera-centred pellet hits.
extends SceneTree
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
 print(("PASS " if ok else "FAIL ")+label)
 if not ok: failures+=1
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate()
 main.set("auto_spawn",false)
 root.add_child(main)
 var player: CharacterBody3D=main.get_node("Player")
 var gun: Node3D=player.get_node("Head/Camera3D/CropDuster")
 gun.set_physics_process(false)
 check(not gun.shoot() and gun.ammo==2,"holstered gun cannot fire")
 player.switch_weapon(2)
 check(not gun.shoot(),"draw gate blocks shooting")
 gun._update(0.45)
 check(gun.shoot() and gun.ammo==1,"first shot consumes exactly one shell")
 check(not gun.shoot() and gun.ammo==1,"cooldown blocks a second immediate shot")
 gun._update(0.43)
 check(gun.shoot() and gun.ammo==0,"second barrel fires independently")
 gun._update(0.43)
 check(not gun.shoot() and gun.state=="reload","empty trigger starts reload without firing")
 gun._update(1.89)
 check(gun.ammo==0 and gun.reserve==24,"reload gives no ammunition before insertion")
 gun._update(0.02)
 check(gun.ammo==1 and gun.reserve==23,"first seated shell transfers at 1.9 seconds")
 player.switch_weapon(1)
 gun._update(0.23)
 check(not gun.visible and gun.ammo==1 and gun.reserve==23,"holstering cancels reload without losing a seated shell")
 player.switch_weapon(2)
 gun._update(0.45)
 gun.reload()
 gun._update(2.41)
 check(gun.ammo==2 and gun.reserve==22,"top-up only spends the missing round")
 gun._update(1.0)
 check(gun.state=="idle" and not gun.reload(),"close completes and full weapon cannot reload")
 gun.loaded.fill(false)
 gun.reserve=1
 gun.reload()
 gun._update(3.4)
 check(gun.ammo==1 and gun.reserve==0,"one reserve shell cannot become two rounds")
 check(not gun.reload(),"empty reserve prevents reload")
 player.set_physics_process(false)
 player.global_position=Vector3(1.4,0.05,-1.4)
 player.rotation.y=-PI/2
 player.get_node("Head").rotation=Vector3.ZERO
 var z: Node3D=main.spawn_zombie(main.get_node("ShopGreybox/Windows/Window_A"))
 z.global_position=Vector3(3.4,0.05,-1.4)
 z.set_physics_process(false)
 for i in 3: await physics_frame
 gun.cooldown=0.0
 gun.loaded.fill(true)
 player.camera.look_at(z.global_position+Vector3(0,1.0,0))
 var hp: float=z.health
 gun.shoot()
 check(z.health<hp,"pellet cone damages the target under the crosshair")
 check(z.is_dead(),"close centered shot kills a full-health Shambler")
 z.queue_free()
 await process_frame
 var scuttler: Node3D=load("res://enemies/scuttler/scuttler.tscn").instantiate()
 main.add_child(scuttler)
 scuttler.global_position=Vector3(3.4,0.05,-1.4)
 scuttler.set_physics_process(false)
 player.camera.look_at(scuttler.global_position+Vector3(0,0.55,0))
 for i in 3:await physics_frame
 gun.cooldown=0.0
 gun.loaded.fill(true)
 gun.shoot()
 check(scuttler.is_dead(),"close centered shot kills a full-health Scuttler")
 scuttler.queue_free()
 await process_frame
 player.camera.rotation=Vector3.ZERO
 var behind: Node3D=main.spawn_zombie(main.get_node("ShopGreybox/Windows/Window_A"))
 behind.global_position=Vector3(3.4,0.05,-1.4)
 behind.set_physics_process(false)
 var wall:=StaticBody3D.new()
 wall.collision_layer=1
 var collision:=CollisionShape3D.new()
 var shape:=BoxShape3D.new()
 shape.size=Vector3(0.2,3.0,2.0)
 collision.shape=shape
 wall.add_child(collision)
 main.add_child(wall)
 wall.position=Vector3(2.3,1.0,-1.4)
 for i in 3: await physics_frame
 hp=behind.health
 gun.cooldown=0.0
 gun.loaded.fill(true)
 gun.shoot()
 check(behind.health==hp,"solid cover blocks every pellet")
 # Recovery queues reload input instead of snapping straight out of recoil.
 gun.loaded.fill(true)
 gun.reserve=24
 gun.cooldown=0.0
 gun.state="idle"
 gun.shoot()
 check(gun.reload() and gun.state=="idle","reload request waits for the firing recovery")
 gun._update(0.20)
 check(gun.state=="idle","action remains closed during recoil recovery")
 gun._update(0.23)
 check(gun.state=="reload" and gun.clock<0.02,"queued reload starts after recovery without skipping animation time")
 var plan: Array=gun.get("_reload_plan")
 check(plan[0] and not plan[1],"top-up plans only the spent barrel")
 gun._update(0.99)
 var mechanics: Skeleton3D=gun.get("_mechanics")
 var right_shell: int=mechanics.find_bone("shell_right")
 check(mechanics.get_bone_pose_position(right_shell).is_equal_approx(mechanics.get_bone_rest(right_shell).origin),"unfired shell stays seated while opening")
 # Sample both chamber contacts in a full reload.
 gun.state="idle"
 gun.loaded.fill(false)
 gun.reload()
 var left: Node3D=gun.get("_left_hand")
 var model: Node3D=gun.get("_gun")
 for i in 2:
  gun.clock=1.9 if i==0 else 2.4
  gun._pose(0.0)
  var target: Vector3=gun.call("_shell_grip_point",i)
  check(left.to_global(gun.get("_hand_anchor")).distance_to(model.to_global(target))<0.0001,"palm anchor follows shell %d through the rotated action" % (i+1))
 # The palm must sit above the shell instead of disappearing underneath the receiver.
 var palm_center: Vector3=player.camera.to_local(left.to_global((left as MeshInstance3D).get_aabb().get_center()))
 var shell_center: Vector3=player.camera.to_local(model.to_global(gun._shell_grip_point(1)))
 check(palm_center.y>shell_center.y+0.025,"loading palm approaches from above the chamber")
 var pose_visible:=true
 for frame in 69:
  gun.clock=float(frame)*0.05
  gun._pose(0.0)
  var center: Vector3=player.camera.to_local(left.to_global((left as MeshInstance3D).get_aabb().get_center()))
  pose_visible=pose_visible and center.z< -0.1 and absf(center.y/center.z)<0.72 and absf(center.x/center.z)<1.2
 check(pose_visible,"loading glove stays within the view throughout reload")
 gun.clock=2.4
 gun._pose(0.0)
 var before_hand: Transform3D=model.global_transform.affine_inverse()*left.global_transform
 var before_hinge: Transform3D=mechanics.get_bone_global_pose(mechanics.find_bone("barrel_hinge"))
 player.switch_weapon(1)
 gun._update(0.10)
 check(gun.visible and (model.global_transform.affine_inverse()*left.global_transform).is_equal_approx(before_hand),"mid-reload holster lowers the complete grip together")
 check(mechanics.get_bone_global_pose(mechanics.find_bone("barrel_hinge")).is_equal_approx(before_hinge),"mid-reload holster does not snap the action closed")
 gun._update(0.13)
 player.switch_weapon(2)
 gun._update(0.45)
 player.health=0.0
 gun.cooldown=0.0
 check(not gun.shoot() and not gun.reload(),"dead player cannot fire or reload")
 var pivot: Node3D=gun.get("_pivot")
 check(pivot.find_children("*","CollisionObject3D",true,false).is_empty(),"held model adds no world colliders")
 var shadows_off:=true
 for mesh: MeshInstance3D in pivot.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh!=null: shadows_off=shadows_off and mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 check(shadows_off,"held meshes cast no world shadows")
 gun._vapour.release(model.to_global(Vector3(0,0.32,0.5)),player.camera)
 check(gun._vapour.puffs.size()==8,"muzzle vapor uses a fixed eight-puff pool")
 gun._vapour.advance(1.0)
 check(gun._vapour.puffs.all(func(puff: MeshInstance3D):return not puff.visible),"vapor fully clears after firing")
 main.free()
 for i in 3: await process_frame
 print("%d failure(s)" % failures)
 quit(1 if failures else 0)
