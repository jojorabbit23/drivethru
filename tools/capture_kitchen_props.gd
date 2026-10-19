extends SceneTree
func _initialize() -> void:run.call_deferred()
func snap(name: String) -> void:
 for i in 5:
  Engine.max_fps=30
  await process_frame
 await RenderingServer.frame_post_draw
 var error: Error=root.get_texture().get_image().save_png("res://docs/previews/"+name+".png")
 assert(error==OK)
func run() -> void:
 root.size=Vector2i(1280,720)
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 var player: Node3D=main.get_node("Player")
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 for weapon in player.weapons:weapon.hide();weapon.set_physics_process(false)
 for child in main.get_children():
  if child is CanvasLayer:child.hide()
 var camera: Camera3D=player.camera
 camera.global_position=Vector3(4.2,1.8,-1.6)
 camera.look_at(Vector3(5.2,1.05,-0.4))
 await snap("grinder_kitchen")
 var grinder: Node3D=get_first_node_in_group("mushroom_grinder")
 grinder.play_deposit(2)
 grinder.set_process(false)
 grinder.advance(0.8)
 camera.global_position=Vector3(4.75,1.56,-0.9)
 camera.look_at(Vector3(5.28,1.22,-0.42))
 await snap("grinder_processing")
 grinder.advance(1.3)
 await snap("grinder_tray")
 var feedback: Node=player.get_node("Presentation")
 feedback.play_distant()
 assert(feedback.distant_voice.bus==&"Ambience")
 assert(feedback.distant_voice.global_position.distance_to(player.global_position)>10.0)
 print("PASS distant cue uses ambience bus and an exterior position")
 main.free()
 quit()
