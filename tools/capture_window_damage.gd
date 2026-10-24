extends SceneTree
func _initialize() -> void:
 create_timer(20).timeout.connect(func()->void:quit(1))
 run.call_deferred()
func run() -> void:
 Engine.max_fps=30
 root.size=Vector2i(960,540)
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 main.player.set_physics_process(false)
 main.player.global_position=Vector3(-3,0,3)
 var win: Node3D=main.get_node("ShopGreybox/Windows/Window_A")
 for b in win.boards: b.collision_layer=0;b.hide()
 var z: CharacterBody3D=load("res://enemies/shambler/shambler.tscn").instantiate()
 z.setup(win,main.player)
 main.add_child(z)
 z.global_position=win.breach_point()
 var camera:=Camera3D.new()
 main.add_child(camera)
 camera.global_position=win.repair_point()+Vector3(-1.3,1.5,-1.2)
 camera.look_at(win.global_position)
 camera.current=true
 z._start_climb()
 await create_timer(.55).timeout
 await process_frame
 root.get_texture().get_image().save_png("res://docs/previews/window_entry_damage.png")
 print("Saved window entry capture")
 quit()
