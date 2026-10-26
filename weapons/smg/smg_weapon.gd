# The SMG (AKS-74U), bought at the shop terminal. Full auto: hold fire.
# Its viewmodel is the whole recoloured AKS-74U rig by Vlasov Daniil (CC BY 4.0,
# CREDITS.md): the same gloved arms as every other weapon, the gun, and the
# rig's own fire, reload (tactical / empty), draw and holster animations.
# Shooting, ammo and the HUD hooks are the pistol's (player/test_gun.gd).
extends "res://player/test_gun.gd"

const SOURCE := "res://weapons/fps_arms/source/aks74u_hands.glb"
const SHADER := preload("res://weapons/fps_arms/fps_arms.gdshader")
const FIRE := "armature|Fire_single"
const RELOAD_TACTICAL := "armature|Reload_t"   # rounds left in the mag
const RELOAD_EMPTY := "armature|Reload_f"      # empty: also works the bolt
const DRAW := "armature|Put_in"
# The rig is authored for a camera at its origin looking down -Z; at our wider
# FOV sit it a little forward, down and right so it reads as a hip carry.
var rig_rest := Vector3(0.04, -0.06, -0.05)
const SPREAD_DEG := 1.6                        # extra random spread once the burst builds
const SPREAD_BUILD := 5                        # shots before it reaches full spread

var _rig: Node3D
var _anim: AnimationPlayer
var _burst := 0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	display_name = "SMG"
	damage = 22.0
	fire_interval = 0.08                       # 750 rounds a minute (12 a second at 60 Hz)
	mag_size = 30
	start_reserve = 60
	reload_time = 2.2
	reach = 45.0
	shot_volume_db = -9.0
	shot_sounds = [preload("res://weapons/pistol/audio/gun_103.wav"), preload("res://weapons/pistol/audio/gun_105.wav")]

func _ready() -> void:
	_rng.randomize()
	for i in 6:                                # fast fire needs more voices than the pistol
		var voice := AudioStreamPlayer.new()
		voice.bus = "Effects"
		voice.volume_db = shot_volume_db
		voice.pitch_scale = 1.15
		add_child(voice)
		_shot_voices.append(voice)
	mag = mag_size
	reserve = start_reserve
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_pivot.visible = active
	_rig = (load(SOURCE) as PackedScene).instantiate()
	_rig.name = "Rig"
	_pivot.add_child(_rig)
	for mi in _rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.material_override = _material(m.mesh.surface_get_material(0) as BaseMaterial3D)
	_anim = _rig.find_children("*", "AnimationPlayer", true, false)[0]
	_anim.play(FIRE)
	_anim.seek(0.0, true)
	_anim.pause()
	# the draw ends in its own pose: settle back to the firing rest afterwards
	_anim.animation_finished.connect(func(clip: StringName):
		if clip == DRAW and not is_reloading():
			_reset_mechanism())
	_set_pose(rig_rest, Vector3.ZERO)
	_flash = OmniLight3D.new()
	_flash.light_color = Color("#F3A34D")
	_flash.light_energy = 0.0
	_flash.omni_range = 4.0
	_flash.visible = false
	_flash.position = Vector3(0.02, -0.08, -1.0)   # by the muzzle, rig space
	_pivot.add_child(_flash)

func _material(src: BaseMaterial3D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	if src:
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		m.set_shader_parameter("normal_tex", src.normal_texture)
		m.set_shader_parameter("roughness_tex", src.roughness_texture)
		m.set_shader_parameter("use_normal", src.normal_texture != null)
		m.set_shader_parameter("albedo_color", src.albedo_color)
	return m

func set_active(on: bool) -> void:
	super.set_active(on)
	_burst = 0
	if on and _anim:
		_anim.speed_scale = DRAW_SPEED
		_anim.play(DRAW, 0.0)

const DRAW_SPEED := 2.2   # Put_in is 1 s; draw in under half a second

# The rig's draw must finish before it can fire.
func request_fire() -> bool:
	if _anim and _anim.current_animation == DRAW and _anim.is_playing():
		return false
	return super.request_fire()

func shoot() -> Dictionary:
	if not can_act() or is_reloading() or mag <= 0:
		_burst = 0
		return super.shoot()
	# bloom: the first rounds go where you aim, a held burst spreads a little
	var head := camera.get_parent() as Node3D
	var spread := deg_to_rad(SPREAD_DEG) * clampf(float(_burst) / SPREAD_BUILD, 0.0, 1.0)
	var keep := Vector2(camera.rotation.x, camera.rotation.y)
	camera.rotation.x += _rng.randf_range(-spread, spread)
	camera.rotation.y += _rng.randf_range(-spread, spread)
	var pitch_before := head.rotation.x
	var res := super.shoot()
	camera.rotation.x = keep.x
	camera.rotation.y = keep.y
	# lighter kick than the pistol's 1.2 deg, but it adds up over a burst
	head.rotation.x = minf(pitch_before + deg_to_rad(0.45), deg_to_rad(85.0))
	_burst += 1
	if _anim and not is_reloading():
		_anim.speed_scale = 1.0
		_anim.play(FIRE, 0.0)
		_anim.seek(0.0, true)
	return res

func _physics_process(delta: float) -> void:
	if not Input.is_action_pressed("fire"):
		_burst = 0
	super._physics_process(delta)

# The rig's clip (tactical 3.25 s, empty 4.6 s) at the game's reload pace.
func _play_reload() -> void:
	if _anim == null:
		return
	var clip := RELOAD_EMPTY if mag == 0 else RELOAD_TACTICAL
	_anim.speed_scale = _anim.get_animation(clip).length / maxf(reload_time, 0.01)
	_anim.play(clip, 0.05)

func _reset_mechanism() -> void:
	if _anim == null:
		return
	_anim.speed_scale = 1.0
	_anim.play(FIRE, 0.1)
	_anim.seek(0.0, true)
	_anim.pause()

# Code adds only bob, sway and a small kick: the rig animates everything else.
func _animate(delta: float) -> void:
	var pos := rig_rest
	var rot := Vector3.ZERO
	var kick := 0.0
	if _shot_t < 0.12:
		kick = clampf(_shot_t / 0.015, 0.0, 1.0) * (1.0 - smoothstep(0.015, 0.12, _shot_t))
	pos += Vector3(0.0, 0.004, 0.018) * kick
	rot += Vector3(1.2, 0.0, 0.0) * kick
	var player := owner as CharacterBody3D
	var speed := 0.0
	if player:
		speed = Vector2(player.velocity.x, player.velocity.z).length()
	_bob_t += delta * (1.5 + speed * 1.6)
	pos += Vector3(sin(_bob_t) * 0.005 * (0.3 + speed * 0.4),
		absf(cos(_bob_t)) * 0.006 * (0.2 + speed * 0.4) + sin(_bob_t * 0.5) * 0.002, 0.0)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	pos += Vector3(-_sway.x, _sway.y, 0.0).limit_length(0.035)
	rot += Vector3(_sway.y * 40.0, -_sway.x * 40.0, 0.0)
	var target := Transform3D(Basis.from_euler(rot * PI / 180.0), pos)
	_pivot.transform = _pivot.transform.interpolate_with(target, 1.0 - exp(-30.0 * delta))
