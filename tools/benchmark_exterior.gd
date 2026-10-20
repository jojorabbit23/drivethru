extends SceneTree
func _initialize() -> void:
 create_timer(40).timeout.connect(func()->void:quit(1))
 run.call_deferred()
func run() -> void:
 Engine.max_fps=0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 root.size=Vector2i(1280,720)
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main);main.hatch.auto=false
 main.player.set_physics_process(false);main.player.set_process_unhandled_input(false)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.far=500
 camera.position=Vector3(0,7,4);camera.look_at(Vector3(7,5,-40))
 var scenery: Node3D=main.get_node("ExteriorSurroundings")
 for enabled in [false,true]:
  scenery.visible=enabled
  for i in 60:await process_frame
  var samples: Array[float]=[]
  var previous: int=Time.get_ticks_usec()
  for i in 120:
   await process_frame
   var now: int=Time.get_ticks_usec()
   samples.append(float(now-previous)/1000.0);previous=now
  samples.sort()
  print("EXTERIOR ",enabled," median_ms=",samples[60]," p95_ms=",samples[114]," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
 quit()
