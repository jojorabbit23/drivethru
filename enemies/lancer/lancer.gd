# The Lancer: tall morel-headed stalker whose forearms end in bone lances.
#
#   LANE     stalks down the approach lane to the window's breach point
#   BREACH   drives both lances between the boards and levers one off
#            (top-down, like a Shambler, a little slower: one per 1.4 s).
#            Its reach is the threat: once there's any gap in the boards it
#            stabs THROUGH at anyone within reach inside (then pries again
#            before the next stab), so repairing a Lancer's window costs health
#   CLIMB    hooks the sill and hauls itself through the empty window
#   HUNT     path to the player round the building (navmesh)
#   ATTACK   rears back and lunges, both lances together: long reach, hits
#            hard, but the wind-up is slow and easy to read; back off and
#            it stabs air
#   STAGGER  only heavy hits (knife stab, headshot) make it flinch
#   DEAD     knees go, pitches forward onto its cap, despawns
#
# The morel cap is the weak spot (head hitbox, x2): three pistol headshots,
# or five to the body. Same interface as the Shambler (setup/take_damage/
# is_dead/died/state/window).
extends CharacterBody3D

const Ooze = preload("res://core/ooze.gd")

signal died(zombie: Node)

enum State { LANE, BREACH, CLIMB, HUNT, ATTACK, STAGGER, DEAD }

@export var max_health := 150.0
@export var lane_speed := 1.3      # matches the stalk stride (1.43 m / 1.1 s)
@export var hunt_speed := 1.6
@export var turn_rate := 5.0
@export var attack_range := 1.8    # starts a lunge from here (the Shambler's is 1.5)
@export var reach := 2.0           # the lunge lands on anything this close in front
@export var attack_damage := 24.0
@export var through_damage := 12.0 # a stab through a gap in the boards
@export var stagger_threshold := 60.0
@export var head_multiplier := 2.0
@export var corpse_time := 10.0

const PRY_MOMENT := 0.95   # seconds into "pry" when the board comes off
const LUNGE_HIT := 0.58    # seconds into "lunge" when the lances land
const CLIMB_TIME := 1.6
const STALK_CYCLE := 1.1

var state := State.LANE
var health := 0.0
var window: Node3D
var target: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var through_window := false       # the current lunge is through the boards
var _pried_since_stab := true     # one stab through, then at least one pry
var _resume_state := State.HUNT
var _anim_prev_pos := 0.0
var _lunge_landed := false
var _repath := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var agent: NavigationAgent3D = $NavigationAgent3D

func setup(win: Node3D, player: Node3D) -> void:
	window = win
	target = player

func _ready() -> void:
	add_to_group("zombies")
	health = max_health
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
	_play("stalk")
	anim.seek(randf() * STALK_CYCLE, true)
	state = State.LANE

# ------------------------------------------------------------ damage ----
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
	get_tree().create_timer(1.3).timeout.connect(func():
		if is_instance_valid(self):
			Ooze.get_fx(self).pool(global_position - global_basis.z * 0.7, 1.6))
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
		_begin_breach()
		return
	_steer(to.normalized(), lane_speed, delta)
	_play("stalk")
	anim.speed_scale = 1.0
	# queued behind another zombie at the window? start prying from here
	if global_position.distance_to(_last_pos) < 0.003 and to.length() < 1.6:
		_stuck_t += delta
		if _stuck_t > 0.5:
			_stuck_t = 0.0
			_begin_breach()
	else:
		_stuck_t = 0.0
	_last_pos = global_position

func _begin_breach() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	state = State.BREACH
	_play("pry", 0.25)
	_anim_prev_pos = 0.0

func _breach(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if through_window:
		_attack_through(delta)
		return
	_face(-window.outward(), delta)
	if window.is_breached():
		if not _window_busy():
			_start_climb()
		else:
			_play("idle")
		return
	# someone repairing behind a gap: stab through it instead of prying
	_play("pry")
	var p := anim.current_animation_position
	# Decides at the end of each pry, so after a board comes off there's about
	# a second before the lances arrive: a prompt repair (0.9 s) closes the gap
	# and the stab hits wood.
	var cycle_end := p < _anim_prev_pos
	if cycle_end and _pried_since_stab and _gap_open() and _in_reach(target, reach):
		_pried_since_stab = false
		through_window = true
		_lunge_landed = false
		_play("lunge", 0.1)
		anim.seek(0.0, true)
		return
	if _anim_prev_pos < PRY_MOMENT and p >= PRY_MOMENT:
		window.rip_board()
		_pried_since_stab = true
	_anim_prev_pos = p

func _gap_open() -> bool:
	return window.boards_left() < window.boards.size()

func _attack_through(_delta: float) -> void:
	if not _lunge_landed and anim.current_animation_position >= LUNGE_HIT:
		_lunge_landed = true
		# the boards went back up in the meantime: the lances thud into wood
		if _gap_open() and _in_reach(target, reach + 0.2):
			_hit(target, through_damage)
	if not anim.is_playing() or anim.current_animation != "lunge":
		through_window = false
		_play("pry", 0.2)
		anim.seek(0.0, true)
		_anim_prev_pos = 0.0

# One at a time through a window (see shambler.gd).
func _window_busy() -> bool:
	for z in get_tree().get_nodes_in_group("zombies"):
		if z == self or not (z is CharacterBody3D) or z.get("window") != window:
			continue
		if z.get("state") == State.CLIMB:
			return true
		if z.get("state") == State.HUNT and (z as Node3D).global_position.distance_to(window.repair_point()) < 0.6:
			return true
	return false

func _start_climb() -> void:
	state = State.CLIMB
	# Keep weapon rays hittable; only movement collision is suspended for entry.
	collision_layer = 8
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
		_lunge_landed = false
		_play("lunge", 0.1)
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
	_play("stalk")
	anim.speed_scale = hunt_speed / lane_speed
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
		# it tracks you through the wind-up, then commits
		if anim.current_animation_position < LUNGE_HIT - 0.2:
			_face(to.normalized(), delta)
		if not _lunge_landed and anim.current_animation_position >= LUNGE_HIT:
			_lunge_landed = true
			if _in_reach(target, reach):
				_hit(target, attack_damage)
	if not anim.is_playing() or anim.current_animation != "lunge":
		anim.speed_scale = 1.0
		state = State.HUNT

func _stagger(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not anim.is_playing() or anim.current_animation != "flinch":
		through_window = false
		state = _resume_state
		if state == State.BREACH:
			_play("pry", 0.15)
			_anim_prev_pos = anim.current_animation_position

# ------------------------------------------------------------ helpers ----
# t is within dist and in the cone in front of it (the lances point forward).
func _in_reach(t: Node3D, dist: float) -> bool:
	if t == null or not is_instance_valid(t) or (t.has_method("is_dead") and t.is_dead()):
		return false
	var to := t.global_position - global_position
	to.y = 0.0
	return to.length() < dist and (-global_basis.z).dot(to.normalized()) > 0.6

func _hit(t: Node3D, dmg: float) -> void:
	if t.has_method("take_damage"):
		t.take_damage(dmg, self)

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
		if name != "stalk":
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

# The morel cap: a sphere on the head bone.
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
	sphere.radius = 0.2
	cs.shape = sphere
	cs.position = Vector3(0, 0.19, 0)
	area.add_child(cs)
	ba.add_child(area)
