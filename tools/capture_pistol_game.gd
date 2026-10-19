extends SceneTree
var main: Node3D
var gun: Node3D
func _initialize() -> void: run.call_deferred()
func snap(label: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/pistol_game_" + label + ".png"))
func run() -> void:
	Engine.max_fps = 30
	root.size = Vector2i(1280,720)
	main = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	var player: CharacterBody3D = main.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.global_position = Vector3(1.4,0.05,-1.4)
	player.rotation.y = -PI/2
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gun = player.get_node("Head/Camera3D/TestGun")
	gun.set_physics_process(false)
	gun._physics_process(0.5)
	await snap("idle")
	gun.shoot()
	gun._physics_process(0.04)
	await snap("fire")
	gun.reload()
	gun._physics_process(0.5)
	gun._view_anim.seek(0.6,true)
	await snap("reload")
	main.free()
	for i in 3: await process_frame
	quit()
