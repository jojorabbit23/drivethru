# Visible custom pistol, animated PSX Firearms hands and finite ammunition.
extends Node3D
signal hit(target: Node, headshot: bool, killed: bool)
signal fired
signal ammo_changed
const Hitscan=preload("res://core/hitscan.gd")
const P=preload("res://core/palette.gd")
const VIEWMODEL=preload("res://weapons/pistol/pistol_viewmodel.tscn")
const MAG_SIZE:=15
const DRAW_TIME:=0.4
const RELOAD_TIME:=2.1
const SEAT_TIME:=1.45
@export var damage:=34.0
@export var fire_interval:=0.22
@export var reach:=60.0
var active:=false
var ammo:=MAG_SIZE
var reserve:=90
var state:="idle"
var clock:=0.0
var _cooldown:=0.0
var idle_time:=0.0
var aim_weight:=0.0
var sway:=Vector2.ZERO
var _pivot: Node3D
var _gun: Node3D
var _arms_anim: AnimationPlayer
var _native_slide: Node3D
var _native_mag: Node3D
var _left_hand: Node3D
var _slide: Node3D
var _mag: Node3D
var _flash: OmniLight3D
var _sound: AudioStreamPlayer
@onready var camera: Camera3D=get_parent()
func _ready() -> void:
 _pivot=VIEWMODEL.instantiate()
 add_child(_pivot)
 _gun=_pivot.find_child("Gun",true,false)
 _arms_anim=_pivot.get_node("Arms/AnimationPlayer")
 _native_slide=_pivot.find_child("fp_pistol_slide",true,false)
 _native_mag=_pivot.find_child("fp_pistol_magazine",true,false)
 _left_hand=_pivot.find_child("fp_pistol_hand_l",true,false)
 _slide=_gun.find_child("pistol_slide",true,false)
 _mag=_gun.find_child("pistol_magazine",true,false)
 _flash=OmniLight3D.new()
 _flash.light_color=P.AMBER_GLOW
 _flash.omni_range=2.5
 _flash.visible=false
 _flash.light_energy=3.0
 _gun.add_child(_flash)
 _flash.position=Vector3(0,0.079,0.16)
 _sound=AudioStreamPlayer.new()
 _sound.volume_db=-14
 add_child(_sound)
 visible=false
 _pose()
func can_act() -> bool:
 var player: Node=owner
 return active and not (player!=null and player.has_method("is_dead") and player.is_dead())
func set_active(on: bool) -> void:
 var was_active: bool=active
 active=on
 visible=on or was_active
 state="draw" if on else ("holster" if was_active else "idle")
 clock=0.0
 aim_weight=0.0
 camera.fov=75.0
 _flash.visible=false
 if not on: _sound.stop()
 _pose()
func add_ammo(n: int) -> void:
 reserve+=maxi(0,n)
 ammo_changed.emit()
func is_reloading() -> bool: return state=="reload"
func is_busy() -> bool: return state!="idle" or _cooldown>0.0
func _unhandled_input(event: InputEvent) -> void:
 if active and event is InputEventMouseMotion: sway+=(event as InputEventMouseMotion).relative*0.0001
 if not can_act() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_R: reload()
  elif event.physical_keycode==KEY_F and not is_busy():
   state="inspect"
   clock=0.0
func _physics_process(delta: float) -> void:
 if not active and state!="holster": return
 if active and not can_act(): set_active(false)
 var aiming: bool=can_act() and state in ["idle","fire"] and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("alt_fire")
 aim_weight=lerpf(aim_weight,1.0 if aiming else 0.0,1.0-exp(-12.0*delta))
 if active: camera.fov=lerpf(75.0,65.0,aim_weight)
 if can_act() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("fire"): request_fire()
 _update(delta)
func request_fire() -> bool:
 if not can_act() or is_busy(): return false
 if ammo<=0:
  _play_sound("empty")
  reload()
  return false
 shoot()
 return true
func reload() -> bool:
 if not can_act() or state!="idle" or ammo==MAG_SIZE or reserve<=0: return false
 state="reload"
 clock=0.0
 _play_sound("reload")
 return true
func _update(delta: float) -> void:
 if not active and state!="holster": return
 var before: float=clock
 clock+=delta
 idle_time+=delta
 _cooldown=maxf(0.0,_cooldown-delta)
 sway=sway.lerp(Vector2.ZERO,1.0-exp(-10.0*delta))
 if state=="reload":
  if before<SEAT_TIME and clock>=SEAT_TIME:
   var transfer: int=mini(MAG_SIZE-ammo,reserve)
   ammo+=transfer
   reserve-=transfer
   ammo_changed.emit()
  if clock>=RELOAD_TIME:
   state="idle"
   clock=0.0
 elif state=="fire" and clock>=fire_interval:
  state="idle"
  clock=0.0
 elif state=="draw" and clock>=DRAW_TIME:
  state="idle"
  clock=0.0
 elif state=="holster" and clock>=0.2:
  state="idle"
  visible=false
 elif state=="inspect" and clock>=3.2:
  state="idle"
  clock=0.0
 _flash.visible=state=="fire" and clock<0.045
 _pose()
func _pose() -> void:
 if _arms_anim==null: return
 var clip: String="idle"
 var t: float=fmod(idle_time,3.0)
 if state=="draw" or state=="holster":
  clip="draw"
  var k: float=clampf(clock/(DRAW_TIME if state=="draw" else 0.2),0.0,1.0)
  t=(k if state=="draw" else 1.0-k)*0.5333333
 elif state=="fire":
  clip="fire"
  t=clampf(clock/fire_interval,0.0,1.0)*0.3
 elif state=="reload":
  clip="reload"
  t=clampf(clock/RELOAD_TIME,0.0,1.0)*1.6
 elif state=="inspect":
  clip="inspect"
  t=clock
 _native_mag.position=Vector3(0,-0.05,0)
 _native_mag.rotation=Vector3.ZERO
 _native_slide.position=Vector3(0,0.074,0)
 _native_slide.rotation=Vector3.ZERO
 _left_hand.position=Vector3(0.1035269,-0.3385068,-0.0533267)
 _left_hand.rotation=Vector3.ZERO
 _arms_anim.play(clip,0.0)
 _arms_anim.seek(t,true)
 var support:=1.0
 if state=="reload": support=1.0-smoothstep(0.0,0.3,clock)+smoothstep(1.7,2.1,clock)
 elif state=="draw": support=smoothstep(0.1,DRAW_TIME,clock)
 elif state=="holster": support=1.0-smoothstep(0.0,0.2,clock)
 elif state=="inspect": support=0.0
 _left_hand.position=_left_hand.position.lerp(Vector3(0.025,-0.025,-0.025),support)
 _pivot.position=Vector3(-0.025-sway.x,-0.045+sway.y,-0.08)
 # Drive custom parts from the matching native hand animation, not a separate timer.
 _slide.transform=_native_slide.transform
 _mag.transform=_native_mag.transform
 if ammo==0 and state=="idle": _slide.position.z-=0.035
 var sight: Vector3=camera.to_local(_gun.to_global(Vector3(0,0.086,0.02)))
 _pivot.position+=Vector3(-sight.x,-sight.y-0.012,0)*aim_weight
func _play_sound(label: String) -> void:
 if DisplayServer.get_name()=="headless": return
 _sound.stream=load("res://weapons/pistol/audio/%s.wav" % label)
 _sound.play()
# Low-level scripted shot API retained for existing hitscan/ooze tests.
# Player input uses request_fire(), which also enforces draw/reload/cooldown gates.
func shoot() -> Dictionary:
 if not can_act() or ammo<=0 or state=="reload": return {}
 ammo-=1
 state="fire"
 clock=0.0
 ammo_changed.emit()
 _play_sound("shot")
 _cooldown = fire_interval
 _flash.light_energy = 3.0
 _flash.visible = true
 fired.emit()
 var head := camera.get_parent() as Node3D
 head.rotation.x = minf(head.rotation.x + deg_to_rad(1.2), deg_to_rad(85.0))
 var from := camera.global_position
 var to := from - camera.global_basis.z * reach
 var ex: Array[RID] = []
 if owner is CollisionObject3D:
  ex.append((owner as CollisionObject3D).get_rid())
 var res := Hitscan.cast(camera.get_world_3d().direct_space_state, from, to, ex)
 if res.is_empty():
  return {}
 _spark(res["position"])
 var col: Object = res["collider"]
 var zombie: Node = null
 var headshot := false
 if col is Area3D and (col as Area3D).has_meta("zombie"):
  zombie = (col as Area3D).get_meta("zombie")
  headshot = true
 elif col is Node and (col as Node).is_in_group("zombies"):
  zombie = col
 if zombie and is_instance_valid(zombie) and zombie.has_method("take_damage"):
  zombie.take_damage(damage, headshot, {"pos": res["position"], "dir": (to - from).normalized(), "normal": res["normal"]})
  var killed: bool = zombie.is_dead()
  hit.emit(zombie, headshot, killed)
 return res

func _spark(at: Vector3) -> void:
 var m := MeshInstance3D.new()
 var s := SphereMesh.new()
 s.radius = 0.03
 s.height = 0.06
 s.radial_segments = 6
 s.rings = 3
 var mat := StandardMaterial3D.new()
 mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.albedo_color = Color("#F3A34D")
 s.material = mat
 m.mesh = s
 var parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
 parent.add_child(m)
 m.global_position = at
 var tw := m.create_tween()
 tw.tween_property(m, "scale", Vector3.ZERO, 0.18)
 tw.tween_callback(m.queue_free)
