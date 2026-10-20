extends Node
const Prefs=preload("res://presentation/preferences.gd")
const Sounds=preload("res://presentation/audio_library.gd")
var actor: CharacterBody3D
var distance: float=0.0
var last: Vector3
var grounded: bool=true
var scan: float=0.0
var states: Dictionary={}
var serial: int=0
var voices: int=0
var distant_time: float=12.0
var distant_index: int=0
var distant_voice: AudioStreamPlayer3D
var help_label: Label
var expanded_help: bool=false
var help_panel: PanelContainer
const SHORT_HELP: String="WASD move · E interact · V select burger · R reload · Wheel weapons · Esc pause · F1 controls"
func _ready() -> void:
 actor=get_parent() as CharacterBody3D
 Prefs.configure()
 last=actor.global_position
 var props: Node3D=preload("res://presentation/kitchen/visuals.gd").new()
 add_child(props)
 var shadows: Node=preload("res://presentation/shadow_budget.gd").new()
 shadows.name="ShadowBudget"
 add_child(shadows)
 if DisplayServer.get_name()=="headless":
  set_physics_process(false)
  return
 actor.weapon_changed.connect(func(_index: int,_weapon: Node):effect("cloth",actor.global_position,-24.0))
 actor.hurt.connect(func(_amount: float,_from: Node3D):effect("hurt",actor.global_position,-11.0))
 get_tree().node_added.connect(route_audio)
 route_tree(get_tree().root)
 tidy_help.call_deferred()
 add_ambience("fridge",Vector3(5.2,1.0,-4.3),-8.0)
 add_ambience("fridge",Vector3(-5.1,1.0,-0.5),-12.0)
 add_ambience("air",Vector3(0,2,5),-6.0)
 add_ambience("distant_drone",Vector3(10,3,10),-5.0)
 distant_voice=AudioStreamPlayer3D.new()
 distant_voice.bus="Ambience"
 distant_voice.volume_db=-10.0
 distant_voice.unit_size=16.0
 distant_voice.max_distance=55.0
 add_child(distant_voice)
 distant_voice.top_level=true

func route_tree(node: Node) -> void:
 route_audio(node)
 for child in node.get_children():route_tree(child)
func route_audio(node: Node) -> void:
 if node is Node3D and not node.has_meta("presentation_audio_hooked"):
  if node.has_signal("board_removed"):
   node.set_meta("presentation_audio_hooked",true)
   node.board_removed.connect(func(_index: int):effect("wood",node.global_position,-10.0))
   node.board_restored.connect(func(_index: int):effect("wood",node.global_position,-15.0))
  elif node.has_signal("collected"):
   node.set_meta("presentation_audio_hooked",true)
   node.collected.connect(func(_pickup: Node):effect("select",actor.global_position,-12.0))
 if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
  if node.bus==&"Master":node.bus=&"Effects"
func add_ambience(kind: String,position: Vector3,volume: float) -> void:
 var source:=AudioStreamPlayer3D.new()
 source.bus="Ambience"
 source.stream=Sounds.sound(kind)
 source.volume_db=volume
 source.unit_size=3.0
 source.max_distance=45.0 if kind=="distant_drone" else 18.0
 if kind=="distant_drone":source.unit_size=12.0
 add_child(source)
 source.top_level=true
 source.global_position=position
 source.play()
func effect(kind: String,position: Vector3,volume: float=-15.0) -> void:
 if voices>=8:return
 voices+=1
 serial+=1
 var source:=AudioStreamPlayer3D.new()
 source.bus="Effects"
 source.stream=Sounds.sound(kind,serial%4)
 source.volume_db=volume
 source.unit_size=3.0
 source.max_distance=16.0
 add_child(source)
 source.top_level=true
 source.global_position=position
 source.finished.connect(func():voices-=1;source.queue_free())
 source.play()
func surface(position: Vector3) -> String:
 if (position.x>1.4 and position.x<3.8 and position.z> -4.05 and position.z< -3.4) or (position.x> -4.6 and position.x< -1.4 and position.z> -3.95 and position.z< -3.25):return "rubber"
 return "tile" if absf(position.x)<6.0 and position.z<0.0 and position.z> -4.75 else "grit"
func _physics_process(delta: float) -> void:
 distant_time-=delta
 if distant_time<=0.0:
  play_distant()
  distant_time=12.0+float((distant_index*7)%9)
 actor.mouse_sensitivity=float(Prefs.values["sensitivity"])
 if not bool(Prefs.values["camera_roll"]):actor.camera.rotation.z=0.0
 var now: Vector3=actor.global_position
 var travel: float=Vector2(now.x-last.x,now.z-last.z).length()
 if actor.is_on_floor() and not actor.is_dead():
  if not grounded:effect("land",now,-17.0)
  if travel<0.5 and actor.velocity.length()>0.5:
   distance+=travel
   if distance>1.7:
    distance=0.0
    effect(surface(now),now,-14.0)
 else:distance=1.2
 grounded=actor.is_on_floor()
 last=now
 scan-=delta
 if scan>0.0:return
 scan=0.25
 var live: Dictionary={}
 for enemy in get_tree().get_nodes_in_group("zombies"):
  var id: int=enemy.get_instance_id()
  var state: int=enemy.state
  live[id]=state
  if states.has(id) and states[id]!=state and now.distance_to(enemy.global_position)<14.0:
   if state==4:effect("chitter" if "Scuttler" in enemy.name else "groan",enemy.global_position,-13.0)
   elif state==6:effect("death",enemy.global_position,-16.0)
 states=live

func tidy_help() -> void:
 for node in get_tree().root.find_children("*","Label",true,false):
  if node.text.begins_with("WASD move"):
   help_label=node
   help_label.text=SHORT_HELP
   help_label.add_theme_color_override("font_color",preload("res://core/palette.gd").WARM_CHALK)
   help_label.add_theme_color_override("font_outline_color",preload("res://core/palette.gd").MIDNIGHT_TYNE)
   help_label.add_theme_constant_override("outline_size",4)
   help_panel=PanelContainer.new()
   help_panel.position=Vector2(16,170)
   help_panel.theme=Prefs.theme()
   var style:=StyleBoxFlat.new()
   style.bg_color=Color(preload("res://core/palette.gd").MIDNIGHT_TYNE,0.95)
   style.set_content_margin_all(16)
   help_panel.add_theme_stylebox_override("panel",style)
   var details:=Label.new()
   details.text="CONTROLS — F1 to close\nWASD move · Shift sprint · Space jump\nLMB fire / slash · RMB aim / stab · F inspect\n1–4 or wheel switch · Buy shotguns at shop\nV cycle burgers · E place / retrieve / discard\nR reload firearm\nE use / hold to repair · 1–4 station options\nF2 auto-collect · Z/X debug spawn · L labels\nEsc pause · R restart after death / with knife"
   details.add_theme_font_size_override("font_size",16)
   help_panel.add_child(details)
   help_label.get_parent().add_child(help_panel)
   help_panel.hide()
   break
func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F1 and is_instance_valid(help_label):
  expanded_help=not expanded_help
  help_panel.visible=expanded_help
  get_viewport().set_input_as_handled()

func play_distant() -> void:
 if not is_instance_valid(distant_voice):return
 var positions: Array[Vector3]=[Vector3(16,2,-9),Vector3(-16,2,7),Vector3(10,2,16),Vector3(-12,2,-12)]
 distant_voice.global_position=positions[distant_index%positions.size()]
 distant_voice.stream=Sounds.sound("distant_moan",distant_index%4)
 distant_voice.play()
 distant_index+=1
