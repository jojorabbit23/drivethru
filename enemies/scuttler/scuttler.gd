# The Scuttler: fast, small, fragile intruder. A mushroom on two boots.
#
#   LANE     sprint down the approach lane
#   BREACH   ram the boards with its cap, knocking them out from the BOTTOM
#   CLIMB    dive through as soon as two neighbouring boards are gone (it
#            doesn't need the whole window open), cap squashed flat
#   HUNT     run you down round the building (nearly your sprint speed)
#   ATTACK   hop in and dropkick your shins
#   STAGGER  every solid hit knocks it back (it's light)
#   DEAD     keels over, kicks twice, its glowing spots fade out
#
# The cap is the weak spot (head hitbox, x1.5 damage). From eye height the
# cap covers its legs, so most shots hit the cap: two pistol hits kill it
# either way; a knife stab kills outright, a slash leaves it on 15. Every hit
# knocks it back. It stands knee-high, so you aim down.
# Same interface as the Shambler (setup/take_damage/is_dead/died/state/window).
extends CharacterBody3D

const Ooze = preload("res://core/ooze.gd")

signal died(zombie: Node)

enum State { LANE, BREACH, CLIMB, HUNT, ATTACK, STAGGER, DEAD }

@export var max_health := 55.0
@export var lane_speed := 3.2
@export var hunt_speed := 3.4
@export var turn_rate := 12.0
@export var attack_range := 1.05
@export var attack_damage := 8.0
@export var head_multiplier := 1.5
@export var knockback := 2.6
@export var corpse_time := 8.0

const RAM_HIT := 0.42      # seconds into "ram" when the cap hits the boards
const RAM_SPEED := 0.82    # ram clip playback: one ram per 1.1 s, just slower
                           # than a 0.9 s repair, so holding E keeps one out
const RAM_STANDOFF := 0.55 # metres out from the wall where it rams from
const KICK_HIT := 0.30     # seconds into "kick" when the boots connect
const DIVE_TIME := 0.8
const RUN_CLIP_SPEED := 3.1  # m/s the run clip's feet travel at speed_scale 1

var state := State.LANE
var health := 0.0
var window: Node3D
var target: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _resume_state := State.HUNT
var _anim_prev := 0.0
var _kick_landed := false
var _repath := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _push := Vector3.ZERO   # knockback velocity, decays

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var agent: NavigationAgent3D = $NavigationAgent3D

func setup(win: Node3D, player: Node3D) -> void:
	window = win
	target = player

func _ready() -> void:
	add_to_group("zombies")
	health = max_health
	agent.avoidance_enabled = true
	agent.radius = 0.45
	agent.neighbor_distance = 4.0
	agent.max_neighbors = 8
	agent.time_horizon_agents = 0.8
	agent.max_speed = hunt_speed
	agent.velocity_computed.connect(_on_safe_velocity)
	_add_cap_hitbox()
	if window == null:
		window = _nearest_window()
	if target == null:
		target = get_tree().get_first_node_in_group("player")
	_play("run")
	anim.seek(randf() * 0.36, true)
	state = State.LANE

# ------------------------------------------------------------ damage ----
func take_damage(amount: float, headshot := false, hit := {}) -> void:
	if state == State.DEAD:
		return
	var dir: Vector3 = hit.get("dir", -global_basis.z)
	if hit.has("pos"):
		Ooze.get_fx(self).spray(hit["pos"], dir, hit.get("normal", -dir), 1.4 if headshot else 0.8, headshot)
	health -= amount * (head_multiplier if headshot else 1.0)
	if health <= 0.0:
		_die()
		return
	if state in [State.HUNT, State.ATTACK, State.LANE]:
		var away := Vector3(dir.x, 0.0, dir.z).normalized()
		_push = away * knockback
		_resume_state = State.HUNT if state == State.ATTACK else state
		state = State.STAGGER
		_play("flinch", 0.04)
		anim.seek(0.0, true)

func is_dead() -> bool:
	return state == State.DEAD

func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	_push = Vector3.ZERO
	collision_layer = 0
	collision_mask = 1
	var cap := find_child("CapHitbox", true, false) as Area3D
	if cap:
		cap.collision_layer = 0
	_play("death", 0.08)
	# its glow dies with it
	var body := $Model/Skeleton3D/Body as MeshInstance3D
	var m := (body.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	body.material_override = m
	create_tween().tween_property(m, "emission_energy_multiplier", 0.0, 2.2).set_delay(0.4)
	get_tree().create_timer(0.9).timeout.connect(func():
		if is_instance_valid(self):
			Ooze.get_fx(self).pool(global_position + global_basis.x * -0.35, 0.9))
	remove_from_group("zombies")
	died.emit(self)
	get_tree().create_timer(corpse_time).timeout.connect(queue_free)

# ------------------------------------------------------------- update ----
func _physics_process(delta: float) -> void:
	match state:
		State.LANE: _lane(delta)
		State.BREACH: _ram(delta)
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

func ram_spot() -> Vector3:
	var p: Vector3 = window.breach_point() - window.outward() * (0.8 - RAM_STANDOFF)
	p.y = global_position.y
	return p

func _lane(delta: float) -> void:
	if window == null:
		state = State.HUNT
		return
	if window.small_gap() >= 0 and global_position.distance_to(ram_spot()) < 2.0:
		_start_dive()
		return
	var to: Vector3 = ram_spot() - global_position
	to.y = 0.0
	if to.length() < 0.2:
		velocity.x = 0.0
		velocity.z = 0.0
		state = State.BREACH
		_play("ram", 0.1)
		anim.seek(0.0, true)
		_anim_prev = 0.0
		return
	_steer(to.normalized(), lane_speed, delta)
	_play("run")
	anim.speed_scale = lane_speed / RUN_CLIP_SPEED
	# something (another zombie) in the way at the window: start ramming here
	if global_position.distance_to(_last_pos) < 0.004 and to.length() < 1.6:
		_stuck_t += delta
		if _stuck_t > 0.4:
			_stuck_t = 0.0
			state = State.BREACH
			_play("ram", 0.1)
			_anim_prev = 0.0
	else:
		_stuck_t = 0.0
	_last_pos = global_position

func _ram(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_face(-window.outward(), delta)
	if window.small_gap() >= 0:
		_start_dive()
		return
	_play("ram")
	anim.speed_scale = RAM_SPEED
	var p := anim.current_animation_position
	if _anim_prev < RAM_HIT and p >= RAM_HIT:
		window.rip_board(true)   # bottom-up
		if window.small_gap() >= 0:
			_start_dive.call_deferred()
	_anim_prev = p

func _start_dive() -> void:
	if state == State.CLIMB or state == State.DEAD:
		return
	var gi: int = window.small_gap()
	if gi < 0:
		return
	state = State.CLIMB
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_play("dive", 0.06)
	anim.seek(0.0, true)
	var w := window
	var floor_y: float = w.gap_floor(gi)
	var outside: Vector3 = w.to_global(Vector3(0, 0, 0.25))
	outside.y = floor_y + 0.05
	var inside: Vector3 = w.to_global(Vector3(0, 0, -0.5))
	inside.y = floor_y + 0.05
	var land: Vector3 = w.repair_point()
	rotation.y = _yaw_of(-w.outward())
	var tw := create_tween()
	var start := ram_spot()
	if Vector2(start.x - global_position.x, start.z - global_position.z).length() > 0.3:
		tw.tween_property(self, "global_position", Vector3(start.x, global_position.y, start.z), 0.25)
	tw.tween_interval(DIVE_TIME * 0.15)
	tw.tween_property(self, "global_position", outside, DIVE_TIME * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", inside, DIVE_TIME * 0.25)
	tw.tween_property(self, "global_position", land, DIVE_TIME * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.finished.connect(_end_dive)

func _end_dive() -> void:
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
		_kick_landed = false
		_play("kick", 0.06)
		anim.seek(0.0, true)
		return
	_repath -= delta
	if _repath <= 0.0:
		agent.target_position = target.global_position
		_repath = 0.2
	var dir := agent.get_next_path_position() - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		dir = to_player
	_face(dir.normalized(), delta)
	agent.velocity = dir.normalized() * hunt_speed
	_play("run")
	anim.speed_scale = Vector2(velocity.x, velocity.z).length() / RUN_CLIP_SPEED + 0.25
	if global_position.distance_to(_last_pos) < 0.003:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	_last_pos = global_position
	if _stuck_t > 0.6:
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
	agent.velocity = Vector3.ZERO
	var t := anim.current_animation_position
	var to := Vector3.ZERO
	if target and is_instance_valid(target):
		to = target.global_position - global_position
		to.y = 0.0
		if t < 0.14:
			_face(to.normalized(), delta)
	# lunge forward through the hop
	var fwd := -global_basis.z
	var lunge := 2.4 if t > 0.14 and t < 0.4 else 0.0
	velocity.x = fwd.x * lunge
	velocity.z = fwd.z * lunge
	if not _kick_landed and t >= KICK_HIT and target and is_instance_valid(target):
		_kick_landed = true
		if to.length() < attack_range + 0.45 and fwd.dot(to.normalized()) > 0.3:
			if target.has_method("take_damage"):
				target.take_damage(attack_damage, self)
	if not anim.is_playing() or anim.current_animation != "kick":
		state = State.HUNT

func _stagger(delta: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	_push = _push.move_toward(Vector3.ZERO, 9.0 * delta)
	if not anim.is_playing() or anim.current_animation != "flinch":
		_push = Vector3.ZERO
		state = _resume_state
		if state == State.BREACH:
			_play("ram", 0.1)
			_anim_prev = anim.current_animation_position

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
		if name != "run":
			anim.speed_scale = RAM_SPEED if name == "ram" else 1.0

func _can_see(t: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), t.global_position + Vector3(0, 0.6, 0), 1, [get_rid()])
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

# The cap is the weak spot: a broad, flat hitbox that follows the cap bone
# (so it squashes, tilts and topples with the animation).
func _add_cap_hitbox() -> void:
	var skel := $Model/Skeleton3D as Skeleton3D
	var ba := BoneAttachment3D.new()
	ba.name = "CapAttach"
	ba.bone_name = "cap"
	skel.add_child(ba)
	var area := Area3D.new()
	area.name = "CapHitbox"
	area.collision_layer = 8
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("zombie", self)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.46
	cyl.height = 0.42
	cs.shape = cyl
	cs.position = Vector3(0, 0.2, 0)
	area.add_child(cs)
	ba.add_child(area)
