# Keep nearby room shadows while avoiding cubemap passes for every distant lamp.
extends Node
const Prefs = preload("res://presentation/preferences.gd")
const MAX_NEARBY := 2
var actor: Node3D
var lights: Array[OmniLight3D] = []
var sunlight: Array[Dictionary] = []
var elapsed: float = 0.0
func _ready() -> void:
	actor = get_parent().get_parent() as Node3D
	refresh.call_deferred()
func refresh() -> void:
	if lights.is_empty():
		var scene: Node = actor.get_parent()
		for candidate: OmniLight3D in scene.find_children("*", "OmniLight3D", true, false):
			if candidate.shadow_enabled: lights.append(candidate)
		for sun: DirectionalLight3D in scene.find_children("*", "DirectionalLight3D", true, false):
			sunlight.append({"light":sun,"mode":sun.directional_shadow_mode,"distance":sun.directional_shadow_max_distance})
	apply_budget()
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.5: return
	elapsed = 0.0
	apply_budget()
func apply_budget() -> void:
	if not is_instance_valid(actor): return
	var nearest: Array[OmniLight3D] = lights.duplicate()
	nearest.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool:
		return a.global_position.distance_squared_to(actor.global_position) < b.global_position.distance_squared_to(actor.global_position))
	for i in nearest.size():
		nearest[i].shadow_enabled = bool(Prefs.values["full_shadows"]) or i < MAX_NEARBY
	for settings: Dictionary in sunlight:
		var sun: DirectionalLight3D = settings.light
		sun.directional_shadow_mode = settings.mode if bool(Prefs.values["full_shadows"]) else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = settings.distance if bool(Prefs.values["full_shadows"]) else 35.0
