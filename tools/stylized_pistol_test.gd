extends SceneTree
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func pose(anim: AnimationPlayer,clip: String,time: float) -> void:
 anim.play(clip,0.0)
 anim.seek(time,true)
 anim.pause()
func run() -> void:
 var vm: Node3D=load("res://weapons/pistol/pistol_viewmodel.tscn").instantiate()
 root.add_child(vm)
 var anim: AnimationPlayer=vm.find_child("AnimationPlayer",true,false)
 var hammer: Node3D=vm.find_child("pistol_hammer",true,false)
 var magazine: Node3D=vm.find_child("pistol_magazine",true,false)
 var slide: Node3D=vm.find_child("pistol_slide",true,false)
 var frame: Node3D=vm.find_child("pistol_frame",true,false)
 pose(anim,"RESET",0)
 var mag_rest: Vector3=magazine.position
 var frame_rest: Transform3D=frame.transform
 pose(anim,"fire",0.012)
 var forward_angle: float=hammer.rotation.x
 pose(anim,"fire",0.05)
 check(absf(hammer.rotation.x-forward_angle)>0.4,"hammer draws back independently after ignition")
 check(slide.position.z < -0.025 and frame.transform.is_equal_approx(frame_rest),"slide cycles while grip frame stays fixed")
 pose(anim,"fire",0.22)
 check(slide.position.length()<0.001 and magazine.position.is_equal_approx(mag_rest),"shot returns slide and preserves seated magazine")
 pose(anim,"reload",0.7)
 check(magazine.position.distance_to(mag_rest)>0.15,"reload removes the complete magazine")
 check(magazine.get_node("MagazineBody") is MeshInstance3D,"extracted magazine includes the concealed body")
 check(slide.position.length()<0.001,"slide stays seated during magazine exchange without interpolation overshoot")
 pose(anim,"reload",1.3)
 check(magazine.position.is_equal_approx(mag_rest) and slide.position.z < -0.025,"fresh magazine seats before slide rack")
 pose(anim,"reload",1.6)
 check(magazine.position.is_equal_approx(mag_rest) and slide.position.length()<0.001,"reload ends with all parts seated")
 for name: String in ["pistol_frame","pistol_slide","pistol_hammer","pistol_magazine"]:
  var mesh: MeshInstance3D=vm.find_child(name,true,false)
  var mat: ShaderMaterial=mesh.mesh.surface_get_material(0)
  check(mat.get_shader_parameter("textured") and mat.get_shader_parameter("albedo_tex")!=null,name+" preserves supplied texture")
 vm.free()
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 main.economy.cash=180
 check(main.terminal.buy_desert_eagle(main.player),"gold pistol is purchased separately")
 var gun: Node3D=main.player.weapon_named("DESERT EAGLE")
 gun.set_physics_process(false)
 gun._physics_process(0.4)
 gun.mag=5
 gun.reload()
 gun._view_anim.seek(0.7,true)
 var live_mag: Node3D=gun._pivot.find_child("pistol_magazine",true,false)
 gun.set_active(false)
 check(live_mag.position.is_equal_approx(mag_rest) and gun.mag==5,"holstering resets rig and cancels reload without granting ammo")
 gun.set_active(true)
 gun.reload()
 gun._view_anim.seek(0.7,true)
 gun._physics_process(1.5)
 check(live_mag.position.is_equal_approx(mag_rest) and gun.mag==7 and gun.reserve==19,"completed reload restores rig and transfers exact ammo")
 main.free()
 for i in 3:await process_frame
 print("%d failure(s)"%failures)
 quit(1 if failures else 0)
