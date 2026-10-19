extends SceneTree
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
 print("PASS " if ok else "FAIL ", label)
 if not ok: failures += 1
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 var player: CharacterBody3D=main.player
 var gun: Node3D=player.get_node("Head/Camera3D/TestGun")
 gun.set_physics_process(false)
 check(player.weapons.size()==4 and player.current_weapon()==gun,"OpenCode pistol starts in retained four-weapon loadout")
 check(gun._pivot.visible and gun._view_anim.has_animation("reload"),"new model and reload animation load")
 var slide: MeshInstance3D=gun._pivot.find_child("pistol_slide",true,false)
 var finish: ShaderMaterial=slide.mesh.surface_get_material(0)
 check(finish.get_shader_parameter("textured") and finish.get_shader_parameter("albedo_tex")!=null,"original textured pistol replaces stock gun in new hands")
 check(not gun.request_fire() and gun.mag==12,"draw gate prevents premature shot")
 gun._physics_process(0.4)
 check(gun.request_fire() and gun.mag==11,"pistol fires one round")
 check(not gun.request_fire() and gun.mag==11,"input respects cooldown")
 gun._physics_process(0.23)
 check(gun.request_fire() and gun.mag==10,"pistol cycles for another shot")
 gun.reload()
 check(gun.is_reloading() and not gun.request_fire(),"reload blocks firing")
 gun._physics_process(0.5)
 check(gun.mag==10 and gun.reserve==36,"reload has no early ammo grant")
 check(gun._support.position.distance_to(gun._support_rest.origin)>0.1,"support hand releases the grip during reload")
 player.switch_weapon(1)
 check(not gun.active and not gun._pivot.visible,"holstering hides the viewmodel")
 gun._physics_process(1.2)
 check(gun.mag==10 and gun.reserve==36,"holstering cancels incomplete reload")
 player.switch_weapon(0)
 gun._physics_process(0.4)
 gun.reload()
 gun._physics_process(1.2)
 check(gun.mag==12 and gun.reserve==34,"reload transfers only missing rounds")
 gun.mag=5
 gun.reserve=2
 gun.reload()
 gun._physics_process(1.2)
 check(gun.mag==7 and gun.reserve==0,"limited reserve conserves ammo")
 gun.mag=1
 gun.reserve=3
 gun.shoot()
 check(gun.mag==0 and gun.is_reloading(),"last shot starts automatic reload")
 check(gun._view_anim.current_animation=="reload","last shot does not overwrite reload clip with fire")
 gun._physics_process(1.2)
 check(gun.mag==3 and gun.reserve==0,"empty reload uses remaining reserve")
 gun.mag=0
 check(not gun.request_fire() and not gun.is_reloading(),"empty pistol with no reserve cannot fire")
 gun.mag=12
 player.health=0.0
 check(not gun.request_fire(),"dead player cannot fire")
 gun.reload()
 check(not gun.is_reloading(),"dead player cannot reload")
 check(gun._pivot.find_children("*","CollisionObject3D",true,false).is_empty(),"viewmodel adds no player colliders")
 main.free()
 for i in 15: await process_frame
 print("%d failure(s)" % failures)
 quit(1 if failures else 0)
