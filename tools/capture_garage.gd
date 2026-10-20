extends SceneTree
func _initialize() -> void:
 create_timer(35).timeout.connect(func() -> void:quit(1))
 run.call_deferred()
func snap(name: String) -> void:
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/garage_"+name+".png"))
func run() -> void:
 Engine.max_fps=30
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main);main.hatch.auto=false
 var player: Node3D=main.player;player.set_physics_process(false);player.set_process_unhandled_input(false)
 for weapon: Node3D in player.weapons:weapon.hide();weapon.set_physics_process(false)
 for child: Node in main.get_children():
  if child is CanvasLayer:child.hide()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var camera: Camera3D=player.camera
 camera.global_position=Vector3(3,1.6,3.4);camera.look_at(Vector3(3,1.4,4.9));camera.fov=70
 await snap("locked")
 var garage: Node3D=main.shop.get_node("Garage")
 main.economy.cash=250;garage.interact(player)
 for i in 20:await process_frame
 camera.global_position=Vector3(3.1,1.65,5.65);camera.look_at(Vector3(2.7,1.05,9.75));camera.fov=82
 await snap("interior")
 camera.global_position=Vector3(4.4,1.5,8.25);camera.look_at(Vector3(1.5,.7,10.0));camera.fov=65
 await snap("cruiser")
 camera.global_position=Vector3(4.3,1.6,10.3);camera.look_at(Vector3(.65,1.1,7.3));camera.fov=75
 await snap("shelves")
 camera.global_position=Vector3(1.1,1.6,7.0);camera.look_at(Vector3(5.9,1.4,8.0));camera.fov=75
 await snap("barricade")
 var env: Environment=main.get_node("WorldEnvironment").environment.duplicate();env.fog_enabled=false;env.ambient_light_color=Color(.8,.85,.9);env.ambient_light_energy=1.4;main.get_node("WorldEnvironment").environment=env
 main.get_node("Moonlight").light_color=Color(1,.95,.85);main.get_node("Moonlight").light_energy=2
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=42;camera.global_position=Vector3(28,40,38);camera.look_at(Vector3(0,0,3));camera.far=150
 await snap("exterior")
 main.free();quit()
