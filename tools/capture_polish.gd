extends SceneTree
func _initialize() -> void:run.call_deferred()
func settle(frames: int=8) -> void:
 for i in frames:
  Engine.max_fps=30
  await process_frame
func shot(name: String) -> void:
 await settle()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/previews/"+name+".png")
func run() -> void:
 root.size=Vector2i(1280,720)
 var menu: Control=load("res://ui/menu/menu.tscn").instantiate()
 root.add_child(menu)
 menu.video.stop()
 menu.activate(3)
 await shot("polish_title_settings")
 menu.free()
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 var player: CharacterBody3D=main.get_node("Player")
 var feedback: Node=player.get_node("Presentation")
 var pause: CanvasLayer=player.get_node("PauseMenu")
 await settle()
 var key:=InputEventKey.new()
 key.physical_keycode=KEY_F1
 key.pressed=true
 feedback._unhandled_key_input(key)
 await shot("polish_controls")
 feedback._unhandled_key_input(key)
 pause.open()
 await shot("polish_pause")
 pause.show_settings()
 await shot("polish_settings")
 pause.resume()
 await create_timer(0.15).timeout
 player.set_physics_process(false)
 for weapon in player.weapons:weapon.hide();weapon.set_physics_process(false)
 var camera: Camera3D=player.get_node("Head/Camera3D")
 camera.global_position=Vector3(1,1.5,-2.4)
 camera.look_at(Vector3(-2,1,-2.4))
 var shambler: Node3D=load("res://enemies/shambler/shambler.tscn").instantiate()
 main.add_child(shambler)
 shambler.global_position=Vector3(-1.5,0,-3.1)
 shambler.rotation.y=PI/2
 shambler.set_physics_process(false)
 var scuttler: Node3D=load("res://enemies/scuttler/scuttler.tscn").instantiate()
 main.add_child(scuttler)
 scuttler.global_position=Vector3(-1.4,0,-1.8)
 scuttler.rotation.y=PI/2
 scuttler.set_physics_process(false)
 for child in main.get_children():
  if child is CanvasLayer:child.hide()
 await shot("polish_enemies")
 for i in 20:feedback.effect("tile",player.global_position,-20.0)
 assert(feedback.voices==8,"voice cap")
 await create_timer(0.4).timeout
 assert(feedback.voices==0,"completed sounds released")
 print("PASS native audio voice cap and cleanup")
 main.free()
 quit()
