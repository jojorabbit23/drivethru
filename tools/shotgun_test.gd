# Shotgun checks (headless):
#   godot --headless --path . --fixed-fps 60 --script res://tools/shotgun_test.gd
extends SceneTree

const Shotgun = preload("res://weapons/shotgun/shotgun_weapon.gd")

var main: Node3D
var player: CharacterBody3D
var sg: Node
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1

func wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func wait_s(seconds: float) -> void:
	await wait(int(seconds * 60.0))

# Fresh scene, shotgun bought and drawn, player in the kitchen facing east,
# and a frozen enemy `dist` metres ahead (aim at `aim_y` above its feet).
func setup(scene: String, dist: float, aim_y := 1.2) -> Node3D:
	if main:
		main.queue_free()
		await process_frame
		var old := root.get_node_or_null("OozeFX")
		if old:
			old.queue_free()
		await process_frame
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	await wait(5)
	sg = Shotgun.new()
	sg.name = "Shotgun"
	player.add_weapon(sg)
	sg._rng.seed = 7
	var ppos := Vector3(1.6, 0, -1.4)
	player.global_position = ppos + Vector3(0, 0.05, 0)
	player.rotation.y = -PI / 2.0
	await wait(40)                       # draw
	var zpos := ppos + Vector3(dist, 0, 0)
	var z: Node3D
	match scene:
		"lancer":
			z = main.spawn_lancer(main.get_node("ShopGreybox/Windows/Window_A"))
		_:
			z = main.spawn_zombie(main.get_node("ShopGreybox/Windows/Window_A"))
	z.state = 3
	z.global_position = zpos
	z.rotation.y = atan2(1.0, 0.0)       # facing the player (west)
	await wait(2)
	z.set_physics_process(false)
	z.velocity = Vector3.ZERO
	await wait(3)
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var to := zpos + Vector3(0, aim_y, 0) - cam.global_position
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await wait(2)
	return z

func st(z: Node) -> String:
	return String(z.State.keys()[z.state])

func _run() -> void:
	print("== buying it")
	var z := await setup("shambler", 2.5)
	check(player.weapon_index == player.weapons.size() - 1 and sg.active and sg.visible, "add_weapon puts it in the next slot and draws it")
	check(player.weapons.size() == 4 and player.weapon_named("SHOTGUN") == sg, "slot 4, found by name")
	player.switch_weapon(0)
	await wait(2)
	check(not sg.visible and not sg.active, "1 holsters it")
	player.switch_weapon(3)
	await wait(30)
	check(sg.active, "4 draws it again")

	print("== damage")
	check(absf(sg.damage_at(3.0) - 15.0) < 0.01 and absf(sg.damage_at(20.0) - 5.25) < 0.01 and sg.damage_at(13.0) < 15.0 and sg.damage_at(13.0) > 5.25, "15 a pellet up to 6 m, down to 5.25 by 20 m (13 m: %.1f)" % sg.damage_at(13.0))
	var res: Array = sg.shoot()
	check(res.size() == 8, "8 pellets (%d hit something)" % res.size())
	await wait(2)
	check(z.is_dead(), "one blast at 2.5 m kills a Shambler")
	check(sg.mag == 5, "one shell used (%d left)" % sg.mag)

	print("== pump")
	check(sg.shoot().is_empty(), "can't fire again until it's pumped")
	var base_z: float = sg._pump.position.z
	await wait_s(0.4)
	check(sg._pump.position.z > base_z + 0.03, "the fore-end racks back with the left hand on it (%.3f m)" % (sg._pump.position.z - base_z))
	await wait_s(0.45)
	check(not sg.shoot().is_empty() or sg.mag == 4, "ready again after the 0.8 s cycle")
	check(sg.mag == 4, "%d in the tube" % sg.mag)

	print("== loading")
	await wait_s(0.85)
	for i in 4:
		sg.shoot()
		await wait_s(0.85)
	check(sg.mag == 0 or sg.is_reloading(), "empty after 6 shots (tube %d)" % sg.mag)
	var reserve0: int = sg.reserve
	await wait_s(1.0)
	check(sg.is_reloading() and sg.mag == 2 and sg.reserve == reserve0 - 2, "it loads one shell every 0.45 s from the spare (tube %d, spare %d)" % [sg.mag, sg.reserve])
	sg.shoot()
	check(sg.mag == 1 and not sg.is_reloading(), "firing interrupts the reload")
	await wait_s(0.8 + 1.5 + 0.45 * 4 + 0.2)
	check(sg.mag == 5 and sg.reserve == 0, "left alone it tops the tube up with what's left (tube %d, spare %d)" % [sg.mag, sg.reserve])
	sg.add_ammo(12)
	await wait_s(0.45 + 0.2)
	check(sg.mag == 6 and sg.reserve == 11, "bought shells top it up to 6 (tube %d, spare %d)" % [sg.mag, sg.reserve])

	print("== spread")
	var hits := 0
	z = await setup("shambler", 4.0, 1.2)
	z.set_meta("unused", true)
	sg.pellet_damage = 0.0                # count pellets only
	var pitch: float = player.get_node("Head").rotation.x
	for i in 3:
		await wait_s(0.85)
		player.get_node("Head").rotation.x = pitch     # re-aim after the kick
		await wait(1)
		for r: Dictionary in sg.shoot():
			hits += 1 if String(r.get("kind", "")) != "world" else 0
	sg.pellet_damage = 15.0
	check(hits > 12 and hits < 24, "at 4 m most pellets, not all, land on a Shambler (%d of 24)" % hits)

	print("== the Lancer")
	z = await setup("lancer", 2.2, 1.7)
	z.set_physics_process(true)
	sg.shoot()
	await wait(2)
	check(not z.is_dead() and st(z) == "STAGGER", "a blast to the Lancer's cap staggers it (%s, health %.0f)" % [st(z), z.health])
	await wait_s(0.85)
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var to: Vector3 = z.global_position + Vector3(0, 1.1, 0) - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await wait(1)
	sg.shoot()
	await wait(2)
	check(z.is_dead(), "and a second one kills it (%s, health %.0f)" % [st(z), z.health])

	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
