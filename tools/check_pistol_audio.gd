extends SceneTree
func _initialize() -> void:
 create_timer(20).timeout.connect(func() -> void:quit(1))
 run.call_deferred()
func run() -> void:
 Engine.max_fps=30
 root.size=Vector2i(960,540)
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 main.get_node("KitchenRadio").source.stop()
 var player: Node=main.player
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var gun: Node=player.get_node("Head/Camera3D/TestGun")
 gun.set_physics_process(false)
 gun._draw_t=0.0
 await create_timer(.6).timeout
 var capture:=AudioEffectCapture.new()
 capture.buffer_length=5.0
 var bus: int=AudioServer.get_bus_index("Effects")
 AudioServer.add_bus_effect(bus,capture)
 for i in 8:
  gun._cooldown=0.0
  gun.request_fire()
  assert(gun._shot_index==i+1,"successful shot advances audio")
  assert(gun._shot_voices[i%4].stream==gun.shot_sounds[i%gun.shot_sounds.size()],"starter plays its original shot")
  assert(gun._shot_voices[i%4].playing,"selected clip plays")
  gun.request_fire()
  assert(gun._shot_index==i+1,"cooldown does not play another clip")
  await create_timer(.22).timeout
 await create_timer(.8).timeout
 var frames: PackedVector2Array=capture.get_buffer(capture.get_frames_available())
 var peak:=0.0
 for frame in frames: peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
 assert(peak>.01 and peak<.99,"audible and unclipped")
 gun.set_active(false)
 assert(gun._shot_voices.all(func(v: AudioStreamPlayer)->bool:return not v.playing),"holster stops sound")
 print("Starter pistol audio: original sample, cooldown, holster, peak=",peak,"; 0 failure(s)")
 quit(0)

