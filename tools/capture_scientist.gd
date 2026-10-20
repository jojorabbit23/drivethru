extends SceneTree
func _initialize() -> void:
 create_timer(35.0).timeout.connect(func() -> void:quit(1))
 run.call_deferred()
func snap(label: String) -> void:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/scientist_"+label+".png"))
func run() -> void:
 Engine.max_fps=30
 root.size=Vector2i(1280,720)
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 var player: Node3D=main.player
 player.global_position=Vector3(3,.05,.2)
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 for weapon: Node3D in player.weapons:weapon.hide();weapon.set_physics_process(false)
 for child: Node in main.get_children():
  if child is CanvasLayer:child.hide()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var enemy: Node3D=main.spawn_scientist()
 enemy.set_physics_process(false)
 enemy.global_position=Vector3(3,.002,-2.4)
 enemy.rotation.y=PI
 var camera: Camera3D=player.camera
 camera.global_position=Vector3(3,1.05,.2)
 camera.look_at(enemy.global_position+Vector3(0,.9,0))
 camera.fov=60
 for entry: Array in [["idle",.3],["shamble",.35],["swing",.62],["rip",1.05],["climb",.8],["flinch",.18]]:
  enemy.anim.play(entry[0],0)
  enemy.anim.seek(entry[1],true)
  enemy.anim.pause()
  await snap(entry[0])
 enemy.anim.play("idle",0)
 enemy.anim.seek(.3,true)
 enemy.anim.pause()
 for i in 3:await process_frame
 enemy.take_damage(10000,false,{"dir":Vector3(0,0,-1)})
 for i in 4:await process_frame
 assert(not enemy.get_node("Model/Skeleton3D/DetachableHead/Head").visible,"attached head is hidden on death")
 assert(get_nodes_in_group("scientist_heads").size()==1,"one falling head spawned")
 await snap("head_falling")
 for i in 32:await process_frame
 await snap("death")
 for i in 30:await process_frame
 await snap("head_landed")
 for i in 100:await process_frame
 assert(get_nodes_in_group("scientist_heads").is_empty(),"cosmetic head cleans up")
 main.free()
 for i in 3:await process_frame
 print("PASS scientist Vulkan poses, detached head physics and cleanup")
 quit()
