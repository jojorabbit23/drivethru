# The pistol, slot 1. Lives under Head/Camera3D. Left click to fire.
# Body shot 34, headshot x3 (one-shot kill on a Shambler).
# The shot itself is still hitscan; the viewmodel
# is selected per weapon: original teal starter or gold Desert Eagle, both
# in Cleatimus's gloved hands. Code supplies draw rise and recoil; each
# AnimationPlayer drives its own mechanical parts.
# Starter pistol and purchasable Desert Eagle share mechanics and bounded audio voices.
extends Node3D

const Hitscan = preload("res://core/hitscan.gd")
const Sfx = preload("res://game/sfx.gd")
const FpsArms = preload("res://weapons/fps_arms/fps_arms.gd")
@export var viewmodel_scene: PackedScene = preload("res://weapons/pistol/starter_pistol_viewmodel.tscn")

# Rest pose (camera space): low right, muzzle forward.
@export var shot_sounds: Array[AudioStream] = [preload("res://weapons/pistol/audio/shot.wav")]
@export var slide_sound: AudioStream
@export var shot_volume_db := -6.0
var _slide_voice: AudioStreamPlayer
var _arms: Node3D   # shared Pistol 43 arms: shoots one-handed, left hand in for reloads
var _reload_slide_played := false
var _shot_voices: Array[AudioStreamPlayer] = []
var _shot_index := 0
const REST_POS := Vector3(0.13, -0.15, -0.26)
const REST_ROT := Vector3(0.0, 0.0, 0.0)   # degrees: pitch, yaw, roll
const DRAW_TIME := 0.28

signal hit(target: Node, headshot: bool, killed: bool)
signal fired
signal ammo_changed(mag: int, reserve: int)

@export var damage := 34.0
@export var fire_interval := 0.22
@export var reach := 60.0
@export var mag_size := 12
@export var reload_time := 1.1
@export var start_reserve := 36   # 12 + 36 to start; buy more at the shop terminal
@export var infinite_ammo := false

var mag := 12
var reserve := 36
var _reloading := 0.0

var _cooldown := 0.0
var active := true
var display_name: String = "PISTOL"
var _pivot: Node3D
var _view_anim: AnimationPlayer
var _draw_t := 0.0
var _bob_t := 0.0
var _sway := Vector2.ZERO
var _shot_t := 99.0
var _support: Node3D
var _support_rest: Transform3D

func set_active(on: bool) -> void:
	active = on
	if not on:
		for voice in _shot_voices: voice.stop()
		if _slide_voice: _slide_voice.stop()
	_cooldown = maxf(_cooldown, 0.25)  # brief draw delay
	if on:
		_draw_t = DRAW_TIME
		if _view_anim and _view_anim.has_animation("rack"):
			_view_anim.speed_scale = 1.0
			_view_anim.play("rack", 0.0)
			_play_slide()
	else:
		_reloading = 0.0
		if _view_anim:
			_reset_mechanism()
		if _support: _support.transform = _support_rest
	if _pivot:
		_pivot.visible = on
@onready var camera: Camera3D = get_parent()
var _flash: OmniLight3D

func _ready() -> void:
	for i in 4:
		var voice := AudioStreamPlayer.new()
		voice.bus = "Effects"
		voice.volume_db = shot_volume_db
		add_child(voice)
		_shot_voices.append(voice)
	_slide_voice = AudioStreamPlayer.new()
	_slide_voice.bus = "Effects"
	_slide_voice.volume_db = -9.0
	add_child(_slide_voice)
	mag = mag_size
	reserve = start_reserve
	_pivot = viewmodel_scene.instantiate() as Node3D
	_pivot.name = "Pivot"
	add_child(_pivot)
	_pivot.visible = active
	_view_anim = _pivot.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_support = _pivot.get_node("Model/SupportSocket")
	_support_rest = _support.transform
	_set_pose(REST_POS, REST_ROT)
	# shared AKS arms reach for the old hand sockets (weapons/fps_arms/fps_arms.gd)
	var right: Node3D = _pivot.get_node("Model/GripSocket/RightHand")
	var left: Node3D = _pivot.get_node("Model/SupportSocket/LeftHand")
	_arms = FpsArms.attach(_pivot, right, left, "pistol", [right, left])
	_flash = OmniLight3D.new()
	_flash.light_color = Color("#F3A34D")
	_flash.light_energy = 0.0
	_flash.omni_range = 4.0
	_flash.visible = false  # hidden lights don't use up per-object light slots
	var muzzle: Node3D = _pivot.find_child("MuzzleTip", true, false) as Node3D
	if muzzle:
		muzzle.add_child(_flash)   # the flash sits where the barrel ends
	else:
		_flash.position = Vector3(0.15, -0.1, -0.4)
		add_child(_flash)

func _physics_process(delta: float) -> void:
	_cooldown -= delta
	_shot_t += delta
	if _reloading > 0.0:
		_reloading -= delta
		if not _reload_slide_played and _reloading <= reload_time * (1.0 - 1.14 / 1.6):
			_reload_slide_played = true
			_play_slide()
		if _reloading <= 0.0:
			var n := mini(mag_size - mag, reserve)
			mag += n
			reserve -= n
			_reset_mechanism()
			ammo_changed.emit(mag, reserve)
	_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 40.0)
	_flash.visible = _flash.light_energy > 0.0
	if active:
		_animate(delta)
	var player := owner as Node
	if not active or (player and player.has_method("is_dead") and player.is_dead()):
		return
	if Input.is_action_pressed("fire") and _cooldown <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		request_fire()

func can_act() -> bool:
	return active and not (owner and owner.has_method("is_dead") and owner.is_dead())

func request_fire() -> bool:
	if not can_act() or _draw_t > 0.0 or _cooldown > 0.0 or is_reloading():
		return false
	var before: int = mag
	shoot()
	return infinite_ammo or mag < before

func add_ammo(n: int) -> void:
	reserve += n
	if mag == 0 and _reloading <= 0.0:
		reload()
	ammo_changed.emit(mag, reserve)

func reload() -> void:
	if not can_act() or _reloading > 0.0 or mag >= mag_size or reserve <= 0:
		return
	_reload_slide_played = false
	_reloading = reload_time
	_play_reload()
	ammo_changed.emit(mag, reserve)

# The mechanical clip is 1.6 s; run it at the game's reload pace so its slide rack
# lands just as the fresh magazine goes back in.
func _play_reload() -> void:
	if _view_anim == null:
		return
	var clip: Animation = _view_anim.get_animation("reload")
	if clip == null:
		return
	_view_anim.speed_scale = clip.length / maxf(reload_time, 0.01)
	_view_anim.play("reload", 0.04)

# Restore the physical parts too when a reload finishes or is cancelled.
func _reset_mechanism() -> void:
	if not _view_anim: return
	_view_anim.speed_scale = 1.0
	_view_anim.play("RESET", 0.0)
	_view_anim.advance(0.0)
	_view_anim.stop()

func is_reloading() -> bool:
	return _reloading > 0.0

# Public so tests and future weapons can call it directly.
# Returns {} without firing when the magazine is empty (and starts a reload).
func shoot() -> Dictionary:
	if not can_act():
		return {}
	if not infinite_ammo:
		if _reloading > 0.0:
			return {}
		if mag <= 0:
			_cooldown = fire_interval
			Sfx.play(self, "click", -8.0)
			reload()
			return {}
		mag -= 1
		ammo_changed.emit(mag, reserve)
	_cooldown = fire_interval
	_shot_t = 0.0
	if _view_anim:
		_view_anim.play("fire", 0.04)
	if mag == 0 and not infinite_ammo:
		reload()
	_flash.light_energy = 3.0
	_flash.visible = true
	_play_shot()
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
	Hitscan.damage_prop(res, damage)
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

func _play_shot() -> void:
	if DisplayServer.get_name() == "headless": return
	var voice: AudioStreamPlayer = _shot_voices[_shot_index % _shot_voices.size()]
	voice.stream = shot_sounds[_shot_index % shot_sounds.size()]
	voice.play()
	_shot_index += 1

func _play_slide() -> void:
	if slide_sound == null or not _slide_voice or DisplayServer.get_name() == "headless": return
	_slide_voice.stream = slide_sound
	_slide_voice.play()

func _spark(at: Vector3) -> void:
	if DisplayServer.get_name() == "headless": return
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

# ---------------------------------------------------------- viewmodel ----
func _animate(delta: float) -> void:
	var progress: float = 1.0 - _reloading / reload_time if is_reloading() else 0.0
	var release: float = smoothstep(0.0, 0.18, progress) * (1.0 - smoothstep(0.72, 1.0, progress))
	_support.transform = _support_rest
	# Match the magazine's extraction/insertion phases, then settle back onto the grip.
	var magazine_travel: float = smoothstep(0.1, 0.275, progress) * (1.0 - smoothstep(0.4375, 0.70625, progress))
	_support.position += Vector3(-0.025, -0.03, -0.01) * release + Vector3(0.0, -0.13, -0.03) * magazine_travel
	if _arms:
		_arms.left_weight = release
	var pos := REST_POS
	var rot := REST_ROT
	# Bring the magazine well into view while the support hand changes the magazine.
	pos += Vector3(-0.02, 0.025, 0.015) * release
	rot += Vector3(12.0, -18.0, -14.0) * release
	# draw: rise into view
	if _draw_t > 0.0:
		_draw_t = maxf(0.0, _draw_t - delta)
		var k := 1.0 - pow(_draw_t / DRAW_TIME, 3.0)
		pos += Vector3(0.0, -0.1, 0.04) * (1.0 - k)
		rot += Vector3(-18.0, 0.0, 6.0) * (1.0 - k)
	# recoil: back and up, then settle
	var kick := 0.0
	if _shot_t < 0.2:
		kick = clampf(_shot_t / 0.02, 0.0, 1.0) * (1.0 - smoothstep(0.02, 0.2, _shot_t))
	pos += Vector3(0.0, 0.02, 0.055) * kick
	rot += Vector3(9.0, 0.0, 1.5) * kick
	# idle: breathe, bob with movement, lag behind mouse look
	var player := owner as CharacterBody3D
	var speed := 0.0
	if player:
		speed = Vector2(player.velocity.x, player.velocity.z).length()
	_bob_t += delta * (1.5 + speed * 1.6)
	pos += Vector3(sin(_bob_t) * 0.005 * (0.3 + speed * 0.4),
		absf(cos(_bob_t)) * 0.006 * (0.2 + speed * 0.4) + sin(_bob_t * 0.5) * 0.002, 0.0)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	pos += Vector3(-_sway.x, _sway.y, 0.0).limit_length(0.035)
	rot += Vector3(_sway.y * 55.0, -_sway.x * 55.0, 0.0)
	var target := Transform3D(Basis.from_euler(rot * PI / 180.0), pos)
	_pivot.transform = target if _draw_t > 0.0 else _pivot.transform.interpolate_with(target, 1.0 - exp(-30.0 * delta))

func _set_pose(pos: Vector3, rot_deg: Vector3) -> void:
	_pivot.transform = Transform3D(Basis.from_euler(rot_deg * PI / 180.0), pos)

func _unhandled_input(event: InputEvent) -> void:
	if can_act() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		reload()
		get_viewport().set_input_as_handled()
	if active and event is InputEventMouseMotion:
		_sway += (event as InputEventMouseMotion).relative * 0.0004
