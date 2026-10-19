# Bounded, paced first-person pistol renders.
extends SceneTree
var main: Node3D
var pistol: Node3D
func _initialize() -> void: run.call_deferred()
func snap(label: String, state: String, t: float) -> void:
 pistol.state=state
 pistol.clock=t
 pistol._pose()
 var flash: OmniLight3D=pistol.get("_flash")
 flash.visible=state=="fire"
 for i in 3:
  Engine.max_fps=30
  await process_frame
  OS.delay_usec(33334)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/pistol_"+label+".png"))
 print("saved pistol_",label)
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
 pistol=player.get_node("Head/Camera3D/TestGun")
 pistol.set_physics_process(false)
 await snap("draw","draw",0.2)
 await snap("idle","idle",0.0)
 await snap("fire","fire",0.04)
 for t in [0.5,1.0,1.4,1.7]: await snap("reload_%02d" % int(t*10),"reload",t)
 await snap("inspect","inspect",1.6)
 pistol.aim_weight=1.0
 await snap("aim","idle",0.0)
 pistol.aim_weight=0.0
 pistol.ammo=0
 await snap("empty","idle",0.0)
 main.free()
 quit()
