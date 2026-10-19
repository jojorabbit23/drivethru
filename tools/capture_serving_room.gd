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
 # Art preview omits the game HUD, leaving the actual room and working stations intact.
 for child in main.get_children():
  if child is CanvasLayer:child.hide()
 var camera: Camera3D=player.get_node("Head/Camera3D")
 var views: Array=[ ["serving_room",Vector3(-0.90,1.65,-0.92),Vector3(-4.35,1.4,-3.55)], ["serving_counter",Vector3(-3.20,1.65,-2.25),Vector3(-2.90,1.38,-4.75)], ["serving_stock",Vector3(-3.4,1.65,-1.45),Vector3(-5.55,1.40,-2.25)] ]
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
