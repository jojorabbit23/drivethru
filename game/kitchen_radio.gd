extends "res://game/station.gd"
const Prefs=preload("res://presentation/preferences.gd")
const TRACKS: Array[String]=[
	"res://presentation/music/Short_Order_Carnage.mp3",
	"res://presentation/music/Locked_Screen_Door.mp3",
	"res://presentation/music/The_Skillet_Vigil.mp3",
]
const TITLES: Array[String]=["SHORT ORDER CARNAGE","LOCKED SCREEN DOOR","THE SKILLET VIGIL"]
var source: AudioStreamPlayer3D
var enabled: bool=true
var track_index: int=0
var power: MeshInstance3D
func _ready() -> void:
	Prefs.configure()
	# A small shelf keeps the radio above the bun counter without blocking prep.
	add_box(Vector3(0.76,0.035,0.34),Vector3(0,-0.015,0),P.WET_CHARCOAL)
	for x: float in [-0.26,0.26]:
		add_box(Vector3(0.035,0.17,0.22),Vector3(x,-0.10,-0.17),P.CONCRETE_GREY)
		add_box(Vector3(0.09,0.035,0.12),Vector3(x,0.025,0),P.WET_CHARCOAL)
	var shell: MeshInstance3D=add_box(Vector3(0.66,0.32,0.24),Vector3(0,0.20,0),P.OXIDISED_TEAL)
	shell.material_override=load("res://materials/kit_teal.tres")
	add_box(Vector3(0.62,0.024,0.025),Vector3(0,0.055,0.13),P.BURNT_ORANGE)
	# Twin recessed speaker grilles, screws and orange tuning controls.
	for x: float in [-0.21,0.21]:
		add_box(Vector3(0.18,0.23,0.018),Vector3(x,0.20,0.128),P.MIDNIGHT_TYNE)
		for i in 7:add_box(Vector3(0.15,0.009,0.009),Vector3(x,0.105+i*0.03,0.14),P.CONCRETE_GREY)
	for x: float in [-0.30,0.30]:
		for y: float in [0.07,0.33]:add_box(Vector3(0.012,0.012,0.009),Vector3(x,y,0.135),P.AMBER_GLOW)
	add_box(Vector3(0.15,0.075,0.02),Vector3(0,0.28,0.13),P.MIDNIGHT_TYNE)
	for i in 5:add_box(Vector3(0.012,0.03,0.008),Vector3(-0.055+i*0.026,0.28,0.145),P.WARM_CHALK)
	power=add_box(Vector3(0.025,0.025,0.014),Vector3(0,0.215,0.14),P.AMBER_GLOW)
	for x: float in [-0.045,0.045]:add_box(Vector3(0.052,0.052,0.035),Vector3(x,0.14,0.14),P.BURNT_ORANGE)
	for x: float in [-0.19,0.19]:add_box(Vector3(0.025,0.085,0.035),Vector3(x,0.395,0),P.WET_CHARCOAL)
	add_box(Vector3(0.40,0.025,0.035),Vector3(0,0.44,0),P.WET_CHARCOAL)
	add_box(Vector3(0.012,0.25,0.012),Vector3(0.27,0.47,-0.08),P.CONCRETE_GREY)
	for child: Node in get_children():
		if child is MeshInstance3D:child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_zone(Vector3(0.72,0.48,0.34),Vector3(0,0.23,0.02))
	source=AudioStreamPlayer3D.new()
	source.name="RadioMusic"
	source.bus="Music"
	source.volume_db=-9.0
	source.unit_size=2.5
	source.max_distance=22.0
	source.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	source.attenuation_filter_cutoff_hz=6500.0
	source.position=Vector3(0,0.20,0)
	add_child(source)
	source.finished.connect(_next_track)
	_load_track()
func _load_track() -> void:
	source.stream=load(TRACKS[track_index])
	# Individual tracks must finish so all three participate in the playlist.
	if source.stream is AudioStreamMP3:source.stream.loop=false
	source.play()
	source.stream_paused=not enabled
func _next_track() -> void:
	track_index=(track_index+1)%TRACKS.size()
	_load_track()
func prompt(_player: Node) -> String:
	return "E  turn radio on" if not enabled else "E  turn radio off  -  "+TITLES[track_index]
func interact(_player: Node) -> void:
	enabled=not enabled
	# Pause rather than restart: turning it back on resumes the current song.
	source.stream_paused=not enabled
	(power.material_override as StandardMaterial3D).albedo_color=P.AMBER_GLOW if enabled else P.WET_CHARCOAL
	Sfx.play(self,"click",-20.0)
