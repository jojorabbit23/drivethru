extends SceneTree
func _initialize() -> void:
	create_timer(25.0).timeout.connect(func() -> void:quit(1))
	run.call_deferred()
func snap(label: String) -> void:
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/hollowhead_"+label+".png"))
func run() -> void:
	Engine.max_fps=30
	root.size=Vector2i(1280,720)
	var main: Node3D=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	var player: Node3D=main.player
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_unhandled_input(false)
	for weapon: Node3D in player.weapons:weapon.hide();weapon.set_physics_process(false)
	for child: Node in main.get_children():
		if child is CanvasLayer:child.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var enemy: Node3D=main.spawn_hollowhead()
	enemy.set_physics_process(false)
	enemy.position=Vector3(3,.02,-2.4)
	enemy.rotation.y=PI
	var camera: Camera3D=player.camera
	camera.global_position=Vector3(3,1.1,-.35)
	camera.look_at(enemy.global_position+Vector3(0,.9,0))
	camera.fov=65
	for entry: Array in [["idle",.3],["shamble",.35],["swing",.62],["swing_left",.62],["slam",.62],["death",1.6]]:
		enemy.anim.play(entry[0],0)
		enemy.anim.seek(entry[1],true)
		enemy.anim.pause()
		await snap(entry[0])
	enemy.take_damage(10000)
	for i in 12:await process_frame
	await snap("spores")
	player.global_position=enemy.global_position+Vector3(0,0,1)
	camera.global_position=enemy.global_position+Vector3(0,1.5,1.3)
	camera.look_at(enemy.global_position+Vector3(0,1.55,0))
	var exposure: Node3D=preload("res://enemies/hollowhead/spore_burst.gd").new()
	exposure.position=enemy.global_position+Vector3(0,1.55,0)
	var before: float=player.health
	main.add_child(exposure)
	assert(exposure.exposed and player.health==before-3,"native short-range spore exposure")
	await snap("exposure")
	for i in 55:await process_frame
	assert(not is_instance_valid(exposure),"spore obstruction clears")
	main.free()
	for i in 3:await process_frame
	print("PASS Hollowhead Vulkan pose and spore captures")
	quit()
