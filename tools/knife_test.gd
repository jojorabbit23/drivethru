# Knife checks (headless):
#   godot --headless --path . --fixed-fps 60 --script res://tools/knife_test.gd
extends SceneTree

var main: Node3D
var player: CharacterBody3D
var knife: Node
var cam: Camera3D
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

# Fresh scene: player in the kitchen facing east, knife drawn, and a frozen
# zombie at `offset` (metres: x right, z forward from the player) facing `zyaw`
# relative to "toward the player".
func setup(offset: Vector3, zyaw_deg := 0.0, ppos := Vector3(1.6, 0, -1.4)) -> Node3D:
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
	knife = player.get_node("Head/Camera3D/Knife")
	cam = player.get_node("Head/Camera3D")
	await wait(5)
	player.global_position = ppos + Vector3(0, 0.05, 0)
	player.rotation.y = -PI / 2.0   # face +X (east)
	player.get_node("Head").rotation.x = 0.0
	player.switch_weapon(1)
	await wait(30)                 # let the draw finish and physics settle
	var fwd := Vector3(1, 0, 0)
	var right := Vector3(0, 0, 1)
	var zpos := ppos + fwd * offset.z + right * offset.x
	var z: Node3D = main.spawn_zombie(main.get_node("ShopGreybox/Windows/Window_A"))
	z.state = 3
	z.global_position = zpos
	var to_player := (ppos - zpos).normalized()
	z.rotation.y = atan2(-to_player.x, -to_player.z) + deg_to_rad(zyaw_deg)
	await wait(2)
	z.set_physics_process(false)
	z.velocity = Vector3.ZERO
	await wait(3)
	return z

func ooze_sprays() -> int:
	var fx := root.get_node_or_null("OozeFX")
	return fx.stats["sprays"] if fx else 0

func _run() -> void:
	print("== switching")
	var z := await setup(Vector3(0, 0, 1.0))
	var gun: Node = player.get_node("Head/Camera3D/TestGun")
	check(knife.visible and knife.active and not gun.active, "2 draws the knife and holsters the pistol")
	player.switch_weapon(0)
	await wait(2)
	check(gun.active and not knife.active and not knife.visible, "1 goes back to the pistol")
	player.switch_weapon(1)
	await wait(2)
	knife.request("slash")
	check(not knife.is_busy() or knife._draw_t > 0.0, "can't swing mid-draw")
	await wait(30)

	print("== slash")
	var hp: float = z.health
	knife.request("slash")
	await wait(6)   # 0.1 s: before the hit frame
	check(z.health == hp, "no damage before the blade arrives (0.1 s)")
	await wait(6)   # 0.2 s: just after the 0.15 s hit frame
	check(z.health == hp - knife.slash_damage, "slash lands at the hit frame for %d (health %.0f)" % [int(knife.slash_damage), z.health])
	check(ooze_sprays() == 1, "the cut sprays ooze")
	await wait_s(0.5)
	knife.request("slash")
	await wait_s(0.38)
	knife.request("slash")  # buffered during recovery
	await wait_s(0.9)
	check(z.health == hp - knife.slash_damage * 3.0 or z.is_dead(), "a swing pressed during recovery is buffered (health %.0f)" % z.health)

	print("== arc and reach")
	z = await setup(Vector3(0.45, 0, 0.75))   # off to the right, ~31 degrees
	hp = z.health
	knife.request("stab")
	await wait_s(0.8)
	check(z.health == hp, "a stab is narrow: misses a zombie 31 deg off to the side")
	knife.request("slash")
	await wait_s(0.6)
	check(z.health < hp, "a slash's wide arc catches it")
	z = await setup(Vector3(0, 0, 2.3))
	hp = z.health
	knife.request("slash")
	await wait_s(0.6)
	knife.request("stab")
	await wait_s(0.8)
	check(z.health == hp, "out of reach at 2.3 m")

	print("== stab")
	z = await setup(Vector3(0, 0, 1.0))
	cam.look_at(z.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	knife.request("stab")
	await wait_s(0.8)
	check(z.health == 100.0 - knife.stab_damage, "body stab does %d (health %.0f)" % [int(knife.stab_damage), z.health])
	z = await setup(Vector3(0, 0, 0.95))
	var skel: Skeleton3D = z.get_node("Model/Skeleton3D")
	var head := skel.to_global(skel.get_bone_global_pose(skel.find_bone("head")).origin) + Vector3(0, 0.14, 0)
	cam.look_at(head, Vector3.UP)
	knife.request("stab")
	await wait_s(0.8)
	check(z.is_dead(), "a stab to the head kills (zombie's x%.0f headshot multiplier)" % z.head_multiplier)
	z = await setup(Vector3(0, 0, 0.95))
	skel = z.get_node("Model/Skeleton3D")
	head = skel.to_global(skel.get_bone_global_pose(skel.find_bone("head")).origin) + Vector3(0, 0.14, 0)
	cam.look_at(head, Vector3.UP)
	knife.request("slash")
	await wait_s(0.6)
	check(z.health == 100.0 - knife.slash_damage, "a slash across the head is a normal hit (health %.0f)" % z.health)

	print("== backstab")
	z = await setup(Vector3(0, 0, 1.0), 180.0)   # facing away
	cam.look_at(z.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	knife.request("stab")
	await wait_s(0.8)
	check(z.is_dead(), "stabbing a zombie from behind kills it outright")
	z = await setup(Vector3(0, 0, 1.0), 180.0)
	cam.look_at(z.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	knife.request("slash")
	await wait_s(0.6)
	check(not z.is_dead(), "a slash from behind is just a slash (no instakill)")
	z = await setup(Vector3(0, 0, 1.0), 90.0)    # side-on
	cam.look_at(z.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	knife.request("stab")
	await wait_s(0.8)
	check(not z.is_dead(), "side-on doesn't count as behind")

	print("== walls")
	# player in the kitchen against the partition, zombie in the storeroom behind it
	z = await setup(Vector3(0, 0, 0), 0.0, Vector3(1.2, 0, -0.5))
	z.global_position = Vector3(1.2, 0, 0.55)      # just the other side of the wall (door is at x 2.4..3.6)
	player.rotation.y = PI                          # face the wall (+Z)
	await wait(2)
	hp = z.health
	knife.request("slash")
	await wait_s(0.6)
	knife.request("stab")
	await wait_s(0.8)
	check(z.health == hp, "no hits through a wall")
	check(ooze_sprays() == 0, "hitting the wall makes no ooze")

	print("\n%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
