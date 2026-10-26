# Shared AKS arms on every weapon (weapons/fps_arms/fps_arms.gd).
#   godot --headless --path . --fixed-fps 60 --script res://tools/fps_arms_test.gd
extends SceneTree
const Shotgun = preload("res://weapons/shotgun/shotgun_weapon.gd")
const DesertEagle = preload("res://weapons/desert_eagle/desert_eagle.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func wait(n: int) -> void:
	for i in n:
		await process_frame

# The arms solve late in each frame (process_priority 1000), after the weapon
# moved its hands; the test resumes before that, so solve here, as the frame will.
func worst_error(arms: Node) -> float:
	arms._solve()
	var worst := 0.0
	for side in ["r", "l"]:
		if side == "l" and float(arms.left_weight) < 0.999:
			continue   # one-handed rig: the left hand is easing in/out or resting off screen
		var ref: Node3D = arms.right_ref if side == "r" else arms.left_ref
		var off: Transform3D = arms.right_offset if side == "r" else arms.left_offset
		var goal: Transform3D = ref.global_transform * off
		var got: Transform3D = arms.hand_global(side)
		worst = maxf(worst, got.origin.distance_to(goal.origin))
	return worst

func run() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	await wait(3)
	var player: Node = main.get_node("Player")
	player.set_process_unhandled_input(false)
	var cam: Node3D = player.get_node("Head/Camera3D")
	var eagle: Node3D = DesertEagle.new(); eagle.name = "DesertEagle"; player.add_weapon(eagle, false)
	var pump: Node3D = Shotgun.new(); pump.name = "Shotgun"; player.add_weapon(pump, false)
	var weapons := {"pistol": cam.get_node("TestGun"), "desert_eagle": eagle, "knife": cam.get_node("Knife"),
		"dagger": cam.get_node("Dagger"), "crop_duster": cam.get_node("CropDuster"), "pump": pump}
	await wait(2)
	for name in weapons:
		var w: Node3D = weapons[name]
		var all := w.find_children("FpsArms", "", true, false)
		check(all.size() == 1, "%s: one shared arms rig" % name)
		if all.is_empty():
			continue
		var arms: Node = all[0]
		var hidden := 0
		for n in w.find_children("*", "Node3D", true, false):
			if n.has_meta("fps_arms_kept_region"):
				# the dagger: its blade is baked into the old hand mesh, so only that region stays
				hidden += 1
				var region: int = n.get_meta("fps_arms_kept_region")
				var a: Array = (n as MeshInstance3D).mesh.surface_get_arrays(0)
				var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
				var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				var only := idx.size() > 0
				for i in idx:
					if int(floor(uv2[i].x + 0.5)) != region:
						only = false
						break
				check(only, "%s: old %s keeps only its blade (%d tris)" % [name, n.name, idx.size() / 3])
			elif n.has_meta("replaced_by_fps_arms"):
				hidden += 1
				var shown: bool = n.visible and (not (n is MeshInstance3D) or (n as MeshInstance3D).mesh != null)
				check(not shown, "%s: old %s hidden" % [name, n.name])
		check(hidden >= 2, "%s: old hand meshes replaced (%d)" % [name, hidden])
		w.set_meta("purchased", true)
		player.switch_weapon(player.weapons.find(w))
		await wait(30)
		check(arms.is_visible_in_tree(), "%s: arms visible when equipped" % name)
		var worst := worst_error(arms)
		if name == "knife":
			var sk: Skeleton3D = arms.skeleton
			var fore: int = arms._arms.r.fore
			var elbow: Vector3 = cam.to_local(sk.global_transform * sk.get_bone_global_pose(fore).origin)
			var wrist: Vector3 = cam.to_local(arms.hand_global("r").origin)
			check(elbow.x > wrist.x + 0.08, "knife: forearm approaches the wrist from screen-right")
		if w.has_method("shoot"):
			w.shoot()
		elif w.has_method("fire"):
			w.fire()
		elif w.has_method("request"):
			w.request("slash")
		for i in 20:
			await wait(1)
			worst = maxf(worst, worst_error(arms))
		if "mag" in w:
			w.mag = 0 if name != "pump" else 3
		if w.has_method("reload"):
			w.reload()
		var peak_left := 0.0
		var reload_frames: int = 240 if name == "crop_duster" else (120 if name == "pump" else 40)
		for i in reload_frames:
			await wait(1)
			worst = maxf(worst, worst_error(arms))
			peak_left = maxf(peak_left, float(arms.left_weight))
		if name in ["pistol", "desert_eagle"]:
			check(peak_left > 0.99, "%s: one-handed, the left hand comes in for the reload (peak %.2f)" % [name, peak_left])
			for i in 60:
				await wait(1)
			check(float(arms.left_weight) < 0.01, "%s: left hand rests off screen after the reload" % name)
		check(worst < 0.01, "%s: hands stay on the grips through idle/fire/reload (worst %.4f m)" % [name, worst])
		check(arms.reach_error["r"] < 0.005 and arms.reach_error["l"] < 0.005, "%s: both arms reach" % name)
	# only the equipped weapon's arms show
	player.switch_weapon(player.weapons.find(weapons["pistol"]))
	await wait(30)
	var shown := 0
	for name in weapons:
		var arms_list: Array[Node] = (weapons[name] as Node).find_children("FpsArms", "", true, false)
		if not arms_list.is_empty() and (arms_list[0] as Node3D).is_visible_in_tree():
			shown += 1
	check(shown == 1, "only the equipped weapon shows arms (%d shown)" % shown)
	print("\n%d failure(s)" % failures)
	quit(1 if failures else 0)
