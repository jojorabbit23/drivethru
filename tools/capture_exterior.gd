extends SceneTree
func _initialize() -> void:
 create_timer(45).timeout.connect(func()->void:quit(1))
 run.call_deferred()
func run() -> void:
 Engine.max_fps=30
 root.size=Vector2i(1280,720)
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main);main.hatch.auto=false
 main.player.set_physics_process(false);main.player.set_process_unhandled_input(false)
 for weapon: Node3D in main.player.weapons:weapon.hide();weapon.set_physics_process(false)
 for child in main.get_children():
  if child is CanvasLayer:child.hide()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.far=500;camera.fov=74
 for view: Array in [["overview",Vector3(31,23,34),Vector3(0,0,-7)],["north",Vector3(0,7,4),Vector3(7,5,-40)],["east",Vector3(0,7,0),Vector3(55,5,-8)],["south",Vector3(0,7,0),Vector3(0,6,65)],["west",Vector3(0,7,0),Vector3(-50,6,-12)],["kitchen_window",Vector3(4.5,1.65,-2.4),Vector3(42,3,-3)],["hatch",Vector3(-3,1.65,-4.5),Vector3(8,2,-29)]]:
  camera.position=view[1];camera.look_at(view[2])
  for i in 10:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/previews/exterior_"+view[0]+".png")
  print("Captured ",view[0]," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)," objects=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)," primitives=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
 quit()
