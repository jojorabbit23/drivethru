# PLACEHOLDER hitscan pistol so zombies can be tested before the Glock and
# PSX arms are wired in. Lives under Head/Camera3D. Left click to fire.
# Body shot 34, headshot x3 (one-shot kill on a Shambler).
extends Node3D

const Hitscan = preload("res://core/hitscan.gd")

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

func set_active(on: bool) -> void:
	active = on
	_cooldown = maxf(_cooldown, 0.25)  # brief draw delay
@onready var camera: Camera3D = get_parent()
var _flash: OmniLight3D

func _ready() -> void:
	mag = mag_size
	reserve = start_reserve
	_flash = OmniLight3D.new()
	_flash.light_color = Color("#F3A34D")
	_flash.light_energy = 0.0
	_flash.omni_range = 4.0
	_flash.visible = false  # hidden lights don't use up per-object light slots
	_flash.position = Vector3(0.15, -0.1, -0.4)
	add_child(_flash)

func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _reloading > 0.0:
		_reloading -= delta
		if _reloading <= 0.0:
			var n := mini(mag_size - mag, reserve)
			mag += n
			reserve -= n
			ammo_changed.emit(mag, reserve)
	_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 40.0)
	_flash.visible = _flash.light_energy > 0.0
	var player := owner as Node
	if not active or (player and player.has_method("is_dead") and player.is_dead()):
		return
	if Input.is_action_pressed("fire") and _cooldown <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		shoot()

func add_ammo(n: int) -> void:
	reserve += n
	if mag == 0 and _reloading <= 0.0:
		reload()
	ammo_changed.emit(mag, reserve)

func reload() -> void:
	if _reloading > 0.0 or mag >= mag_size or reserve <= 0:
		return
	_reloading = reload_time
	ammo_changed.emit(mag, reserve)

func is_reloading() -> bool:
	return _reloading > 0.0

# Public so tests and future weapons can call it directly.
# Returns {} without firing when the magazine is empty (and starts a reload).
func shoot() -> Dictionary:
	if not infinite_ammo:
		if _reloading > 0.0:
			return {}
		if mag <= 0:
			_cooldown = fire_interval
			const Sfx = preload("res://game/sfx.gd")
			Sfx.play(self, "click", -8.0)
			reload()
			return {}
		mag -= 1
		ammo_changed.emit(mag, reserve)
		if mag == 0:
			reload()
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
