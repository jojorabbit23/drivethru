extends SceneTree
var sg: Node3D
var main: Node3D
func _initialize() -> void:run.call_deferred()
func snap(name: String,cycle: float=0.0,loading: bool=false,shell_t: float=0.0) -> void:
 sg._cycle=cycle
 sg._loading=loading
 sg._shell_t=shell_t
 sg._flash.visible=name=="fire"
 sg._flash.light_energy=3.0 if name=="fire" else 0.0
 sg._flash_mesh.visible=name=="fire"
 for i in 8:
  sg._animate(1.0/30.0)
  Engine.max_fps=30
  await process_frame
 await RenderingServer.frame_post_draw
 var error: Error=root.get_texture().get_image().save_png("res://docs/previews/new_shotgun_"+name+".png")
 assert(error==OK)
func run() -> void:
 root.size=Vector2i(1280,720)
 main=load("res://main.tscn").instantiate()
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
 sg=load("res://weapons/shotgun/shotgun_weapon.gd").new()
 player.camera.add_child(sg)
 sg.owner=player
 sg.set_active(true)
 sg._draw_t=0.0
 sg.set_physics_process(false)
 await snap("idle")
 await snap("pump",0.38)
 await snap("fire",0.74)
 await snap("load",0.0,true,0.22)
 await snap("load_start",0.0,true,0.04)
 main.free()
 for i in 3:await process_frame
 quit()
