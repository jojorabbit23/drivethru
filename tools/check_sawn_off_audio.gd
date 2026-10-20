# Bounded native check of the actual fire path and Effects-bus recording.
extends SceneTree
func _initialize() -> void:run.call_deferred()
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
	main.economy.cash=90
	assert(main.terminal.buy_sawn_off(player))
	var gun: Node=player.get_node("Head/Camera3D/CropDuster")
	gun.set_physics_process(false)
	gun._update(0.5)
	await create_timer(0.6).timeout
	var capture:=AudioEffectCapture.new()
	capture.buffer_length=6.0
	var bus: int=AudioServer.get_bus_index("Effects")
	AudioServer.add_bus_effect(bus,capture)
	assert(gun.shoot(),"actual sawn-off fire succeeds")
	await create_timer(0.15).timeout
	assert(gun._sound.playing and gun._sound.stream==gun.SHOT_SOUND,"fire plays the enhanced owner sample")
	var first_voice: AudioStreamPlayer=gun._sound
	await create_timer(0.28).timeout
	gun._update(0.43)
	assert(gun.shoot(),"second barrel fires while first tail is still audible")
	assert(gun._sound!=first_voice and first_voice.playing,"pooled voices preserve overlapping ringing tails")
	await create_timer(4.2).timeout
	var frames: PackedVector2Array=capture.get_buffer(capture.get_frames_available())
	var peak: float=0.0
	var bytes:=PackedByteArray()
	bytes.resize(frames.size()*4)
	for i in frames.size():
		peak=maxf(peak,maxf(absf(frames[i].x),absf(frames[i].y)))
		bytes.encode_s16(i*4,roundi(clampf(frames[i].x,-1,1)*32767))
		bytes.encode_s16(i*4+2,roundi(clampf(frames[i].y,-1,1)*32767))
	assert(peak>0.01 and peak<0.99,"native fire emits audible, unclipped Effects-bus audio")
	var recording:=AudioStreamWAV.new()
	recording.format=AudioStreamWAV.FORMAT_16_BITS
	recording.mix_rate=roundi(AudioServer.get_mix_rate())
	recording.stereo=true
	recording.data=bytes
	assert(recording.save_to_wav(ProjectSettings.globalize_path("res://docs/previews/sawn_off_deep_blast_ingame.wav"))==OK)
	print("PASS native enhanced sawn-off fire; recorded peak=",peak)
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	main.free()
	for i in 3:await process_frame
	quit()
