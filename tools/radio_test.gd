extends SceneTree
const Prefs=preload("res://presentation/preferences.gd")
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run() -> void:
	var main: Node3D=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	var radio: Node3D=main.get_node("KitchenRadio")
	check(radio.enabled and radio.track_index==0,"kitchen radio starts enabled on first song")
	check(radio.source is AudioStreamPlayer3D and radio.source.bus==&"Music","music comes from positional source on music bus")
	check(radio.source.unit_size==2.5 and radio.source.max_distance==22.0 and radio.source.attenuation_model==AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,"distance attenuation and bounded audibility configured")
	for i in 3:
		check(radio.track_index==i and radio.source.stream is AudioStreamMP3 and radio.source.stream.get_length()>30.0,"playlist loads supplied track %d" % (i+1))
		check(not radio.source.stream.loop,"individual song loop disabled to allow playlist advancement")
		radio.source.finished.emit()
		if i==1:
			check(radio.broadcast_index==0 and radio.track_index==1 and radio.source.stream is AudioStreamOggVorbis,"broadcast follows second track before third song")
			check(not radio.source.stream.loop and radio.source.stream.get_length()>50.0,"full extracted broadcast does not loop")
			for frame in 3:await process_frame
			radio.interact(main.player)
			check(not radio.enabled and radio.source.stream_paused,"switching radio off pauses broadcast")
			radio.interact(main.player)
			check(radio.enabled and radio.broadcast_index==0 and not radio.source.stream_paused,"switching on resumes broadcast without repeating it")
			radio.source.finished.emit()
	check(radio.track_index==0,"playlist wraps from third song to first")
	for cycle in 3:
		for track in 3:
			check(radio.track_index==track and radio.broadcast_index==-1,"later music loops skip previously played broadcasts")
			radio.source.finished.emit()
	check(radio.played_broadcasts.size()==1,"broadcast recorded once for this run")
	for i in 3:await process_frame
	radio.interact(main.player)
	check(not radio.enabled and radio.source.stream_paused,"E switches radio off by pausing music")
	check(radio.prompt(main.player).contains("on"),"off radio offers turn-on interaction")
	radio.interact(main.player)
	check(radio.enabled and not radio.source.stream_paused and radio.track_index==0,"E resumes current track without skipping")
	Prefs.set_value("music",0.3,false)
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")),linear_to_db(0.3)),"music setting controls its own bus")
	Prefs.set_focused(false)
	check(AudioServer.is_bus_mute(0),"radio obeys background audio mute")
	Prefs.set_focused(true)
	main.free()
	for i in 3:await process_frame
	print("%d failure(s)" % failures)
	quit(1 if failures else 0)
