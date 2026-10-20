# Two-shot break-action shotgun. Visuals use the supplied mechanical clips plus PSX arms.
extends Node3D
signal hit(target: Node, headshot: bool, killed: bool)
signal fired
signal ammo_changed
const P=preload("res://core/palette.gd")
const Hitscan=preload("res://core/hitscan.gd")
const VIEWMODEL=preload("res://weapons/crop_duster/crop_duster_viewmodel.tscn")
const SHOT_SOUND=preload("res://weapons/crop_duster/audio/sawn_off_deep_blast.wav")
const DRAW_TIME:=0.45
const RELOAD_TIME:=3.4
@export var pellet_damage:=22.0
@export var reach:=40.0
var active:=false
var loaded: Array[bool]=[true,true]
var reserve:=24
var display_name: String="SAWN-OFF"
var mag: int:
 get:return ammo
func add_ammo(amount: int) -> void:
 reserve+=amount
 ammo_changed.emit()
func is_reloading() -> bool:
 return state=="reload"
var ammo: int:
 get: return int(loaded[0])+int(loaded[1])
var state:="idle"
var clock:=0.0
var cooldown:=0.0
var recoil:=0.0
var sway:=Vector2.ZERO
var idle_time:=0.0
var aim_weight:=0.0
var _pivot: Node3D
var _gun: Node3D
var _arms: Node3D
var _mechanics: Skeleton3D
var _arms_anim: AnimationPlayer
var _gun_anim: AnimationPlayer
var _left_hand: Node3D
var _pump: Node3D
var _grip_in_hand:=Vector3.ZERO
var _support_basis_in_gun:=Basis.IDENTITY
var _holster_start:=Transform3D.IDENTITY
var _reload_requested:=false
var _reload_plan: Array[bool]=[true,true]
var _reload_initial_loaded: Array[bool]=[false,false]
var _left_forearm: Node3D
var _forearm_direction:=Vector3(0.12,-0.20,-0.23).normalized()
var _flash: OmniLight3D
var _sound: AudioStreamPlayer
var _mechanism_sound: AudioStreamPlayer
var _shot_voices: Array[AudioStreamPlayer]=[]
var _shot_voice: int=0
var _vapour: Node3D
var _hand_anchor:=Vector3.ZERO
const Sounds=preload("res://presentation/audio_library.gd")
var _shell_materials: Array[ShaderMaterial]=[]
var _rng:=RandomNumberGenerator.new()
@onready var camera: Camera3D=get_parent()
func _ready() -> void:
 _rng.seed=420
 _pivot=VIEWMODEL.instantiate()
 add_child(_pivot)
 _arms=_pivot.get_node("Arms")
 _gun=_pivot.find_child("Gun",true,false)
 _mechanics=_gun.find_child("Skeleton3D",true,false)
 _arms_anim=_arms.get_node("AnimationPlayer")
 _gun_anim=_gun.find_child("AnimationPlayer",true,false)
 _left_hand=_arms.find_child("fp_pump_shotgun_hand_l",true,false)
 _pump=_arms.find_child("fp_pump_shotgun_pump",true,false)
 _arms_anim.play("idle")
 _arms_anim.seek(0.0,true)
 _pump.position=Vector3(0,0.078,0.280)
 _grip_in_hand=_left_hand.to_local(_gun.to_global(Vector3(0.015,0.24,0.18)))
 _support_basis_in_gun=_gun.global_basis.orthonormalized().inverse()*_left_hand.global_basis.orthonormalized()
 _left_forearm=_arms.find_child("fp_pump_shotgun_forearm_l",true,false)
 var mesh: MeshInstance3D=_gun.find_child("Shotgun_SkinnedMesh",true,false)
 for surface in range(5,11):
  var mat: ShaderMaterial=mesh.mesh.surface_get_material(surface).duplicate()
  mesh.set_surface_override_material(surface,mat)
  _shell_materials.append(mat)
 _flash=OmniLight3D.new()
 _flash.light_color=P.AMBER_GLOW
 _flash.omni_range=2.0
 _flash.light_energy=3.0
 _flash.visible=false
 _gun.add_child(_flash)
 _flash.position=Vector3(0,0.32,0.50)
 for i in 3:
  var voice:=AudioStreamPlayer.new()
  voice.volume_db=-5.0
  voice.bus="Effects"
  voice.stream=SHOT_SOUND
  add_child(voice)
  _shot_voices.append(voice)
 _sound=_shot_voices[0]
 _mechanism_sound=AudioStreamPlayer.new()
 _mechanism_sound.volume_db=-11.0
 _mechanism_sound.bus="Effects"
 add_child(_mechanism_sound)
 if DisplayServer.get_name()!="headless":
  Sounds.sound("mechanism")
 _vapour=preload("res://weapons/crop_duster/muzzle_vapour.gd").new()
 add_child(_vapour)
 visible=false
 _pose(0.0)
func set_active(on: bool) -> void:
 var was_active: bool=active
 if was_active and not on: _holster_start=_pivot.transform
 _reload_requested=false
 active=on
 visible=on or was_active
 state="draw" if on else ("holster" if was_active else "idle")
 clock=0.0
 recoil=0.0
 aim_weight=0.0
 camera.fov=75.0
 _flash.visible=false
 if not on:
  for voice in _shot_voices:voice.stop()
  _mechanism_sound.stop()
  if _vapour: _vapour.clear()
 # Interrupted reloads retain only seated shells. A brief reversed draw lowers the gun.
 _pose(0.0)
func is_busy() -> bool: return state!="idle" or cooldown>0.0
func can_act() -> bool:
 var player: Node=owner
 return active and not (player!=null and player.has_method("is_dead") and player.is_dead())
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion and active:
  sway+=(event as InputEventMouseMotion).relative*0.00012
 if not can_act() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_R: reload()
  elif event.physical_keycode==KEY_F and not is_busy():
   state="inspect"
   clock=0.0
func _physics_process(delta: float) -> void:
 if not active and state!="holster": return
 if active and not can_act(): set_active(false)
 var aiming: bool=can_act() and state=="idle" and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("alt_fire")
 aim_weight=lerpf(aim_weight,1.0 if aiming else 0.0,1.0-exp(-12.0*delta))
 if active: camera.fov=lerpf(75.0,65.0,aim_weight)
 if can_act() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("fire"):
  shoot()
 _update(delta)
func reload() -> bool:
 if not can_act() or state!="idle" or ammo==2 or reserve<=0: return false
 if cooldown>0.0:
  _reload_requested=true
  return true
 _reload_requested=false
 _reload_initial_loaded.assign(loaded)
 var available: int=reserve
 for i in 2:
  _reload_plan[i]=not loaded[i] and available>0
  if _reload_plan[i]: available-=1
 state="reload"
 clock=0.0
 _click()
 return true
func _update(delta: float) -> void:
 if not active and state!="holster": return
 var remaining_cooldown: float=cooldown
 var action_delta: float=delta
 cooldown=maxf(0.0,cooldown-delta)
 recoil=move_toward(recoil,0.0,delta*3.8)
 _vapour.advance(delta)
 if _reload_requested and cooldown<=0.0:
  reload()
  action_delta=maxf(0.0,delta-remaining_cooldown)
 var previous: float=clock
 clock+=action_delta
 idle_time+=delta
 sway=sway.lerp(Vector2.ZERO,1.0-exp(-10.0*delta))
 if state=="reload":
  for i in 2:
   var seat_time: float=1.9 if i==0 else 2.4
   if previous<seat_time and clock>=seat_time and not loaded[i] and reserve>0:
    loaded[i]=true
    reserve-=1
    ammo_changed.emit()
    _click()
  if previous<3.0 and clock>=3.0: _click()
  if clock>=RELOAD_TIME:
   state="idle"
   clock=0.0
 elif state=="holster" and clock>=0.22:
  state="idle"
  visible=false
 elif state=="draw" and clock>=DRAW_TIME:
  state="idle"
  clock=0.0
 elif state=="inspect" and clock>=3.2:
  state="idle"
  clock=0.0
 _flash.visible=recoil>0.87
 _pose(delta)
func shoot() -> bool:
 if not can_act() or is_busy(): return false
 if ammo==0:
  _click()
  reload()
  return false
 var barrel: int=0 if loaded[0] else 1
 loaded[barrel]=false
 _flash.position.x=-0.044 if barrel==0 else 0.044
 cooldown=0.42
 recoil=1.0
 ammo_changed.emit()
 fired.emit()
 _shot_sound()
 _vapour.release(_gun.to_global(Vector3(_flash.position.x,0.32,0.50)),camera)
 var accumulated: Dictionary={}
 var exclude: Array[RID]=[]
 if owner is CollisionObject3D: exclude.append((owner as CollisionObject3D).get_rid())
 for pellet in 8:
  var radius: float=0.0 if pellet==0 else sqrt(float(pellet)/7.0)*tan(deg_to_rad(3.5))
  var angle: float=float(pellet)*2.39996323
  var direction: Vector3=(camera.global_basis*Vector3(cos(angle)*radius,sin(angle)*radius,-1)).normalized()
  var result: Dictionary=Hitscan.cast(camera.get_world_3d().direct_space_state,camera.global_position,camera.global_position+direction*reach,exclude)
  if result.is_empty(): continue
  Hitscan.damage_prop(result,pellet_damage)
  var col: Object=result["collider"]
  var zombie: Node=null
  var headshot:=false
  if col is Area3D and (col as Area3D).has_meta("zombie"):
   zombie=(col as Area3D).get_meta("zombie")
   headshot=true
  elif col is Node and (col as Node).is_in_group("zombies"): zombie=col
  if zombie==null: continue
  var key: int=zombie.get_instance_id()
  var distance: float=camera.global_position.distance_to(result["position"])
  var amount: float=pellet_damage*clampf(1.0-(distance-8.0)/40.0,0.35,1.0)
  if headshot: amount*=float(zombie.get("head_multiplier"))
  if not accumulated.has(key): accumulated[key]={"zombie":zombie,"damage":0.0,"head":false,"result":result,"dir":direction}
  accumulated[key]["damage"]+=amount
  accumulated[key]["head"]=accumulated[key]["head"] or headshot
 for record: Dictionary in accumulated.values():
  var zombie: Node=record["zombie"]
  var result: Dictionary=record["result"]
  zombie.take_damage(record["damage"],false,{"pos":result["position"],"dir":record["dir"],"normal":result["normal"]})
  hit.emit(zombie,record["head"],zombie.is_dead())
 return true
func _pose(_delta: float) -> void:
 if _gun==null: return
 if state=="holster":
  # Freeze the current grip and open action while the whole weapon lowers.
  # Reversing draw here would snap an interrupted reload closed on screen.
  var lower: float=smoothstep(0.0,0.22,clock)
  _pivot.transform=_holster_start
  _pivot.position+=Vector3(0,-0.50*lower,0.12*lower)
  return
 var reload_t: float=clock if state=="reload" else 0.0
 var clip: String="idle"
 var sample: float=fmod(idle_time,3.0)
 if state=="holster":
  clip="draw"
  sample=(1.0-clampf(clock/0.22,0.0,1.0))*_arms_anim.get_animation(clip).length
 elif state=="draw":
  clip="draw"
  sample=clampf(clock/DRAW_TIME,0.0,1.0)*_arms_anim.get_animation(clip).length
 elif state=="reload":
  # The reference keeps the stock hand planted throughout the break-action reload.
  # The pack reload is for a bottom-fed pump gun; its wrist motion fights this gun.
  clip="idle"
  sample=0.0
 elif state=="inspect":
  clip="inspect"
  sample=clampf(clock/3.2,0.0,1.0)*3.2
 elif cooldown>0.15:
  clip="fire"
  sample=clampf((0.42-cooldown)/0.27,0.0,1.0)*0.2666667
 _left_hand.position=Vector3(0.0312899,-0.0274160,-0.0141472)
 _left_hand.rotation=Vector3.ZERO
 _left_forearm.transform=Transform3D.IDENTITY
 _arms_anim.play(clip,0.0)
 _arms_anim.seek(sample,true)
 var reload_weight: float=smoothstep(0.0,0.55,reload_t)*(1.0-smoothstep(2.80,3.4,reload_t))
 # Lower ready pose leaves more of the centre clear, as in the video.
 var settle: float=(1.0-reload_weight)*(1.0-aim_weight)*clampf(1.0-recoil,0.0,1.0)
 var breath: float=sin(idle_time*1.7)*0.0015*settle
 _pivot.position=Vector3(-sway.x,sway.y-0.115+breath,-0.10)+Vector3(-0.035,0.015,0.015)*reload_weight
 # Roll the breech towards the player while keeping the right wrist fixed to the stock.
 _pivot.rotation=Vector3(0.12,0.62,-0.30)*reload_weight
 var anchor:=Vector3(0.20,-0.20,-0.50)
 _pivot.position+=anchor-_pivot.basis*anchor+Vector3(0,0.02,0)*reload_weight
 _gun_anim.play("reload_empty" if state=="reload" else "idle",0.0)
 _gun_anim.seek(minf(reload_t,RELOAD_TIME),true)
 if state=="reload":
  for i in 2:
   if _reload_initial_loaded[i]:
    # Leave an unfired shell in its chamber instead of ejecting it like a spent case.
    var bone: int=_mechanics.find_bone("shell_left" if i==0 else "shell_right")
    var seated: Transform3D=_mechanics.get_bone_rest(bone)
    _mechanics.set_bone_pose_position(bone,seated.origin)
    _mechanics.set_bone_pose_rotation(bone,seated.basis.get_rotation_quaternion())
 _pump.position=Vector3(0,0.078,0.280)
 var support:=Vector3(0.015,0.24,0.18)
 var hinge: Transform3D=_mechanics.get_bone_global_pose(_mechanics.find_bone("barrel_hinge"))
 var rest: Transform3D=_mechanics.get_bone_global_rest(_mechanics.find_bone("barrel_hinge"))
 var moving: Vector3=(hinge*rest.affine_inverse())*support
 var left_point: Vector3=moving
 if state=="reload":
  var shell_l: Vector3=_shell_grip_point(0)
  var shell_r: Vector3=_shell_grip_point(1)
  # Fetch stays in frame; both insertions approach the breech from above.
  var pocket: Vector3=_gun.to_local(camera.to_global(Vector3(-0.17,-0.22,-0.52)))
  var lift: Vector3=_gun.global_basis.inverse()*camera.global_basis*Vector3(-0.025,0.105,0.055)
  if not _reload_plan[0]:shell_l=pocket
  if not _reload_plan[1]:shell_r=moving
  var keys: Array=[ [0.0,moving],[0.30,moving],[0.75,pocket],[1.25,shell_l+lift],[1.55,shell_l+lift*0.5],[1.75,shell_l],[1.95,shell_l],[2.08,shell_l+lift],[2.18,shell_r+lift],[2.28,shell_r],[2.45,shell_r],[2.65,shell_r+lift],[2.95,moving],[3.4,moving] ]
  for i in keys.size()-1:
   if reload_t<=float(keys[i+1][0]):
    var u: float=smoothstep(float(keys[i][0]),float(keys[i+1][0]),reload_t)
    left_point=(keys[i][1] as Vector3).lerp(keys[i+1][1],u)
    break
 # A palm-space anchor keeps the grasp on the fore-end/shell as the wrist rotates.
 var support_basis: Basis=_gun.global_basis.orthonormalized()*(hinge.basis*rest.basis.inverse()).orthonormalized()*_support_basis_in_gun
 var loading_weight: float=smoothstep(0.35,1.15,reload_t)*(1.0-smoothstep(2.60,3.10,reload_t)) if state=="reload" else 0.0
 # Finger ends point down into the chambers; the palm and sleeve stay above/left.
 var loading_basis: Basis=camera.global_basis*Basis.from_euler(Vector3(-PI/2,0.18,-0.30))*Basis(Vector3.UP,PI)
 _left_hand.global_basis=Basis(support_basis.get_rotation_quaternion().slerp(loading_basis.get_rotation_quaternion(),loading_weight))
 _hand_anchor=_grip_in_hand.lerp(Vector3(-0.028,-0.005,0.105),loading_weight)
 _left_hand.global_position=_gun.to_global(left_point)-_left_hand.global_basis*_hand_anchor
 # Keep the sleeve coming from below-left instead of following the barrel's full tilt.
 var elbow: Vector3=camera.to_global(Vector3(-0.48,-0.55,0.05))
 var direction: Vector3=_left_hand.global_basis.inverse()*(elbow-_left_hand.global_position).normalized()
 var turn:=Quaternion(_forearm_direction,direction.normalized())
 var length_scale: float=lerpf(1.0,maxf(1.0,_left_hand.global_position.distance_to(elbow)/0.40),loading_weight)
 var axis: Vector3=_forearm_direction
 var stretch:=Basis(Vector3.RIGHT+axis*axis.x*(length_scale-1.0),Vector3.UP+axis*axis.y*(length_scale-1.0),Vector3.BACK+axis*axis.z*(length_scale-1.0))
 _left_forearm.basis=Basis(Quaternion.IDENTITY.slerp(turn,lerpf(0.90,1.0,loading_weight)))*stretch
 var sight: Vector3=camera.to_local(_gun.to_global(Vector3(0,0.36,-0.02)))
 _pivot.position+=Vector3(-sight.x,-sight.y-0.015,0)*aim_weight
 _pivot.position+=Vector3(0,0.022,0.105)*recoil
 _pivot.rotation+=Vector3(0.18,-0.018,-0.022)*recoil
 _update_shell_visibility()
func _shell_grip_point(index: int) -> Vector3:
 var bone: int=_mechanics.find_bone("shell_left" if index==0 else "shell_right")
 var shell: Transform3D=_mechanics.get_bone_global_pose(bone)
 return _gun.to_local(_mechanics.to_global(shell*Vector3(0,0,0.012)))
func _update_shell_visibility() -> void:
 for i in 2:
  var approaching: bool=state=="reload" and _reload_plan[i] and clock>=(1.45 if i==0 else 2.05)
  var show_shell: bool=loaded[i] or approaching or (state=="reload" and clock<0.75)
  for part in 3:
   _shell_materials[i*3+part].set_shader_parameter("visible_part",show_shell)
func _shot_sound() -> void:
 if DisplayServer.get_name()=="headless":return
 _shot_voice=(_shot_voice+1)%_shot_voices.size()
 _sound=_shot_voices[_shot_voice]
 _sound.play()
func _click() -> void:
 if DisplayServer.get_name()=="headless":return
 _mechanism_sound.stream=Sounds.sound("mechanism")
 _mechanism_sound.play()
