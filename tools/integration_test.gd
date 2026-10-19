extends SceneTree
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func run() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	await process_frame
	var player: Node = main.player
	var pistol: Node3D = player.get_node("Head/Camera3D/TestGun")
	check(player.weapons.size() == 4, "pistol, knife, sawn-off and dagger survive integration")
	check(pistol.visible and pistol.active and pistol._pivot != null, "starting pistol has visible custom viewmodel")
	check(pistol.mag == pistol.mag_size and pistol.mag_size == 12, "OpenCode pistol retains its magazine and shop interface")
	main.economy.cash = 1000
	var reserve: int = pistol.reserve
	check(main.terminal.buy_ammo(player) and pistol.reserve > reserve, "new terminal supplies custom pistol")
	check(main.terminal.buy_shotgun(player), "new terminal purchases pump shotgun")
	check(player.weapons.size() == 5 and player.current_weapon().display_name == "SHOTGUN", "purchase adds pump without replacing original weapons")
	player.current_weapon().add_ammo(1)
	player.switch_weapon(0)
	pistol.ammo_changed.emit(pistol.mag, pistol.reserve)
	check(main._hud.weapon.text.contains("PISTOL") and main._hud.weapon.text.contains("12 /"), "pistol ammo signal updates merged HUD")
	check(main.bench != null and main.tray != null and main.rail != null, "new cooking stations remain loaded")
	main.free()
	for i in 3: await process_frame
	print("%d failure(s)" % failures)
	quit(1 if failures else 0)
