# Lancer scenarios (headless):
#   godot --headless --path . --fixed-fps 60 --script res://tools/lancer_test.gd
extends SceneTree

const DT := 1.0 / 60.0
const SPOTS := {
	"shop counter": Vector3(-3.0, 0, -3.4),
	"kitchen line": Vector3(2.6, 0, -3.4),
	"office desk": Vector3(-2.8, 0, 3.0),
	"storeroom door": Vector3(3.0, 0, 4.1),
}
const CLIPS := ["idle", "stalk", "pry", "lunge", "climb", "flinch", "death"]
var main: Node3D
var player: CharacterBody3D
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1

func st(z: Node) -> String:
	return ["LANE", "BREACH", "CLIMB", "HUNT", "ATTACK", "STAGGER", "DEAD"][z.state]

func fresh(ppos := Vector3(-3.0, 0, 3.0), god := true) -> void:
	if main:
		main.queue_free()
		await process_frame
		for n in root.get_children():
			if n is RigidBody3D or n.name == "OozeFX":
				n.queue_free()
		await process_frame
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	if god:
		player.max_health = 1e9
		player.health = 1e9
	for i in 10:
		await physics_frame
	player.global_position = ppos + Vector3(0, 0.05, 0)
	await physics_frame

func win(id: String) -> Node3D:
	return main.get_node("ShopGreybox/Windows/Window_" + id)

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func run_until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while t < limit and not cond.call():
		await physics_frame
		t += DT
	return t

# A Lancer already inside, hunting, at `at`, its behaviour paused.
func parked(at: Vector3) -> Node:
	var z: Node = main.spawn_lancer(win("A"))
	z.state = 3
	z.global_position = at
	await physics_frame
	z.set_physics_process(false)
	return z

func _run() -> void:
	print("== model")
	await fresh()
	var z: Node = main.spawn_lancer(win("A"))
	await frames(2)
	var ap: AnimationPlayer = z.get_node("Model/AnimationPlayer")
	var missing := CLIPS.filter(func(c): return not ap.has_animation(c))
	check(missing.is_empty(), "has all its clips (%s)" % ", ".join(CLIPS))
	var skel: Skeleton3D = z.get_node("Model/Skeleton3D")
	check(skel.get_bone_count() == 18, "18 bones (%d)" % skel.get_bone_count())
	var body := skel.get_node("Body") as MeshInstance3D
	var aabb := body.get_aabb()
	check(absf(aabb.size.y - 1.85) < 0.02, "stands 1.85 m tall at rest (%.2f)" % aabb.size.y)
	check(body.mesh.get_surface_count() == 1 and (body.mesh as ArrayMesh).surface_get_array_len(0) > 0, "one skinned surface")
	check(main.drop_kind(z) == "red", "drops a red mushroom")
	var head_hb := z.find_child("HeadHitbox", true, false) as Node3D
	check(head_hb != null and head_hb.global_position.y > 1.4, "head hitbox on the cap (%.2f m)" % (head_hb.global_position.y if head_hb else -1.0))

	print("== lanes x rooms")
	for w_id in ["A", "B"]:
		for spot in SPOTS:
			await fresh(SPOTS[spot])
			z = main.spawn_lancer(win(w_id))
			var w := win(w_id)
			var order := []
			w.board_removed.connect(func(i): order.append(i))
			var times := {}
			var hp: float = player.health
			var t := 0.0
			var still := 0.0
			var prev: Vector3 = z.global_position
			var stuck := ""
			var escaped := false
			while t < 60.0 and player.health == hp:
				await physics_frame
				t += DT
				var s := st(z)
				if not times.has(s):
					times[s] = t
				if s in ["LANE", "HUNT"]:
					still = still + DT if z.global_position.distance_to(prev) < 0.004 else 0.0
					if still > 2.0 and stuck == "":
						stuck = "%s %s" % [s, str(z.global_position.snapped(Vector3.ONE * 0.1))]
				prev = z.global_position
				if s in ["HUNT", "ATTACK"] and (absf(z.global_position.x) > 5.8 or absf(z.global_position.z) > 4.8):
					escaped = true
			var ok: bool = times.has("BREACH") and times.has("CLIMB") and times.has("HUNT") and times.has("ATTACK") and player.health < hp and stuck == "" and not escaped
			check(ok, "window %s -> %s: prying %.1fs, climbs %.1fs, lances you %.1fs (-%.0f)%s%s" % [
				w_id, spot, times.get("BREACH", -1.0), times.get("CLIMB", -1.0), t, hp - player.health,
				(" STUCK " + stuck) if stuck != "" else "", " ESCAPED" if escaped else ""])
			if w_id == "A" and spot == "shop counter":
				check(order.slice(0, 2) == [w.boards.size() - 1, w.boards.size() - 2], "pries the boards off from the top (%s)" % str(order))
				var pry_time: float = times.get("CLIMB", 0.0) - times.get("BREACH", 0.0)
				check(pry_time > 1.4 * w.boards.size() - 0.5, "slower to pry than a 0.9 s repair (%.1f s for %d boards)" % [pry_time, w.boards.size()])
				check(absf(hp - player.health - z.attack_damage) < 0.01, "a lunge hits for %.0f" % z.attack_damage)

	print("== stabbing through the boards")
	await fresh(win("A").repair_point())
	var w := win("A")
	z = main.spawn_lancer(w)
	var hp0: float = player.health
	await run_until(func(): return w.boards_left() < w.boards.size() or player.health < hp0, 25.0)
	check(player.health == hp0 and w.boards_left() < w.boards.size(), "no stab while the boards are whole")
	await run_until(func(): return z.through_window or player.health < hp0, 6.0)
	check(z.through_window, "a gap opens: it stabs through at you, inside at the repair spot")
	await run_until(func(): return player.health < hp0, 3.0)
	check(absf(hp0 - player.health - z.through_damage) < 0.01, "a stab through hits for %.0f (-%.0f)" % [z.through_damage, hp0 - player.health])
	# back off out of reach: it goes back to prying
	player.global_position = w.repair_point() + (-w.outward()) * 2.5 + Vector3(0, 0.05, 0)
	var hp1: float = player.health
	await frames(240)
	check(player.health == hp1 and st(z) == "BREACH" and not z.through_window, "step back out of reach and it goes back to prying")

	print("== repairing")
	await fresh(win("A").repair_point())
	player.get_node("Head/Camera3D").look_at(win("A").global_position)
	w = win("A")
	z = main.spawn_lancer(w)
	hp0 = player.health
	var t2 := 0.0
	while t2 < 30.0:
		await physics_frame
		t2 += DT
		if st(z) == "BREACH":
			Input.action_press("interact")
	Input.action_release("interact")
	check(st(z) == "BREACH", "holding E keeps a Lancer out (state %s, %d boards)" % [st(z), w.boards_left()])
	check(player.health == hp0, "and a prompt repair shuts each gap before its lances arrive (-%.0f in %.0f s)" % [hp0 - player.health, t2])

	print("== dodging the lunge")
	await fresh(Vector3(2.6, 0, -1.4))
	z = main.spawn_lancer(win("A"))
	z.state = 3
	z.global_position = Vector3(4.2, 0.05, -1.4)
	z.rotation.y = PI / 2.0
	hp0 = player.health
	await run_until(func(): return st(z) == "ATTACK", 5.0)
	check(st(z) == "ATTACK", "starts a lunge from %.1f m" % z.attack_range)
	await frames(12)
	player.global_position = Vector3(-0.5, 0.05, -1.4)   # back off during the wind-up
	await run_until(func(): return st(z) != "ATTACK", 3.0)
	check(player.health == hp0, "back off during the wind-up and it stabs air")

	print("== shooting and knifing")
	await fresh(Vector3(0.5, 0, -1.4))
	z = await parked(Vector3(4.0, 0.05, -1.4))
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var gun: Node = player.get_node("Head/Camera3D/TestGun")
	head_hb = z.find_child("HeadHitbox", true, false) as Node3D
	var kinds := []
	for i in 3:
		cam.look_at(head_hb.global_position, Vector3.UP)
		await physics_frame
		var r: Dictionary = gun.shoot()
		kinds.append(r.get("kind", ""))
		await frames(30)
		if i == 1:
			check(not z.is_dead(), "two pistol shots to the cap don't kill (health %.0f, %s)" % [z.health, str(kinds)])
	check(z.is_dead() and kinds == ["head", "head", "head"], "three do (%s)" % str(kinds))
	await fresh(Vector3(0.5, 0, -1.4))
	z = await parked(Vector3(4.0, 0.05, -1.4))
	cam = player.get_node("Head/Camera3D")
	gun = player.get_node("Head/Camera3D/TestGun")
	var shots := 0
	while not z.is_dead() and shots < 8:
		cam.look_at(z.global_position + Vector3(0, 0.95, 0), Vector3.UP)
		await physics_frame
		gun.shoot()
		shots += 1
		await frames(30)
	check(z.is_dead() and shots == 5, "five body shots kill (%d)" % shots)
	await frames(30)
	check(z.collision_layer == 0, "the corpse doesn't block")
	await fresh(Vector3(0.5, 0, -1.4))
	z = await parked(Vector3(4.0, 0.05, -1.4))
	z.set_physics_process(true)
	z.take_damage(34.0)
	await physics_frame
	check(st(z) != "STAGGER", "a body shot doesn't make it flinch")
	z.take_damage(34.0, true)
	await physics_frame
	check(st(z) == "STAGGER", "a headshot does")
	# knife
	await fresh(Vector3(1.6, 0, -1.4))
	player.rotation.y = -PI / 2.0
	player.switch_weapon(1)
	await frames(30)
	z = await parked(Vector3(2.7, 0.05, -1.4))
	var knife: Node = player.get_node("Head/Camera3D/Knife")
	cam = player.get_node("Head/Camera3D")
	cam.look_at(z.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	knife.request("stab")
	await frames(50)
	check(not z.is_dead() and absf(z.health - (z.max_health - 75.0)) < 0.01, "a knife stab to the body takes 75 (health %.0f)" % z.health)
	cam.look_at(z.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	knife.request("stab")
	await frames(50)
	check(z.is_dead(), "a second stab kills")

	print("== waves")
	await fresh()
	main.wave = main.lancer_from_wave
	main.set("_wave_left", 1)
	main.set("_spawned", 4)
	main.set("_spawn_t", 0.0)
	main.auto_spawn = true
	await frames(2)
	main.auto_spawn = false
	var lancers := get_root().find_children("Lancer*", "CharacterBody3D", true, false)
	check(lancers.size() == 1, "wave %d (Lancers join): every 5th spawn is a Lancer" % main.lancer_from_wave)
	await fresh()
	main.wave = main.lancer_from_wave - 1
	main.set("_wave_left", 1)
	main.set("_spawned", 4)
	main.set("_spawn_t", 0.0)
	main.auto_spawn = true
	await frames(2)
	main.auto_spawn = false
	lancers = get_root().find_children("Lancer*", "CharacterBody3D", true, false)
	check(lancers.is_empty(), "none before wave %d" % main.lancer_from_wave)

	print("== mixed crowd")
	for spot in ["office desk", "kitchen line"]:
		await fresh(SPOTS[spot])
		var crowd := []
		for i in 6:
			var ww := win("A" if i % 2 == 0 else "B")
			crowd.append(main.spawn_lancer(ww) if i < 2 else (main.spawn_scuttler(ww) if i == 2 else main.spawn_zombie(ww)))
			await frames(30)
		var reached := {}
		var stuck := {}
		var hist := {}
		var t := 0.0
		while t < 100.0 and reached.size() < crowd.size():
			await physics_frame
			t += DT
			for c in crowd:
				var s := st(c)
				if not reached.has(c) and (s == "ATTACK" or (s == "HUNT" and c.global_position.distance_to(player.global_position) < 2.0)):
					reached[c] = t
				if s in ["LANE", "HUNT"]:
					if not hist.has(c):
						hist[c] = []
					hist[c].append(c.global_position)
					if hist[c].size() > 360:
						hist[c].pop_front()
					if hist[c].size() == 360 and (hist[c][0] as Vector3).distance_to(c.global_position) < 0.4 and c.global_position.distance_to(player.global_position) > 2.5:
						stuck[c] = "%s %s %s" % [c.name, s, str(c.global_position.snapped(Vector3.ONE * 0.1))]
		var ts := reached.values().map(func(x): return "%.0f" % x)
		check(reached.size() == crowd.size() and stuck.is_empty(), "2 Lancers + 1 Scuttler + 3 Shamblers all reach you at the %s (%d of %d, at %s s)%s" % [spot, reached.size(), crowd.size(), ", ".join(ts), (" STUCK " + str(stuck.values())) if not stuck.is_empty() else ""])

	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
