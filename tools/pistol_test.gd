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
 var gun: Node3D=player.get_node("Head/Camera3D/TestGun")
 gun.set_physics_process(false)
 check(player.weapons.size()==4 and player.current_weapon()==gun,"pistol, knife, Crop Duster and dagger share the player loadout")
 check(not gun.request_fire() and gun.ammo==15,"draw gate prevents a premature shot")
 gun._update(0.4)
 check(gun.request_fire() and gun.ammo==14,"player can fire the restored pistol")
 check(not gun.request_fire() and gun.ammo==14,"repeated input respects shot cooldown")
 gun._update(0.23)
 check(gun.request_fire() and gun.ammo==13,"pistol cycles for another shot")
 gun._update(0.23)
 check(gun.reload() and not gun.request_fire(),"reload blocks firing")
 gun._update(1.44)
 check(gun.ammo==13 and gun.reserve==90,"no ammunition transferred before magazine insertion")
 gun._update(0.02)
 check(gun.ammo==15 and gun.reserve==88,"insertion transfers only the missing rounds")
 player.switch_weapon(1)
 gun._update(0.21)
 check(not gun.active and not gun.visible and gun.ammo==15,"holster hides the pistol and keeps inserted ammunition")
 player.switch_weapon(0)
 gun._update(0.4)
 gun.ammo=5
 gun.reserve=10
 gun.reload()
 gun._update(0.5)
 player.switch_weapon(2)
 gun._update(0.21)
 check(gun.ammo==5 and gun.reserve==10,"early reload cancellation cannot grant ammunition")
 player.switch_weapon(0)
 gun._update(0.4)
 gun.reload()
 gun._update(2.1)
 check(gun.ammo==15 and gun.reserve==0 and gun.state=="idle","limited reserve completes a valid reload")
 check(not gun.reload(),"full magazine prevents reload")
 gun.ammo=0
 check(not gun.request_fire() and gun.ammo==0,"empty pistol cannot shoot")
 check(not gun.reload(),"no reserve prevents empty reload")
 gun._pose()
 var slide: Node3D=gun.get("_slide")
 var native: Node3D=gun.get("_native_slide")
 check(absf(slide.position.z-native.position.z+0.035)<0.0001,"empty pistol visibly locks its slide back")
 gun.ammo=15
 gun._pose()
 check(slide.position.is_equal_approx(native.position),"loaded slide returns to battery")
 player.health=0.0
 check(not gun.request_fire() and not gun.reload(),"dead player cannot shoot or reload")
 var pivot: Node3D=gun.get("_pivot")
 check(pivot.find_children("*","CollisionObject3D",true,false).is_empty(),"pistol adds no world colliders")
 var shadows_off:=true
 for mesh: MeshInstance3D in pivot.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh!=null: shadows_off=shadows_off and mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 check(shadows_off,"pistol and hands cast no world shadows")
 main.free()
 for i in 15: await process_frame
 print("%d failure(s)" % failures)
 quit(1 if failures else 0)
