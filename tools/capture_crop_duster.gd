# Bounded 30 FPS screenshots; samples animation directly instead of running uncapped fixed-FPS.
extends SceneTree
var main: Node3D
var gun: Node3D
func _initialize() -> void: run.call_deferred()
func snap(label: String, state: String, clock: float, recoil: float=0.0) -> void:
 if state=="holster": gun.set_active(false)
 gun.set("state",state)
 gun.set("clock",clock)
 gun.set("recoil",recoil)
 gun.set("cooldown",0.40 if recoil>0.0 else 0.0)
 gun.call("_pose",0.0)
 for i in 3:
  Engine.max_fps=30
  await process_frame
  OS.delay_usec(33334)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/crop_"+label+".png"))
 print("saved crop_",label)
func run() -> void:
 root.size=Vector2i(1280,720)
 main=load("res://main.tscn").instantiate()
 main.set("auto_spawn",false)
 root.add_child(main)
 var player: CharacterBody3D=main.get_node("Player")
 player.set_process_unhandled_input(false)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 player.global_position=Vector3(1.4,0.05,-1.4)
 player.rotation.y=-PI/2
 player.switch_weapon(2)
 gun=player.get_node("Head/Camera3D/CropDuster")
 gun.set_physics_process(false)
 await snap("draw","draw",0.2)
 await snap("idle","idle",0.0)
 gun.set("aim_weight",1.0)
 await snap("aim","idle",0.0)
 gun.set("aim_weight",0.0)
 await snap("fire","idle",0.0,1.0)
 gun.loaded[0]=false
 gun.loaded[1]=false
 for t in [0.5,1.0,1.7,1.9,2.2,2.4,3.1]:
  await snap("reload_%02d" % int(t*10),"reload",t)
 gun.loaded[0]=true
 gun.loaded[1]=true
 await snap("inspect","inspect",1.6)
 await snap("holster","holster",0.12)
 main.free()
 quit()
