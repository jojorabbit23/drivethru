extends SceneTree
func _initialize() -> void:
 create_timer(35).timeout.connect(func()->void:quit(1))
 run.call_deferred()
func run() -> void:
 Engine.max_fps=30;root.size=Vector2i(1440,810)
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main)
 main.player.set_physics_process(false)
 for weapon in main.player.weapons:weapon.visible=false;weapon.set_physics_process(false)
 for child in main.get_children():
  if child is CanvasLayer:child.hide()
 var camera: Camera3D=main.player.get_node("Head/Camera3D");camera.fov=78
 var views: Array=[
 ["decor_kitchen",Vector3(3,1.7,-1),Vector3(2.7,1.4,-4.6)],
 ["decor_kitchen_notices",Vector3(2,1.7,-3.8),Vector3(4,1.5,-.2)],
 ["decor_serving",Vector3(-2,1.7,-.7),Vector3(-3.4,1.5,-4.6)],
 ["decor_office",Vector3(-3,1.7,1),Vector3(-2.8,1.4,4.5)],
 ["decor_freezer",Vector3(2.3,1.7,1.1),Vector3(3.6,1.3,4.5)],
 ["decor_lane",Vector3(-15,2.4,-5.4),Vector3(-7,1.8,-6)],
 ["decor_roof",Vector3(-5,4,-10),Vector3(-3,4,-4.8)]]
 for view: Array in views:
  camera.global_position=view[1];camera.look_at(view[2])
  for i in 10:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/previews/"+view[0]+".png")
 var decor: Node3D=main.get_node("BuildingDecorations")
 decor.apply_wear(.85);decor.update_shift(3)
 for view: Array in [["decor_worn_roof",Vector3(-5,4,-10),Vector3(-3,4,-4.8)],["decor_worn_poster",Vector3(-3.8,1.8,-1.4),Vector3(-5.7,1.8,-1.4)],["decor_employee",Vector3(-2,2.25,3.8),Vector3(-2,2.3,4.7)]]:
  camera.global_position=view[1];camera.look_at(view[2])
  for i in 8:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/previews/"+view[0]+".png")
 main.free();await process_frame;quit()
