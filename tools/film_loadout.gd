# 16-second capped visual demonstration of the combined weapon loadout.
extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,720)
 var main: Node3D=load("res://main.tscn").instantiate()
 main.set("auto_spawn",false)
 root.add_child(main)
 var player: CharacterBody3D=main.get_node("Player")
 player.set_process_unhandled_input(false)
 player.set_physics_process(false)
 player.global_position=Vector3(1.4,0.05,-1.4)
 player.rotation.y=-PI/2
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var pistol: Node3D=player.get_node("Head/Camera3D/TestGun")
 var crop: Node3D=player.get_node("Head/Camera3D/CropDuster")
 var knife: Node3D=player.get_node("Head/Camera3D/Knife")
 pistol.set_physics_process(false)
 crop.set_physics_process(false)
 for frame in 480:
  Engine.max_fps=30
  if frame==18 or frame==28: pistol.request_fire()
  if frame==40: pistol.reload()
  if frame==110: player.get_node("Head").rotation=Vector3.ZERO
  if frame==140: player.switch_weapon(1)
  if frame==160: knife.request("slash")
  if frame==185: knife.request("stab")
  if frame==215: player.switch_weapon(2)
  if frame==234 or frame==250: crop.shoot()
  if frame==265: crop.reload()
  if frame==380:
   crop.state="inspect"
   crop.clock=0.0
  pistol._physics_process(1.0/30.0)
  crop._update(1.0/30.0)
  await process_frame
  OS.delay_usec(33334)
 main.free()
 quit()
