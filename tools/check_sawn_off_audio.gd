# Bounded native check of the actual fire path and Effects-bus recording.
extends SceneTree
func _initialize() -> void:
	create_timer(25).timeout.connect(func() -> void:quit(1))
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
	main.economy.cash=90
	assert(main.terminal.buy_sawn_off(player))
	var gun: Node=player.get_node("Head/Camera3D/CropDuster")
	gun.set_physics_process(false)
	gun._update(0.5)
	await create_timer(0.6).timeout
	var capture:=AudioEffectCapture.new()
	capture.buffer_length=12.0
	var bus: int=AudioServer.get_bus_index("Effects")
	AudioServer.add_bus_effect(bus,capture)
	assert(gun.shoot(),"actual sawn-off fire succeeds")
	await create_timer(0.15).timeout
	assert(gun._sound.playing and gun._sound.stream==gun.SHOT_SOUND,"fire plays selected sound 04")
	var first_voice: AudioStreamPlayer=gun._sound
	await create_timer(0.28).timeout
	gun._update(0.43)
	assert(gun.shoot(),"second barrel fires while first tail is still audible")
	assert(gun._sound!=first_voice and first_voice.playing,"pooled voices preserve overlapping ringing tails")
	await create_timer(4.2).timeout
	gun._update(.43)
	assert(gun.reload(),"empty sawn-off starts its normal reload")
	assert(gun._reload_voices[gun._reload_voice].stream==gun.COCK_SOUND and gun._reload_voices[gun._reload_voice].playing,"opening the action plays selected sound 14")
	await create_timer(1.89).timeout
	gun._update(1.89)
	assert(gun.ammo==0,"no shell sound or ammo transfer before seating")
	gun._update(.02)
	var first_shell: AudioStreamPlayer=gun._reload_voices[gun._reload_voice]
	assert(first_shell.stream==gun.SHELL_SOUND and first_shell.playing and gun.ammo==1,"first insertion plays selected sound 13")
	await create_timer(.49).timeout
	gun._update(.50)
	var second_shell: AudioStreamPlayer=gun._reload_voices[gun._reload_voice]
	assert(second_shell!=first_shell and second_shell.stream==gun.SHELL_SOUND and second_shell.playing and gun.ammo==2,"second insertion uses its own sound 13 voice")
	await create_timer(.6).timeout
	gun._update(.99)
	assert(gun.state=="idle" and not gun.reload(),"full gun cannot retrigger reload sounds")
	gun.loaded[0]=false
	assert(gun.reload(),"one-shell top-up begins")
	gun._update(1.91)
	assert(gun._reload_voices[gun._reload_voice].stream==gun.SHELL_SOUND,"top-up plays a shell insertion")
	gun.set_active(false)
	assert(gun._reload_voices.all(func(voice: AudioStreamPlayer)->bool:return not voice.playing),"holstering stops all reload audio")
	var frames: PackedVector2Array=capture.get_buffer(capture.get_frames_available())
	var peak: float=0.0
	var bytes:=PackedByteArray()
	bytes.resize(frames.size()*4)
	for i in frames.size():
		peak=maxf(peak,maxf(absf(frames[i].x),absf(frames[i].y)))
		bytes.encode_s16(i*4,roundi(clampf(frames[i].x,-1,1)*32767))
		bytes.encode_s16(i*4+2,roundi(clampf(frames[i].y,-1,1)*32767))
	print("Captured frames=",frames.size()," peak=",peak)
	assert(peak>0.01 and peak<0.99,"native fire emits audible, unclipped Effects-bus audio")
	var recording:=AudioStreamWAV.new()
	recording.format=AudioStreamWAV.FORMAT_16_BITS
	recording.mix_rate=roundi(AudioServer.get_mix_rate())
	recording.stereo=true
	recording.data=bytes
	assert(recording.save_to_wav(ProjectSettings.globalize_path("res://docs/previews/sawn_off_selected_audio_ingame.wav"))==OK)
	print("PASS selected sawn-off fire, cocking, shell insertions and cancellation; recorded peak=",peak)
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	main.free()
	for i in 3:await process_frame
	quit()
