extends SceneTree
var main: Node3D
func _initialize() -> void:run.call_deferred()
func rms(capture: AudioEffectCapture) -> float:
	var frames: PackedVector2Array=capture.get_buffer(capture.get_frames_available())
	var energy: float=0.0
	for frame: Vector2 in frames:energy+=frame.length_squared()
	return sqrt(energy/maxi(1,frames.size()*2))
func sample(radio: Node,listener: AudioListener3D,offset: Vector3,capture: AudioEffectCapture) -> float:
	listener.global_position=radio.source.global_position+offset
	radio.source.play(25.0)
	await create_timer(0.25).timeout
	capture.clear_buffer()
	await create_timer(0.7).timeout
	return rms(capture)
func run() -> void:
	Engine.max_fps=30
	root.size=Vector2i(1280,720)
	main=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	var player: Node=main.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	for weapon: Node3D in player.weapons:weapon.hide();weapon.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var radio: Node3D=main.get_node("KitchenRadio")
	var broadcast_mode: bool=OS.get_cmdline_user_args().has("--broadcast")
	if broadcast_mode:
		radio._next_track()
		radio._next_track()
		assert(radio.broadcast_index==0,"broadcast starts after second song")
	player.global_position=Vector3(4.4,0.05,-3.25)
	var direction: Vector3=radio.global_position+Vector3(0,0.20,0)-player.camera.global_position
	player.rotation.y=atan2(-direction.x,-direction.z)
	player.head.rotation.x=atan2(direction.y,Vector2(direction.x,direction.z).length())
	for i in 6:await physics_frame
	player._update_focus()
	assert(player.focus==radio,"actual interaction ray reaches radio without hitting food stations")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/kitchen_radio_broadcast.png" if broadcast_mode else "res://docs/previews/kitchen_radio.png"))
	player.use_focus()
	assert(not radio.enabled and radio.source.stream_paused,"E turns radio off")
	var paused_at: float=radio.source.get_playback_position()
	await create_timer(0.3).timeout
	assert(absf(radio.source.get_playback_position()-paused_at)<0.1,"off radio preserves playback position")
	player.use_focus()
	assert(radio.enabled and not radio.source.stream_paused,"E resumes radio")
	# Measure actual post-attenuation audio on the Music bus at two listener distances.
	var listener:=AudioListener3D.new()
	main.add_child(listener)
	listener.make_current()
	var capture:=AudioEffectCapture.new()
	capture.buffer_length=2.0
	var bus: int=AudioServer.get_bus_index("Music")
	AudioServer.add_bus_effect(bus,capture)
	var near_level: float=await sample(radio,listener,Vector3(0,0,1),capture)
	var far_level: float=await sample(radio,listener,Vector3(0,0,18),capture)
	print("RADIO AUDIO near RMS=",near_level," far RMS=",far_level)
	assert(near_level>0.00001 and far_level<near_level*0.4,"music is audible nearby and fades with distance")
	if broadcast_mode:
		radio.source.finished.emit()
		assert(radio.track_index==2 and radio.broadcast_index==-1,"third song follows broadcast")
		for i in 3:radio.source.finished.emit()
		assert(radio.track_index==2 and radio.broadcast_index==-1 and radio.played_broadcasts.size()==1,"next loop does not repeat broadcast")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	var pause: CanvasLayer=player.get_node("PauseMenu")
	pause.open()
	pause.show_settings()
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/kitchen_radio_settings.png"))
	assert(pause.content.get_global_rect().end.y<=720.0,"settings including radio volume fit on screen")
	paused=false
	main.free()
	for i in 3:await process_frame
	print("PASS native radio targeting, toggle, resume and measured distance fade")
	quit()
