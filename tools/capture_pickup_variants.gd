extends SceneTree
const Pickup=preload("res://pickups/mushroom/mushroom_pickup.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
 Engine.max_fps=30;root.size=Vector2i(1280,720)
 var world:=Node3D.new();root.add_child(world)
 var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0.8,2.7);camera.look_at(Vector3(0,0.35,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.2
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0.04,0.07,0.10);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=0.6;world.add_child(env)
 var sun:=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-35,-30,0)
 seed(17)
 var col: int=0
 for kind: String in ["brown","blue","red"]:
  var seen: Array=[]
  for attempt in 32:
   var drop: Node3D=Pickup.new();drop.kind=kind;world.add_child(drop);drop.set_physics_process(false)
   if seen.has(drop._model.mesh):drop.free();continue
   seen.append(drop._model.mesh)
   drop.position=Vector3((col-1)*0.65,0.65-(seen.size()-1)*0.55,0)
   drop.rotation_degrees.y=20
   if seen.size()==2:break
  assert(seen.size()==2,"Both actual randomized variants should appear")
  var label:=Label3D.new();world.add_child(label);label.position=Vector3((col-1)*0.65,-0.22,0);label.text="YELLOW" if kind=="red" else ("COMMON" if kind=="brown" else "BLUE");label.font_size=35;label.pixel_size=0.002;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true
  col+=1
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/non_morel_pickups.png"))
 print("PASS six randomized category-matched drop variants rendered")
 quit()
