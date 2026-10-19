extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1600,900)
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 var player: Node3D=main.get_node("Player")
 player.set_physics_process(false)
 for weapon in player.weapons:weapon.visible=false;weapon.set_physics_process(false)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 for child in main.get_children():
  if child is CanvasLayer:child.hide()
 var camera: Camera3D=player.get_node("Head/Camera3D")
 var views: Array=[ ["kitchen_cooking",Vector3(2.8,1.68,-1.25),Vector3(2.85,1.38,-4.6)], ["kitchen_sink",Vector3(3.0,1.68,-3.80),Vector3(3.0,1.40,-0.20)], ["kitchen_prep",Vector3(3.60,1.65,-2.60),Vector3(1.20,1.30,-4.55)] ]
 for view: Array in views:
  camera.global_position=view[1]
  camera.look_at(view[2])
  camera.fov=75
  for i in 8:
   Engine.max_fps=30
   await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/"+view[0]+".png"))
 main.free()
 quit()
