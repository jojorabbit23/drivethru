# The SMG (weapons/smg/smg_weapon.gd): bought at the terminal, full auto, a
# 30-round mag with its own reserve and ammo purchase, reloads (tactical and
# empty clips), draw blocks firing, shots damage enemies, accurate first shots.
#   godot --headless --path . --fixed-fps 60 --script res://tools/smg_test.gd
extends SceneTree
var failures := 0

func _initialize() -> void:
	create_timer(60).timeout.connect(func() -> void: print("TIMEOUT"); quit(1))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func run() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	main.auto_spawn = false
	root.add_child(main)
	await process_frame
	main.hatch.auto = false
	var player: Node = main.player
	player.set_physics_process(false)
	var terminal: Node = main.terminal
	var count: int = player.weapons.size()
	check(not player.has_weapon("SMG"), "the SMG is not a starting weapon")
	terminal.page = "weapons"
	var rows: Array = terminal.options(player)
	var row := {}
	for r: Dictionary in rows:
		if "SMG" in String(r.label):
			row = r
	check(not row.is_empty() and "$%d" % main.economy.SMG_PRICE in String(row.label), "the weapons page sells it (%s)" % String(row.get("label", "")))
	main.economy.cash = main.economy.SMG_PRICE - 1
	check(not terminal.buy_smg(player) and main.economy.cash == main.economy.SMG_PRICE - 1, "can't buy it without the cash")
	main.economy.cash = main.economy.SMG_PRICE + 50
	check(terminal.buy_smg(player) and main.economy.cash == 50, "purchase charges $%d" % main.economy.SMG_PRICE)
	var smg: Node = player.weapon_named("SMG")
	check(smg != null and player.weapons.size() == count + 1 and player.current_weapon() == smg, "bought SMG goes in a new slot and is equipped")
	check(not terminal.buy_smg(player) and main.economy.cash == 50, "no second SMG")
	check(smg.mag == 30 and smg.reserve == 60, "30 in the mag, 60 spare")
	smg.set_physics_process(false)
	check(not smg.request_fire(), "can't fire during the draw")
	for i in 40:
		await process_frame          # the rig's draw clip plays out
	smg._draw_t = 0.0
	smg._cooldown = 0.0
	# full auto: one second holding the trigger
	var shots := 0
	for i in 60:
		smg._physics_process(1.0 / 60.0)
		if smg.request_fire():
			shots += 1
	check(shots >= 10 and shots <= 13 and smg.mag == 30 - shots, "full auto: %d rounds in a second" % shots)
	check(smg.damage < 34.0 and smg.damage * 11.0 > 34.0 / 0.22 * 1.0, "less per round than the pistol, far more per second")
	# reload: tactical keeps the reserve honest
	var reserve: int = smg.reserve
	var before: int = smg.mag
	smg.reload()
	check(smg.is_reloading() and smg._anim.current_animation == smg.RELOAD_TACTICAL, "rounds left: the tactical reload clip")
	smg._physics_process(smg.reload_time + 0.05)
	check(smg.mag == 30 and smg.reserve == reserve - (30 - before), "reload tops up from the reserve")
	smg.mag = 0
	smg.reload()
	check(smg._anim.current_animation == smg.RELOAD_EMPTY and is_equal_approx(smg._anim.speed_scale, smg._anim.get_animation(smg.RELOAD_EMPTY).length / smg.reload_time), "empty: the bolt-pull clip, timed to the reload")
	smg._physics_process(smg.reload_time + 0.05)
	# ammo
	main.economy.cash = 100
	var pistol_reserve: int = (player.weapon_named("PISTOL") as Node).reserve
	reserve = smg.reserve
	check(terminal.buy_smg_ammo(player) and smg.reserve == reserve + 30 and main.economy.cash == 100 - main.economy.SMG_AMMO_PRICE, "SMG rounds: +30 for $%d" % main.economy.SMG_AMMO_PRICE)
	check((player.weapon_named("PISTOL") as Node).reserve == pistol_reserve, "pistol reserve untouched")
	# accuracy: the first shot goes exactly where the camera points
	var cam: Camera3D = player.camera
	var rot_before := cam.rotation
	smg._cooldown = 0.0
	smg._burst = 6                     # full spread
	smg.shoot()
	check(cam.rotation.is_equal_approx(rot_before), "the camera is put back after a spread shot (only the recoil kick stays)")
	# damage: a Shambler in front of the camera takes 22 a round
	var z: Node3D = load("res://enemies/shambler/shambler.tscn").instantiate()
	main.add_child(z)
	(cam.get_parent() as Node3D).rotation.x = 0.0   # level the view after the bursts' kick
	var ahead := -cam.global_basis.z
	ahead.y = 0.0
	z.global_position = cam.global_position + ahead.normalized() * 4.0 - Vector3(0, 1.5, 0)
	for i in 3:
		await physics_frame
	var hp: float = z.health
	smg._cooldown = 0.0
	smg._burst = 0
	var res: Dictionary = smg.shoot()
	check(not res.is_empty() and z.health < hp, "a round hits the Shambler (%.0f -> %.0f)" % [hp, z.health])
	# switching away and back
	player.switch_weapon(0)
	check(not smg.active and not smg._pivot.visible, "hidden when holstered")
	player.switch_weapon(player.weapons.find(smg))
	check(smg.active and smg._anim.current_animation == smg.DRAW, "draws again when re-equipped")
	print("\nSMG: %d failure(s)" % failures)
	quit(1 if failures else 0)
