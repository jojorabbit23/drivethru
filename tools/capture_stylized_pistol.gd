extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 Engine.max_fps=30
 root.size=Vector2i(1280,720)
 var vm: Node3D=load("res://weapons/pistol/pistol_viewmodel.tscn").instantiate()
 root.add_child(vm)
 vm.get_node("Model/GripSocket").hide()
 vm.get_node("Model/SupportSocket").hide()
 var anim: AnimationPlayer=vm.find_child("AnimationPlayer",true,false)
 var camera:=Camera3D.new()
 camera.near=0.001
 root.add_child(camera)
 camera.position=Vector3(-0.55,0.06,-0.12)
 camera.look_at(Vector3(0,-0.04,-0.07))
 camera.fov=43
 var env:=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color(.08,.1,.13)
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color.WHITE
 env.environment.ambient_light_energy=.8
 root.add_child(env)
 var light:=DirectionalLight3D.new()
 root.add_child(light)
 light.rotation_degrees=Vector3(-45,-35,0)
 for view: Array in [["ready","RESET",0.0],["hammer_back","fire",0.05],["hammer_forward","fire",0.012],["magazine_out","reload",0.7],["magazine_seated","reload",1.13]]:
  anim.play(view[1],0.0)
  anim.seek(float(view[2]),true)
  anim.pause()
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/stylized_pistol_"+view[0]+".png"))
 print("PASS pistol mechanical poses captured")
 quit()
