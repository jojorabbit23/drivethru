# Bounded demonstration. Use --fixed-fps 30 --write-movie <path.avi>.
# A wall-clock delay also caps movie capture workload; fixed-fps alone does not.
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
 var gun: Node3D=player.get_node("Head/Camera3D/CropDuster")
 gun.set_physics_process(false)
 player.switch_weapon(2)
 for frame in 285:
  Engine.max_fps=30
  if frame==20 or frame==36: gun.shoot()
  if frame==51: gun.reload()
  if frame==162:
   gun.state="inspect"
   gun.clock=0.0
  if frame==267: player.switch_weapon(0)
  gun._update(1.0/30.0)
  await process_frame
  OS.delay_usec(33334)
 main.free()
 quit()
