extends Node3D
# One shared clock for gentle practical-light dips and occasional machine clunks.
var damage_events: int=0
var current_shift: int=1
var _door_checked: bool=false
var _elapsed: float=0
var _next_clunk: float=19
var _lights: Array[OmniLight3D]=[]
var _energies: Array[float]=[]
func _ready() -> void:
 var main: Node=get_parent()
 main.wave_started.connect(update_shift)
 for window in main.shop.find_children("Window_*","Node3D",true,false):
  if window.has_signal("board_removed"):window.board_removed.connect(_board_removed)
 for key in ["ShopFloor","Kitchen","BackOffice","Storeroom"]:
  var light:=main.get_node_or_null("ShopGreybox/Lights/Light_"+key) as OmniLight3D
  if light:_lights.append(light);_energies.append(light.light_energy)
 if DisplayServer.get_name()=="headless":set_process(false);return
 _audio("FX_audio_fridge_hum",Vector3.ZERO,"hum",-29,true)
 _audio("FX_audio_fridge_hum",Vector3(2.4,0,-6.4),"hum",-30,true)
 _audio("FX_audio_hold_music",Vector3.ZERO,"hold",-25,true)
 _audio("FX_audio_ice_machine",Vector3.ZERO,"clunk",-24,false)
func _audio(anchor: String,offset: Vector3,clip: String,volume: float,playing: bool) -> void:
 var audio:=AudioStreamPlayer3D.new();audio.name=clip;audio.position=offset
 audio.stream=load("res://art/building_decor/audio/"+clip+".wav")
 if clip in ["hum","hold"] and audio.stream is AudioStreamWAV:audio.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;audio.stream.loop_end=audio.stream.data.size()/2
 audio.volume_db=volume;audio.max_distance=8;audio.unit_size=1.5;audio.bus="Ambience"
 get_node(anchor).add_child(audio)
 if playing:audio.play()
func _process(delta: float) -> void:
 _elapsed+=delta
 if not _door_checked and get_node("BACK_freezer_door").linked().unlocked:
  _door_checked=true
  get_node("BACK_freezer_door").hide()
  get_node("BACK_freezer_door/Zone").collision_layer=0
 var bulb:=get_node("EXT_roof_sign/FlickeringBulb") as MeshInstance3D
 bulb.visible=fmod(_elapsed,7.3)>.15
 for i in _lights.size():
  # Brief staggered dips; never a full blackout or flashing strobe.
  var phase: float=fmod(_elapsed+i*4.1,19.0)
  _lights[i].light_energy=_energies[i]*(.78 if phase<.12 else 1.0)
 if _elapsed>=_next_clunk:
  var audio:=get_node_or_null("FX_audio_ice_machine/clunk") as AudioStreamPlayer3D
  if audio:audio.play()
  _next_clunk=_elapsed+randf_range(18,36)
func _board_removed(_index: int) -> void:
 damage_events+=1
 apply_wear(minf(1,damage_events/18.0))
func apply_wear(amount: float) -> void:
 for child in get_children():
  if child.has_method("apply_wear"):child.apply_wear(amount)
 var letters:=get_node("EXT_roof_sign/Letters") as Label3D
 letters.text="DRIVE THR" if amount<.35 else ("DR VE THR" if amount<.7 else "DR VE  HR")
func update_shift(n: int) -> void:
 current_shift=n
 var employee:=get_node("BACK_photo_eotm/EmployeeName") as Label3D
 employee.text="EMPLOYEE OF\nTHE MONTH\n"+(["DAVE","DAVE?","STILL DAVE","DAVE (MISSING)"][(maxi(1,n)-1)%4])
