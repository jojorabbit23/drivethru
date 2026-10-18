# First-person survival knife with the PSX pack's corrected knife rig.
#   LMB  slash  — quick right-to-left sweep, 40 damage, wide arc
#   RMB  stab   — slower thrust, 75 damage; a stab to the head gets the
#                 zombie's headshot multiplier; instant kill from behind
#   (a slash that clips the head is a normal hit — only a stab is precise)
# Hits land on a specific frame of each swing. A hit on a zombie sprays ooze
# in the direction of the cut; hitting a wall or board just clinks.
# Lives under Player/Head/Camera3D; the player switches weapons via
# set_active().
extends Node3D

signal hit(target: Node, headshot: bool, killed: bool)
signal swung(kind: String)

const VIEWMODEL := preload("res://weapons/knife/knife_viewmodel.tscn")
const VIEW_OFFSET := Vector3(0.0, -0.015, -0.025)
# Blend the authored elbow halfway toward the right while retaining the grip.
const RIGHT_ELBOW_DIRECTION := Vector3(0.33, -0.18, 0.14)
const GRIP_ROLL := -0.314159265 # -18 degrees: expose the curled fingers as in the reference.
const UPRIGHT_ANGLE := 0.261799388 # 15 degrees; rotate the complete grip about the wrist.
const STAB_CONTACT := 7.0 / 30.0
const Hitscan = preload("res://core/hitscan.gd")

@export var slash_damage := 40.0
@export var stab_damage := 75.0
@export var reach := 1.6            # metres from the eye
@export var backstab_angle := 0.3   # how far behind (dot) counts as a backstab

# Rest pose (camera space): low right, tip forward and slightly inward.
const REST_POS := Vector3(0.17, -0.18, -0.28)
const REST_ROT := Vector3(6.0, 12.0, -22.0)   # degrees: pitch, yaw, roll

# Keyframes: [time, position, rotation_degrees]. hit = when damage is dealt.
const SLASH := {
	"length": 0.5, "hit": 0.15,
	"keys": [
		[0.0, Vector3(0.17, -0.18, -0.28), Vector3(6, 12, -22)],
		[0.09, Vector3(0.34, -0.06, -0.26), Vector3(14, -30, -78)],   # wind up, out to the right
		[0.2, Vector3(-0.2, -0.26, -0.4), Vector3(-12, 62, -112)],    # sweep across
		[0.5, Vector3(0.17, -0.18, -0.28), Vector3(6, 12, -22)],
	]}
const STAB := {
	"length": 0.72, "hit": 0.24,
	"keys": [
		[0.0, Vector3(0.17, -0.18, -0.28), Vector3(6, 12, -22)],
		[0.16, Vector3(0.24, -0.15, -0.17), Vector3(18, 26, -30)],    # draw back, blade cocked inward
		[0.24, Vector3(0.11, -0.12, -0.46), Vector3(10, 24, -38)],    # thrust in from the lower right
		[0.36, Vector3(0.12, -0.13, -0.44), Vector3(10, 24, -38)],    # hold
		[0.72, Vector3(0.17, -0.18, -0.28), Vector3(6, 12, -22)],
	]}
const DRAW_TIME := 0.32

var active := false
var _pivot: Node3D
var _arms_anim: AnimationPlayer
var _visual_clip := ""
var _skeleton: Skeleton3D
var _right_forearm := -1
var _right_hand := -1
var _forearm_length := 0.4
var _attack: Dictionary = {}
var _attack_t := 0.0
var _attack_kind := ""
var _hit_done := false
var _queued := ""
var _draw_t := 0.0
var _sway := Vector2.ZERO
var _bob_t := 0.0
@onready var camera: Camera3D = get_parent()

func _ready() -> void:
	_pivot = VIEWMODEL.instantiate()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_arms_anim = _pivot.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = _pivot.find_child("Skeleton3D", true, false) as Skeleton3D
	_right_forearm = _skeleton.find_bone("lowerarm_r")
	_right_hand = _skeleton.find_bone("hand_r")
	_forearm_length = _skeleton.get_bone_rest(_right_hand).origin.length()
	_arms_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_sample_clip("kitchen_knife_idle", 0.0)
	_set_pose(REST_POS, REST_ROT)
	visible = active
	if not InputMap.has_action("alt_fire"):
		InputMap.add_action("alt_fire")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("alt_fire", mb)

func set_active(on: bool) -> void:
	active = on
	visible = on
	_attack = {}
	_queued = ""
	if on:
		_draw_t = DRAW_TIME
		_sample_clip("kitchen_knife_draw", 0.0)
	else:
		_arms_anim.pause()

func is_busy() -> bool:
	return not _attack.is_empty() or _draw_t > 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_sway += (event as InputEventMouseMotion).relative * 0.0004

func _physics_process(delta: float) -> void:
	if not active:
		return
	var player := owner as Node
	var dead: bool = player != null and player.has_method("is_dead") and player.is_dead()
	if not dead and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_just_pressed("fire"):
			request("slash")
		elif Input.is_action_just_pressed("alt_fire"):
			request("stab")
	_update(delta)

# Public so tests (and future input schemes) can trigger attacks.
func request(kind: String) -> void:
	if _draw_t > 0.0:
		return
	if _attack.is_empty():
		_start(kind)
	elif _attack_t > _attack["length"] * 0.6:
		_queued = kind  # buffer the next swing during recovery

func _start(kind: String) -> void:
	_attack = SLASH if kind == "slash" else STAB
	_attack_kind = kind
	_attack_t = 0.0
	_hit_done = false
	swung.emit(kind)

func _update(delta: float) -> void:
	# draw: rise into view
	if _draw_t > 0.0:
		_draw_t = maxf(0.0, _draw_t - delta)
		var k := 1.0 - _draw_t / DRAW_TIME
		k = 1.0 - pow(1.0 - k, 3.0)
		_sample_clip("kitchen_knife_draw", (1.0 - _draw_t / DRAW_TIME) * (16.0 / 30.0))
		_set_pose(REST_POS + Vector3(0, -0.05, 0) * (1.0 - k), REST_ROT)
		return
	if not _attack.is_empty():
		_attack_t += delta
		if not _hit_done and _attack_t >= _attack["hit"]:
			_hit_done = true
			_strike()
		if _attack_t >= _attack["length"]:
			_attack = {}
			_sample_clip("kitchen_knife_idle", 0.0)
			_set_pose(REST_POS, REST_ROT)
			if _queued != "":
				var q := _queued
				_queued = ""
				_start(q)
			return
		if _attack_kind == "stab":
			# Frame 7 is full extension: preserve 0.24 s contact and 0.72 s recovery.
			var source_time: float
			if _attack_t <= 0.24:
				source_time = (_attack_t / 0.24) * STAB_CONTACT
			else:
				source_time = lerpf(STAB_CONTACT, 14.0 / 30.0, (_attack_t - 0.24) / 0.48)
			_sample_clip("kitchen_knife_stab", source_time)
			_set_pose(REST_POS, REST_ROT)
		else:
			_sample_clip("kitchen_knife_idle", 0.0)
			_pose_at(_attack, _attack_t)
		return
	# idle: breathe, bob with movement, lag behind mouse look
	var player := owner as CharacterBody3D
	var speed := 0.0
	if player:
		speed = Vector2(player.velocity.x, player.velocity.z).length()
	_bob_t += delta * (1.5 + speed * 1.6)
	_sample_clip("kitchen_knife_idle", fmod(_bob_t * 0.4, 3.0))
	var bob := Vector3(sin(_bob_t) * 0.006 * (0.3 + speed * 0.4), absf(cos(_bob_t)) * 0.008 * (0.2 + speed * 0.4), 0.0)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	var sway := Vector3(-_sway.x, _sway.y, 0.0).limit_length(0.04)
	_set_pose(REST_POS + bob + sway, REST_ROT + Vector3(_sway.y * 60.0, -_sway.x * 60.0, 0.0))

func _pose_at(anim: Dictionary, t: float) -> void:
	var keys: Array = anim["keys"]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t <= b[0]:
			var k: float = (t - a[0]) / maxf(b[0] - a[0], 1e-4)
			k = k * k * (3.0 - 2.0 * k)
			_set_pose((a[1] as Vector3).lerp(b[1], k), (a[2] as Vector3).lerp(b[2], k))
			return
	var last: Array = keys[-1]
	_set_pose(last[1], last[2])

func _set_pose(pos: Vector3, rot_deg: Vector3) -> void:
	# The rig already contains its authored hand/weapon pose. Add only root motion.
	_pivot.position = VIEW_OFFSET + (pos - REST_POS) * 0.45
	_pivot.rotation_degrees = (rot_deg - REST_ROT) * Vector3(0.45, 0.45, 0.40)
	_position_right_forearm()

func _position_right_forearm() -> void:
	# The source elbow starts behind the eye and left of centre. Re-aim the
	# forearm from the right. The upright wrist turn carries knife and fingers together.
	var hand: Transform3D = _skeleton.get_bone_global_pose(_right_hand)
	var upright_weight := 1.0
	if _visual_clip == "kitchen_knife_stab":
		var t: float = _arms_anim.current_animation_position
		upright_weight = 1.0 - smoothstep(4.0 / 30.0, 7.0 / 30.0, t) + smoothstep(10.0 / 30.0, 14.0 / 30.0, t)
	var wrist_axis: Vector3 = (_skeleton.global_basis.inverse() * camera.global_basis.x).normalized()
	var socket_axis: Vector3 = _skeleton.get_bone_global_pose(_skeleton.find_bone("weapon_r")).basis.y.normalized()
	hand.basis = Basis(wrist_axis, UPRIGHT_ANGLE * upright_weight) * Basis(socket_axis, GRIP_ROLL * upright_weight) * hand.basis
	var forearm: Transform3D = _skeleton.get_bone_global_pose(_right_forearm)
	var eye_offset: Vector3 = RIGHT_ELBOW_DIRECTION.normalized() * _forearm_length
	var offset: Vector3 = _skeleton.global_basis.inverse() * camera.global_basis * eye_offset
	var authored_offset: Vector3 = (forearm.origin - hand.origin).normalized()
	offset = authored_offset.slerp(offset.normalized(), 0.5) * _forearm_length
	var elbow: Vector3 = hand.origin + offset
	var y: Vector3 = (hand.origin - elbow).normalized()
	var x: Vector3 = forearm.basis.x.slide(y).normalized()
	if x.length_squared() < 0.001:
		x = y.cross(Vector3.UP).normalized()
	var z: Vector3 = x.cross(y).normalized()
	_skeleton.set_bone_global_pose(_right_forearm, Transform3D(Basis(x, y, z).orthonormalized(), elbow))
	_skeleton.set_bone_global_pose(_right_hand, hand)

func _sample_clip(clip: String, time: float) -> void:
	if _visual_clip != clip:
		_arms_anim.play(clip, 0.0)
		_visual_clip = clip
	# seek(update=true) applies the tracks once; advance(0) repeats that work.
	_arms_anim.seek(time, true)

# ------------------------------------------------------------- hitting ----
func _strike() -> void:
	var space := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var right := camera.global_basis.x
	# a slash sweeps an arc; a stab is a narrow cone
	var angles := [0.0, 10.0, -10.0, 22.0, -22.0, 34.0, -34.0] if _attack_kind == "slash" else [0.0, 4.0, -4.0]
	var pitches := [0.0, -8.0] if _attack_kind == "slash" else [0.0, 3.0, -3.0]
	var best: Dictionary = {}
	var best_d := INF
	var head_hit: Dictionary = {}
	var wall: Dictionary = {}
	for pa in pitches:
		for ya in angles:
			var dir := fwd.rotated(camera.global_basis.y, deg_to_rad(ya)).rotated(right, deg_to_rad(pa))
			var ex: Array[RID] = []
			if owner is CollisionObject3D:
				ex.append((owner as CollisionObject3D).get_rid())
			var res := Hitscan.cast(space, from, from + dir * reach, ex)
			if res.is_empty():
				continue
			var d := from.distance_to(res["position"])
			if _zombie_of(res["collider"]) != null:
				if res["collider"] is Area3D and head_hit.is_empty():
					head_hit = res
				if d < best_d:
					best_d = d
					best = res
			elif wall.is_empty() or d < from.distance_to(wall["position"]):
				wall = res
	if _attack_kind == "stab" and not head_hit.is_empty():
		best = head_hit   # any ray of a stab that finds the head counts as a head stab
	if not best.is_empty():
		var z: Node = _zombie_of(best["collider"])
		var head: bool = _attack_kind == "stab" and best["collider"] is Area3D
		var dmg := slash_damage if _attack_kind == "slash" else stab_damage
		if _attack_kind == "stab" and _is_behind(z):
			dmg = 9999.0  # backstab
		# ooze follows the blade: sideways for a slash, forward for a stab
		var cut_dir := (-right * 0.8 + fwd * 0.6).normalized() if _attack_kind == "slash" else fwd
		z.take_damage(dmg, head, {"pos": best["position"], "dir": cut_dir, "normal": best["normal"]})
		hit.emit(z, head, z.is_dead())
		_kick(0.6)
	elif not wall.is_empty():
		_clink(wall["position"], wall["normal"])
		_kick(1.0)

func _zombie_of(col: Object) -> Node:
	if col is Area3D and (col as Area3D).has_meta("zombie"):
		var z: Node = (col as Area3D).get_meta("zombie")
		return z if is_instance_valid(z) and not z.is_dead() else null
	if col is Node and (col as Node).is_in_group("zombies"):
		return col
	return null

func _is_behind(z: Node) -> bool:
	var zf: Vector3 = -(z as Node3D).global_basis.z
	var to_me := (owner as Node3D).global_position - (z as Node3D).global_position
	to_me.y = 0.0
	zf.y = 0.0
	return zf.normalized().dot(to_me.normalized()) < -backstab_angle

# a little screen kick when the blade connects
func _kick(strength: float) -> void:
	var head := camera.get_parent() as Node3D
	head.rotation.x = minf(head.rotation.x + deg_to_rad(0.6 * strength), deg_to_rad(85.0))

func _clink(at: Vector3, normal: Vector3) -> void:
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	for i in 5:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE * 0.012
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("#E9E1D1")
		b.material = mat
		m.mesh = b
		parent.add_child(m)
		m.global_position = at + normal * 0.01
		var v := (normal + Vector3(randf_range(-0.8, 0.8), randf_range(-0.2, 0.9), randf_range(-0.8, 0.8))).normalized() * randf_range(0.12, 0.25)
		var tw := m.create_tween()
		tw.tween_property(m, "global_position", m.global_position + v, 0.14)
		tw.parallel().tween_property(m, "scale", Vector3.ZERO, 0.14)
		tw.tween_callback(m.queue_free)
