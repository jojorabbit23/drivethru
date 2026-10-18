# The Shambler: slow board-ripper.
#
#   LANE     shamble down the approach lane to the window's breach point
#   BREACH   rip boards off one at a time (keeps going if you repair them)
#   CLIMB    scramble through the empty window
#   HUNT     path to the player round the building (navmesh)
#   ATTACK   club swing; hits if you're still in front of it
#   STAGGER  flinch on a heavy hit, then carry on
#   DEAD     topple, stay down, despawn
#
# Spawn with setup(window, player) before adding to the tree, or let it
# pick the nearest window itself.
extends CharacterBody3D

const Ooze = preload("res://core/ooze.gd")

signal died(zombie: Node)

enum State { LANE, BREACH, CLIMB, HUNT, ATTACK, STAGGER, DEAD }

@export var max_health := 100.0
@export var lane_speed := 0.9      # matches the shamble stride (1.32 m / 1.5 s)
@export var hunt_speed := 1.15
@export var turn_rate := 6.0
@export var attack_range := 1.5
@export var attack_damage := 20.0
@export var stagger_threshold := 30.0
@export var head_multiplier := 3.0
@export var corpse_time := 10.0

const RIP_MOMENT := 1.05   # seconds into "rip" when the board comes off
const SWING_HIT := 0.62    # seconds into "swing" when the club connects
const CLIMB_TIME := 1.6

var state := State.LANE
var health := 0.0
var window: Node3D
var target: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _resume_state := State.HUNT
var _anim_prev_pos := 0.0
var _swing_landed := false
var _repath := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var body_shape: CollisionShape3D = $Shape

func setup(win: Node3D, player: Node3D) -> void:
	window = win
	target = player

func _ready() -> void:
	add_to_group("zombies")
	health = max_health
	# Crowd avoidance: zombies flow round each other instead of queuing in doorways.
	agent.avoidance_enabled = true
	agent.neighbor_distance = 4.0
	agent.max_neighbors = 8
	agent.time_horizon_agents = 1.2
	agent.max_speed = hunt_speed
	agent.velocity_computed.connect(_on_safe_velocity)
	_add_head_hitbox()
	if window == null:
		window = _nearest_window()
	if target == null:
		target = get_tree().get_first_node_in_group("player")
	# start out of step with other zombies
	_play("shamble")
	anim.seek(randf() * 1.5, true)
	state = State.LANE

# ------------------------------------------------------------ damage ----
# hit (optional): {"pos": Vector3, "dir": Vector3, "normal": Vector3} — where
# and how it was struck, so the ooze sprays from the wound and lands where
# it would really go.
func take_damage(amount: float, headshot := false, hit := {}) -> void:
	if state == State.DEAD:
		return
	if hit.has("pos"):
		var dir: Vector3 = hit.get("dir", -global_basis.z)
		Ooze.get_fx(self).spray(hit["pos"], dir, hit.get("normal", -dir), 2.0 if headshot else 1.0, headshot)
	var dmg := amount * (head_multiplier if headshot else 1.0)
	health -= dmg
	if health <= 0.0:
		_die()
	elif dmg >= stagger_threshold and state != State.CLIMB and state != State.STAGGER:
		_resume_state = state if state != State.ATTACK else State.HUNT
		state = State.STAGGER
		_play("flinch", 0.05)

func is_dead() -> bool:
	return state == State.DEAD

func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	var head := find_child("HeadHitbox", true, false) as Area3D
	if head:
		head.collision_layer = 0
	_play("death", 0.1)
	# a puddle spreads where the body comes to rest (it topples forward)
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(self):
			Ooze.get_fx(self).pool(global_position - global_basis.z * 0.55, 1.5))
	remove_from_group("zombies")
	died.emit(self)
	get_tree().create_timer(corpse_time).timeout.connect(queue_free)

# ------------------------------------------------------------- update ----
func _physics_process(delta: float) -> void:
	match state:
		State.LANE: _lane(delta)
		State.BREACH: _breach(delta)
		State.CLIMB: return  # driven by a tween
		State.HUNT: _hunt(delta)
		State.ATTACK: _attack(delta)
		State.STAGGER: _stagger(delta)
		State.DEAD: pass
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()

func _lane(delta: float) -> void:
	if window == null:
		state = State.HUNT
		return
	var to: Vector3 = window.breach_point() - global_position
	to.y = 0.0
	if to.length() < 0.25:
		velocity.x = 0.0
		velocity.z = 0.0
		state = State.BREACH
		_play("rip", 0.25)
		_anim_prev_pos = 0.0
		return
	_steer(to.normalized(), lane_speed, delta)
	_play("shamble")
	anim.speed_scale = 1.0
	# Queued behind another zombie near the window? Join in ripping.
	if global_position.distance_to(_last_pos) < 0.003 and to.length() < 1.6:
		_stuck_t += delta
		if _stuck_t > 0.5:
			_stuck_t = 0.0
			velocity.x = 0.0
			velocity.z = 0.0
			state = State.BREACH
			_play("rip", 0.25)
			_anim_prev_pos = 0.0
	else:
		_stuck_t = 0.0
	_last_pos = global_position

func _breach(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_face(-window.outward(), delta)
	if window.is_breached():
		_start_climb()
		return
	_play("rip")
	var p := anim.current_animation_position
	if _anim_prev_pos < RIP_MOMENT and p >= RIP_MOMENT:
		window.rip_board()
	_anim_prev_pos = p

func _start_climb() -> void:
	state = State.CLIMB
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_play("climb", 0.15)
	var w := window
	var sill_y: float = w.global_position.y - (w.get_meta("opening_size") as Vector2).y * 0.5
	var out_sill := w.to_global(Vector3(0, 0, 0.15))
	out_sill.y = sill_y
	var in_sill := w.to_global(Vector3(0, 0, -0.45))
	in_sill.y = sill_y
	var land: Vector3 = w.repair_point()
	rotation.y = _yaw_of(-w.outward())
	var tw := create_tween()
	var bp: Vector3 = w.breach_point()
	if Vector2(bp.x - global_position.x, bp.z - global_position.z).length() > 0.3:
		tw.tween_property(self, "global_position", Vector3(bp.x, global_position.y, bp.z), 0.35)
	tw.tween_property(self, "global_position", out_sill, CLIMB_TIME * 0.32).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "global_position", in_sill, CLIMB_TIME * 0.3)
	tw.tween_property(self, "global_position", land, CLIMB_TIME * 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.finished.connect(_end_climb)

func _end_climb() -> void:
	if state == State.DEAD:
		return
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	state = State.HUNT
	_repath = 0.0

func _hunt(delta: float) -> void:
	if target == null or not is_instance_valid(target) or (target.has_method("is_dead") and target.is_dead()):
		velocity.x = 0.0
		velocity.z = 0.0
		_play("idle")
		return
	var to_player := target.global_position - global_position
	to_player.y = 0.0
	if to_player.length() < attack_range and _can_see(target):
		state = State.ATTACK
		_swing_landed = false
		_play("swing", 0.1)
		anim.seek(0.0, true)
		return
	_repath -= delta
	if _repath <= 0.0:
		agent.target_position = target.global_position
		_repath = 0.3
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		dir = to_player
	_face(dir.normalized(), delta)
	agent.velocity = dir.normalized() * hunt_speed  # -> _on_safe_velocity
	_play("shamble")
	anim.speed_scale = hunt_speed / lane_speed
	# unstick: if we're pushing but not moving, sidestep briefly
	if global_position.distance_to(_last_pos) < 0.002:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	_last_pos = global_position
	if _stuck_t > 0.8:
		var side := Vector3(-dir.z, 0, dir.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
		velocity.x = side.x * hunt_speed
		velocity.z = side.z * hunt_speed
		_stuck_t = 0.0
		_repath = 0.0

func _on_safe_velocity(v: Vector3) -> void:
	if state == State.HUNT:
		velocity.x = v.x
		velocity.z = v.z

func _attack(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	agent.velocity = Vector3.ZERO
	if target and is_instance_valid(target):
		var to := target.global_position - global_position
		to.y = 0.0
		if anim.current_animation_position < SWING_HIT:
			_face(to.normalized(), delta)
		if not _swing_landed and anim.current_animation_position >= SWING_HIT:
			_swing_landed = true
			var fwd := -global_basis.z
			if to.length() < attack_range + 0.3 and fwd.dot(to.normalized()) > 0.35:
				if target.has_method("take_damage"):
					target.take_damage(attack_damage, self)
	if not anim.is_playing() or anim.current_animation != "swing":
		anim.speed_scale = 1.0
		state = State.HUNT

func _stagger(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not anim.is_playing() or anim.current_animation != "flinch":
		state = _resume_state
		if state == State.BREACH:
			_play("rip", 0.15)
			_anim_prev_pos = anim.current_animation_position

# ------------------------------------------------------------ helpers ----
func _steer(dir: Vector3, speed: float, delta: float) -> void:
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(dir, delta)

func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)

func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 1e-4:
		return
	rotation.y = lerp_angle(rotation.y, _yaw_of(dir), 1.0 - exp(-turn_rate * delta))

func _play(name: String, blend := -1.0) -> void:
	if anim.current_animation != name:
		anim.play(name, blend)
		if name != "shamble":
			anim.speed_scale = 1.0

func _can_see(t: Node3D) -> bool:
	var from := global_position + Vector3(0, 1.4, 0)
	var to := t.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _nearest_window() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for w in get_tree().get_nodes_in_group("windows"):
		var d: float = (w as Node3D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = w
	return best

func _add_head_hitbox() -> void:
	var skel := $Model/Skeleton3D as Skeleton3D
	var ba := BoneAttachment3D.new()
	ba.name = "HeadAttach"
	ba.bone_name = "head"
	skel.add_child(ba)
	var area := Area3D.new()
	area.name = "HeadHitbox"
	area.collision_layer = 8
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("zombie", self)
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.19
	cs.shape = sphere
	cs.position = Vector3(0, 0.14, -0.03)
	area.add_child(cs)
	ba.add_child(area)
