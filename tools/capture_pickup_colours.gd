extends SceneTree
const Pickup = preload("res://pickups/mushroom/mushroom_pickup.gd")
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 Engine.max_fps=30
 root.size=Vector2i(1280,720)
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 var player: Node3D=main.get_node("Player")
 player.set_physics_process(false)
 player.remove_from_group("player")
 for weapon in player.weapons:
  weapon.visible=false
  weapon.set_physics_process(false)
 for child in main.get_children():
  if child is CanvasLayer:child.hide()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var camera: Camera3D=player.get_node("Head/Camera3D")
 camera.global_position=Vector3(2.8,1.5,-1.3)
 camera.look_at(Vector3(2.8,0.5,-3.0))
 camera.fov=65
 var column: int=0
 for kind: String in ["brown","blue","red"]:
  var drop: Node3D=Pickup.new()
  drop.kind=kind
  main.add_child(drop)
  drop.global_position=Vector3(2.1+column*0.7,0.55,-3.0)
  column+=1
 for frame in 10:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/pickup_colours_kitchen.png"))
 main.free()
 print("PASS drop colours captured under actual kitchen lighting")
 quit()
