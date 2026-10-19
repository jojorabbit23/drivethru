# A glowing mushroom dropped by dead Shamblers and Scuttlers.
# It pops out of the body, lands hovering above the floor, then spins, bobs
# and pulses a soft orange glow until the player walks into it. Within
# magnet_range (with a clear line through walls; boards don't block) it drifts
# to the player, so one dropped just outside a window can still be collected.
#   var p := MushroomPickup.new(); add_child(p); p.drop(from, ground_y)
class_name MushroomPickup
extends Node3D

signal collected(pickup: Node3D)

# Accessibility (docs/GAME_DESIGN.md "Auto Collect Pickups"): every pickup
# flies to the player from anywhere once it has landed. main.gd toggles it (F2).
static var auto_collect := false

const MESH := preload("res://pickups/mushroom/mushroom_pickup_mesh.res")
const Palette = preload("res://core/palette.gd")

@export var hover := 0.42          # height of its centre above the floor
@export var spin_speed := 1.8      # rad/s
@export var bob := 0.05            # bob amplitude (m)
@export var magnet_range := 2.6
@export var collect_range := 0.75
@export var value := 1

var _t := randf() * TAU
var _ready_to_collect := false
var _taken := false
var _home := Vector3.ZERO
var _magnet := false
var _model: MeshInstance3D
var _light: OmniLight3D
var _halo: ShaderMaterial

func _ready() -> void:
	add_to_group("pickups")
	_model = MeshInstance3D.new()
	_model.name = "Mesh"
	_model.mesh = MESH
	_model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_model)
	# own copy of the halo so each pickup pulses on its own beat
	var mat := (MESH.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	_halo = (mat.next_pass as ShaderMaterial).duplicate() as ShaderMaterial
	mat.next_pass = _halo
	_model.material_override = mat
	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.light_color = Palette.AMBER_GLOW
	_light.light_energy = 0.7
	_light.omni_range = 1.4
	_light.omni_attenuation = 1.6
	_light.shadow_enabled = false
	add_child(_light)
	_home = global_position

# Pops up out of `from` and lands hovering at `ground_y + hover`, a little to
# one side (kept clear of walls).
func drop(from: Vector3, ground_y: float) -> void:
	var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 0.45
	var land := from + side
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.5, 0), land + Vector3(0, 0.5, 0), 1)
	if not space.intersect_ray(q).is_empty():
		land = from
	var down := PhysicsRayQueryParameters3D.create(land + Vector3(0, 1.0, 0), land - Vector3(0, 2.0, 0), 1)
	var ground := space.intersect_ray(down)
	land.y = ((ground["position"] as Vector3).y if not ground.is_empty() else ground_y) + hover
	global_position = from + Vector3(0, 0.5, 0)
	_home = land
	scale = Vector3.ONE * 0.3
	var arc := create_tween().set_parallel(true)
	arc.tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	arc.tween_method(func(k: float):
		var p := (from + Vector3(0, 0.5, 0)).lerp(land, k)
		p.y += sin(PI * k) * 0.45
		global_position = p, 0.0, 1.0, 0.55)
	arc.chain().tween_callback(func(): _ready_to_collect = true)

func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	rotation.y = wrapf(rotation.y + spin_speed * delta, -PI, PI)
	var pulse := 0.8 + 0.2 * sin(_t * 2.6)
	_light.light_energy = 0.7 * pulse
	_halo.set_shader_parameter("pulse", pulse)
	if not _ready_to_collect:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var target := _home + Vector3(0, bob * sin(_t * 2.2), 0)
	if player and not (player.has_method("is_dead") and player.is_dead()):
		var chest := player.global_position + Vector3(0, 1.1, 0)
		var d := global_position.distance_to(chest)
		if d < collect_range:
			_collect(player)
			return
		if auto_collect:
			_magnet = true
			target = chest
		elif d < magnet_range and (_magnet or _sees(chest)):
			_magnet = true
			target = chest
			# below a window sill: rise until there's a clear line, then fly in
			if not _clear_line(global_position, chest):
				target = global_position + Vector3(0, 1, 0)
		else:
			_magnet = false
	else:
		_magnet = false
	var speed := (9.0 if auto_collect else 5.0) if _magnet else 2.5
	global_position = global_position.move_toward(target, speed * delta)

# Can it reach the player? Tried from its own height and from just above, so
# one hovering under a window sill still counts.
func _sees(to: Vector3) -> bool:
	for up in [0.0, 0.5, 0.9]:
		if _clear_line(global_position + Vector3(0, up, 0), to):
			return true
	return false

func _clear_line(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)   # world only: boards don't block
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _collect(player: Node3D) -> void:
	_taken = true
	if player.has_method("add_mushrooms"):
		player.add_mushrooms(value)
	collected.emit(self)
	remove_from_group("pickups")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * 1.4, 0.08)
	tw.tween_property(_light, "light_energy", 2.0, 0.08)
	tw.chain().tween_property(self, "scale", Vector3.ONE * 0.01, 0.14)
	tw.chain().tween_callback(queue_free)

func is_collectable() -> bool:
	return _ready_to_collect and not _taken
