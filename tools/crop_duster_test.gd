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
 var hp: float=z.health
 gun.shoot()
 check(z.health<hp,"pellet cone damages the target under the crosshair")
 z.queue_free()
 await process_frame
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
 player.health=0.0
 gun.cooldown=0.0
 check(not gun.shoot() and not gun.reload(),"dead player cannot fire or reload")
 var pivot: Node3D=gun.get("_pivot")
 check(pivot.find_children("*","CollisionObject3D",true,false).is_empty(),"held model adds no world colliders")
 var shadows_off:=true
 for mesh: MeshInstance3D in pivot.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh!=null: shadows_off=shadows_off and mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 check(shadows_off,"held meshes cast no world shadows")
 main.free()
 for i in 3: await process_frame
 print("%d failure(s)" % failures)
 quit(1 if failures else 0)
