extends SceneTree
func _initialize() -> void:
 create_timer(40.0).timeout.connect(func() -> void: quit(1))
 run.call_deferred()
func run() -> void:
 Engine.max_fps=30
 root.size=Vector2i(1280,720)
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 var player: Node3D=main.player
 player.set_physics_process(false)
 player.set_process(false)
 player.set_process_unhandled_input(false)
 for weapon: Node3D in player.weapons:
  weapon.hide()
  weapon.set_physics_process(false)
 for child: Node in main.get_children():
  if child is CanvasLayer:child.hide()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var camera: Camera3D=player.camera
 camera.fov=58
 var views: Array=[["north",Vector3(2.9,1.6,4.35),Vector3(2.9,1.6,0.08)],["south",Vector3(2.9,1.6,0.72),Vector3(2.9,1.6,4.7)],["east",Vector3(0.4,1.6,2.4),Vector3(5.7,1.6,2.4)],["west",Vector3(5.1,1.6,2.4),Vector3(0.08,1.6,2.4)]]
 for view: Array in views:
  camera.global_position=view[1]
  camera.look_at(view[2])
  for i in 12:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/fridge_room_"+view[0]+".png"))
 main.free()
 quit()

