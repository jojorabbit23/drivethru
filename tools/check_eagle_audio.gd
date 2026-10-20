extends SceneTree
func _initialize() -> void:
 create_timer(25).timeout.connect(func()->void:quit(1))
 run.call_deferred()
func run() -> void:
 Engine.max_fps=30
 root.size=Vector2i(960,540)
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 main.get_node("KitchenRadio").source.stop()
 main.player.set_physics_process(false)
 main.player.set_process_unhandled_input(false)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 main.economy.cash=180
 assert(main.terminal.buy_desert_eagle(main.player))
 var gun: Node=main.player.weapon_named("DESERT EAGLE")
 gun.set_physics_process(false)
 assert(gun._slide_voice.playing,"draw plays slide sample")
 assert(gun._view_anim.current_animation=="rack","draw racks visible slide")
 await create_timer(1.0).timeout
 gun._draw_t=0.0
 var capture:=AudioEffectCapture.new()
 capture.buffer_length=8.0
 var bus: int=AudioServer.get_bus_index("Effects")
 AudioServer.add_bus_effect(bus,capture)
 for i in 3:
  gun._cooldown=0.0
  assert(gun.request_fire())
  assert(gun._shot_voices[i%4].stream==gun.shot_sounds[0] and gun._shot_voices[i%4].playing,"fire plays gunshot, not slide")
  assert(not gun._slide_voice.playing,"shot does not retrigger mechanical sample")
  await create_timer(.32).timeout
 await create_timer(1.8).timeout
 gun.reload()
 gun._physics_process(.9)
 assert(not gun._slide_voice.playing,"no rack during magazine removal")
 gun._physics_process(.15)
 assert(gun._slide_voice.playing and gun._slide_voice.stream==gun.slide_sound,"reload rack plays slide sample")
 await create_timer(.9).timeout
 var frames: PackedVector2Array=capture.get_buffer(capture.get_frames_available())
 var peak:=0.0
 var bytes:=PackedByteArray()
 bytes.resize(frames.size()*4)
 for i in frames.size():
  peak=maxf(peak,maxf(absf(frames[i].x),absf(frames[i].y)))
  bytes.encode_s16(i*4,roundi(clampf(frames[i].x,-1,1)*32767))
  bytes.encode_s16(i*4+2,roundi(clampf(frames[i].y,-1,1)*32767))
 assert(peak>.01 and peak<.99,"audible and unclipped")
 var recording:=AudioStreamWAV.new()
 recording.format=AudioStreamWAV.FORMAT_16_BITS
 recording.stereo=true
 recording.mix_rate=int(AudioServer.get_mix_rate())
 recording.data=bytes
 recording.save_to_wav("res://docs/previews/desert_eagle_audio.wav")
 gun.set_active(false)
 assert(not gun._slide_voice.playing,"holster cancels rack")
 print("Eagle audio: 0 failure(s), peak=",peak)
 quit()
