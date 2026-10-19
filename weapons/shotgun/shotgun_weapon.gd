# Pump-action shotgun, bought at the shop terminal (slot 4).
#   LMB   fire: 8 pellets in a 3.5 degree cone, 15 each up close, falling off
#         to 35% by 20 m. Pellets that hit the same zombie add up into one
#         body hit and one head hit (x the zombie's head multiplier), so a
#         close blast kills a Shambler and staggers a Lancer.
#   pump  automatic after each shot (0.8 s cycle; hold LMB to keep firing)
#   load  6-shell tube, loaded one shell at a time from your reserve: when it
#         runs dry, or by itself after 1.5 s without firing. Firing interrupts
#         a reload if there's a shell in the tube.
# The viewmodel (weapons/shotgun/shotgun_model.tscn, tools/build_shotgun.gd) is
# animated in code: kick, pump (the left hand rides the fore-end), shell loading.
# Sounds are requested by name ("shotgun", "pump", "shell"); game/sfx.gd plays
# silence for names it doesn't know yet.
extends Node3D

const Hitscan = preload("res://core/hitscan.gd")
const Sfx = preload("res://game/sfx.gd")
const Palette = preload("res://core/palette.gd")
const MODEL := preload("res://weapons/shotgun/shotgun_model.tscn")

signal hit(target: Node, headshot: bool, killed: bool)
signal fired
signal pumped
signal shell_loaded
signal ammo_changed(mag: int, reserve: int)

@export var pellets := 8
@export var pellet_damage := 15.0
@export var spread_deg := 3.5
@export var falloff_start := 6.0
@export var falloff_end := 20.0
@export var falloff_min := 0.35
@export var reach := 40.0
@export var tube_size := 6
@export var cycle_time := 0.8      # shot to ready: kick + pump
@export var shell_time := 0.45     # per shell loaded
@export var top_up_after := 1.5    # idle seconds before it tops the tube up

const REST_POS := Vector3(0.13, -0.19, -0.3)
const REST_ROT := Vector3(1.5, 3.0, 0.0)     # degrees
const DRAW_TIME := 0.4
const PUMP_START := 0.22                     # into the cycle
const PUMP_TRAVEL := 0.09

var display_name := "SHOTGUN"
var mag := 6            # shells in the tube (named like the pistol's for the HUD)
var reserve := 6
var active := false
var _cycle := 0.0       # >0 while kicking / pumping
var _loading := false
var _shell_t := 0.0
var _idle := 0.0
var _draw_t := 0.0
var _bob_t := 0.0
var _sway := Vector2.ZERO
var _pivot: Node3D
var _pump: Node3D
var _hand_l: Node3D
var _hand_l_home := Vector3.ZERO
var _shell: MeshInstance3D
var _flash: OmniLight3D
var _flash_mesh: MeshInstance3D
var _flash_t := 0.0
var _rng := RandomNumberGenerator.new()
@onready var camera: Camera3D = get_parent()

func _ready() -> void:
	_pivot = MODEL.instantiate()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_pump = _pivot.get_node("Pump")
	_hand_l = _pivot.get_node("Pump/PumpSocket")
	_hand_l_home = _hand_l.position
	# a shell in the left hand while loading
	_shell = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.011
	c.bottom_radius = 0.011
	c.height = 0.065
	c.radial_segments = 8
	c.rings = 1
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Palette.BURNT_ORANGE
	c.material = sm
	_shell.mesh = c
	_shell.rotation_degrees.x = 90.0
	_shell.position = Vector3(0.0, -0.02, -0.03)
	_shell.visible = false
	_hand_l.add_child(_shell)
	var muzzle: Node3D = _pivot.get_node("MuzzleTip")
	_flash = OmniLight3D.new()
	_flash.light_color = Palette.AMBER_GLOW
	_flash.omni_range = 5.0
	_flash.light_energy = 0.0
	_flash.visible = false
	muzzle.add_child(_flash)
	_flash_mesh = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Palette.AMBER_GLOW
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_texture = _star_texture()
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	q.material = fm
	_flash_mesh.mesh = q
	_flash_mesh.visible = false
	_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle.add_child(_flash_mesh)
	_set_pose(REST_POS, REST_ROT)
	visible = active

# a chunky 12 px pixel star for the muzzle flash
static func _star_texture() -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 12:
		for x in 12:
			var dx := absf(x - 5.5)
			var dy := absf(y - 5.5)
			if dx + dy < 4.0 or (dx < 1.0 and dy < 6.0) or (dy < 1.0 and dx < 6.0):
				img.set_pixel(x, y, Color.WHITE if dx + dy < 2.5 else Color(1, 1, 1, 0.85))
	return ImageTexture.create_from_image(img)

func set_active(on: bool) -> void:
	active = on
	visible = on
	if on:
		_draw_t = DRAW_TIME
	else:
		_loading = false
		_shell.visible = false
		_cycle = 0.0
		_pump.position.z = -0.37

func is_reloading() -> bool:
	return _loading

func is_busy() -> bool:
	return _cycle > 0.0 or _draw_t > 0.0

func add_ammo(n: int) -> void:
	reserve += n
	ammo_changed.emit(mag, reserve)

func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventMouseMotion:
		_sway += (event as InputEventMouseMotion).relative * 0.0004

func _physics_process(delta: float) -> void:
	_flash_t = maxf(0.0, _flash_t - delta)
	_flash.light_energy = 4.0 * _flash_t / 0.06
	_flash.visible = _flash_t > 0.0
	_flash_mesh.visible = _flash_t > 0.03
	if not active:
		return
	var player := owner as Node
	var dead: bool = player != null and player.has_method("is_dead") and player.is_dead()
	if not dead and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("fire"):
		shoot()
	_tick(delta)

# Advances timers and the viewmodel. Public for tests (headless has no input).
func _tick(delta: float) -> void:
	if _draw_t > 0.0:
		_draw_t = maxf(0.0, _draw_t - delta)
	if _cycle > 0.0:
		var before := _cycle
		_cycle = maxf(0.0, _cycle - delta)
		var t_in := cycle_time - _cycle
		if cycle_time - before < PUMP_START and t_in >= PUMP_START:
			pumped.emit()
			Sfx.play_at(self, "pump", global_position, -4.0)
	elif _loading:
		_shell_t += delta
		if _shell_t >= shell_time:
			_shell_t = 0.0
			if reserve > 0 and mag < tube_size:
				mag += 1
				reserve -= 1
				shell_loaded.emit()
				ammo_changed.emit(mag, reserve)
				Sfx.play_at(self, "shell", global_position, -6.0)
			if mag >= tube_size or reserve <= 0:
				_loading = false
	else:
		_idle += delta
		if mag < tube_size and reserve > 0 and (mag == 0 or _idle >= top_up_after):
			reload()
	_animate(delta)

func reload() -> void:
	if _loading or mag >= tube_size or reserve <= 0 or _cycle > 0.0:
		return
	_loading = true
	_shell_t = 0.0
	ammo_changed.emit(mag, reserve)

# Fires if it can. Returns the pellets' hit results (empty if it didn't fire).
func shoot() -> Array:
	if _draw_t > 0.0 or _cycle > 0.0:
		return []
	if _loading:
		if mag <= 0:
			return []
		_loading = false        # firing interrupts the reload
	if mag <= 0:
		_cycle = 0.25
		Sfx.play(self, "click", -8.0)
		reload()
		return []
	mag -= 1
	_idle = 0.0
	_cycle = cycle_time
	_flash_t = 0.06
	(_flash_mesh.mesh as QuadMesh).size = Vector2.ONE * _rng.randf_range(0.13, 0.19)
	fired.emit()
	ammo_changed.emit(mag, reserve)
	Sfx.play(self, "shotgun", -2.0)
	var head := camera.get_parent() as Node3D
	head.rotation.x = minf(head.rotation.x + deg_to_rad(3.0), deg_to_rad(85.0))
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var ex: Array[RID] = []
	if owner is CollisionObject3D:
		ex.append((owner as CollisionObject3D).get_rid())
	var space := camera.get_world_3d().direct_space_state
	var per_target := {}          # zombie -> [body damage, head damage, pos, dir]
	var results := []
	for i in pellets:
		var dir := _spread(fwd)
		var res := Hitscan.cast(space, from, from + dir * reach, ex)
		if res.is_empty():
			continue
		results.append(res)
		_spark(res["position"])
		var col: Object = res["collider"]
		var zombie: Node = null
		var headshot := false
		if col is Area3D and (col as Area3D).has_meta("zombie"):
			zombie = (col as Area3D).get_meta("zombie")
			headshot = true
		elif col is Node and (col as Node).is_in_group("zombies"):
			zombie = col
		if zombie == null or not is_instance_valid(zombie) or not zombie.has_method("take_damage"):
			continue
		if not per_target.has(zombie):
			per_target[zombie] = [0.0, 0.0, res["position"], dir]
		var e: Array = per_target[zombie]
		e[1 if headshot else 0] = float(e[1 if headshot else 0]) + damage_at(from.distance_to(res["position"]))
	for z: Node in per_target:
		if not is_instance_valid(z) or z.is_dead():
			continue
		var e: Array = per_target[z]
		var info := {"pos": e[2], "dir": e[3], "normal": -(e[3] as Vector3)}
		var head_hit := float(e[1]) > 0.0
		if head_hit:
			z.take_damage(float(e[1]), true, info)
		if float(e[0]) > 0.0 and not z.is_dead():
			z.take_damage(float(e[0]), false, info)
		hit.emit(z, head_hit, z.is_dead())
	return results

# One pellet's damage at distance d: full up close, down to falloff_min far off.
func damage_at(d: float) -> float:
	return pellet_damage * (1.0 - clampf((d - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0) * (1.0 - falloff_min))

func _spread(fwd: Vector3) -> Vector3:
	# uniform over a cone: random angle round the axis, sqrt for even density
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * deg_to_rad(spread_deg)
	var side := fwd.cross(Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(fwd).normalized()
	return (fwd + (side * cos(a) + up * sin(a)) * tan(r)).normalized()

func _spark(at: Vector3) -> void:
	var m := MeshInstance3D.new()
	var s := BoxMesh.new()
	s.size = Vector3.ONE * 0.03
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Palette.AMBER_GLOW
	s.material = mat
	m.mesh = s
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(m)
	m.global_position = at
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ZERO, 0.15)
	tw.tween_callback(m.queue_free)

# ---------------------------------------------------------- viewmodel ----
func _animate(delta: float) -> void:
	var pos := REST_POS
	var rot := REST_ROT
	# draw: rise into view
	if _draw_t > 0.0:
		var k := 1.0 - pow(_draw_t / DRAW_TIME, 3.0)
		pos += Vector3(0.0, -0.12, 0.05) * (1.0 - k)
		rot += Vector3(-25.0, 0.0, 10.0) * (1.0 - k)
	var pump_z := 0.0
	if _cycle > 0.0 and _cycle <= cycle_time:
		var t := cycle_time - _cycle
		# kick: back and up fast, settle
		var kick := clampf(t / 0.04, 0.0, 1.0) * (1.0 - smoothstep(0.04, 0.24, t))
		pos += Vector3(0.0, 0.025, 0.09) * kick
		rot += Vector3(11.0, 0.0, 2.0) * kick
		# pump: back then forward, the gun dipping and rolling a little
		var pk := clampf((t - PUMP_START) / (cycle_time - PUMP_START - 0.08), 0.0, 1.0)
		var stroke := sin(pk * PI)
		pump_z = PUMP_TRAVEL * stroke
		pos += Vector3(-0.01, -0.012, 0.012) * stroke
		rot += Vector3(-3.0, 2.0, 8.0) * stroke
	# loading: roll the gun to show the port, the left hand feeds a shell
	var hand_off := Vector3.ZERO
	if _loading:
		var lk := clampf(_shell_t / shell_time, 0.0, 1.0)
		var reach_k := sin(lk * PI)
		hand_off = Vector3(-0.01, -0.035, 0.29) * reach_k
		rot += Vector3(4.0, 0.0, -28.0)
		pos += Vector3(-0.03, 0.02, 0.0)
		_shell.visible = lk < 0.55
	else:
		_shell.visible = false
	_pump.position.z = -0.37 + pump_z
	_hand_l.position = _hand_l.position.lerp(_hand_l_home + hand_off, 1.0 - exp(-25.0 * delta))
	# idle: breathe, bob with movement, lag behind mouse look
	var player := owner as CharacterBody3D
	var speed := 0.0
	if player:
		speed = Vector2(player.velocity.x, player.velocity.z).length()
	_bob_t += delta * (1.5 + speed * 1.6)
	pos += Vector3(sin(_bob_t) * 0.006 * (0.3 + speed * 0.4), absf(cos(_bob_t)) * 0.008 * (0.2 + speed * 0.4) + sin(_bob_t * 0.5) * 0.002, 0.0)
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	pos += Vector3(-_sway.x, _sway.y, 0.0).limit_length(0.04)
	rot += Vector3(_sway.y * 60.0, -_sway.x * 60.0, 0.0)
	# the roll eases in and out rather than snapping
	var target := Transform3D(Basis.from_euler(rot * PI / 180.0), pos)
	_pivot.transform = _pivot.transform.interpolate_with(target, 1.0 - exp(-30.0 * delta)) if _draw_t <= 0.0 else target

func _set_pose(pos: Vector3, rot_deg: Vector3) -> void:
	_pivot.transform = Transform3D(Basis.from_euler(rot_deg * PI / 180.0), pos)
