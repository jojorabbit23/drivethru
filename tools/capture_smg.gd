# The SMG viewmodel: idle, firing, tactical reload and empty reload.
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tools/capture_smg.gd
extends SceneTree
var main: Node3D
func _initialize() -> void:
	create_timer(90).timeout.connect(func() -> void: quit(1))
	run.call_deferred()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/smg_" + name + ".png")

func frames(n: int) -> void:
	for i in n:
		await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	await process_frame
	main.hatch.auto = false
	var player: Node = main.player
	player.set_process_unhandled_input(false)
	main.get_node("ClarityHUD").visible = false
	main.economy.cash = 1000
	var terminal: Node = main.terminal
	assert(terminal.buy_smg(player))
	var smg: Node = player.weapon_named("SMG")
	assert(player.current_weapon() == smg)
	await frames(40)
	await shot("idle")
	smg.shoot()
	await frames(2)
	await shot("fire")
	smg.mag = 12
	smg.reload()
	await frames(int(smg.reload_time * 60.0 * 0.4))
	await shot("reload")
	await frames(int(smg.reload_time * 60.0))
	smg.mag = 0
	smg.reload()
	await frames(int(smg.reload_time * 60.0 * 0.7))
	await shot("reload_empty")
	quit()
