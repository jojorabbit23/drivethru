# Bounded eight-second demo of the new pump gun, independent of purchase wiring.
extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,720)
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 var player: CharacterBody3D=main.get_node("Player")
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 player.global_position=Vector3(1.4,0.05,-1.4)
 player.rotation.y=-PI/2
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 for weapon in player.weapons:weapon.set_active(false);weapon.hide();weapon.set_physics_process(false)
 for child in main.get_children():
  if child is CanvasLayer:child.hide()
 var sg: Node3D=load("res://weapons/shotgun/shotgun_weapon.gd").new()
 player.camera.add_child(sg)
 sg.owner=player
 sg.set_active(true)
 sg.set_physics_process(false)
 for frame in 240:
  Engine.max_fps=30
  if frame in [20,60,190]:sg.shoot()
  if frame==100:
   sg.mag=2
   sg.reload()
  sg._physics_process(1.0/30.0)
  await process_frame
  OS.delay_usec(33334)
 main.free()
 for i in 3:await process_frame
 quit()
