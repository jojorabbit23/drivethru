extends SceneTree
const Prefs=preload("res://presentation/preferences.gd")
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func run() -> void:
	check(ProjectSettings.get_setting("display/window/stretch/mode")=="viewport","fullscreen keeps a fixed render resolution")
	var main: Node3D=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	await process_frame
	var budget: Node=main.player.get_node("Presentation/ShadowBudget")
	budget.refresh()
	check(budget.lights.size()>2,"authored shadow lights are retained")
	Prefs.values.full_shadows=false
	budget.apply_budget()
	var enabled: int=0
	for light: OmniLight3D in budget.lights:
		if light.shadow_enabled:enabled+=1
	check(budget.lights.all(func(light: OmniLight3D)->bool:return light.omni_shadow_mode==OmniLight3D.SHADOW_DUAL_PARABOLOID),"shadow lights use two-pass dual paraboloid maps")
	check(enabled==2,"balanced mode bounds expensive shadow cubemaps")
	main.player.position=Vector3(-3,0,2.4)
	budget.apply_budget()
	var closest: OmniLight3D=budget.lights[0]
	for light: OmniLight3D in budget.lights:
		if light.global_position.distance_squared_to(main.player.global_position)<closest.global_position.distance_squared_to(main.player.global_position):closest=light
	check(closest.shadow_enabled,"shadows follow the player to a different room")
	Prefs.values.full_shadows=true
	budget.apply_budget()
	check(budget.lights.all(func(light: OmniLight3D)->bool:return light.shadow_enabled),"full lighting restores every authored shadow")
	Prefs.values.full_shadows=false
	main.free()
	for i in 3:await process_frame
	print("%d failure(s)" % failures)
	quit(1 if failures else 0)
