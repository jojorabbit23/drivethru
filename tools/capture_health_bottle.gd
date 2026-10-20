extends SceneTree
func _initialize() -> void:
	create_timer(20.0).timeout.connect(func() -> void:quit(1))
	run.call_deferred()
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
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for weapon: Node3D in player.weapons:weapon.hide()
	var bottle: Node3D=main.drop_health_pickup(Vector3(3,0,-2))
	for i in 30:await process_frame
	bottle.set_process(false)
	var camera: Camera3D=player.camera
	camera.global_position=bottle.global_position+Vector3(0.6,0.45,1.1)
	camera.look_at(bottle.global_position+Vector3(0,0.12,0))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/health_bottle.png"))
	player.health=30
	player.global_position=bottle.global_position-Vector3(0,bottle.hover,0)
	bottle.set_process(true)
	for i in 12:await process_frame
	assert(player.health==80,"native bottle restores 50 HP")
	assert(main._hud["health"].text.contains("HEALTH 80"),"health HUD updates immediately")
	main.free()
	for i in 3:await process_frame
	print("PASS native bottle healing and health HUD")
	quit()
