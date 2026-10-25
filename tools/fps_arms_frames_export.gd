# Grip frames for tools/fps_arms_fit.py's semantic start (see its docstring).
#   godot --headless --path . --script res://tools/fps_arms_frames_export.gd -- <out_dir>
# Writes <out_dir>/frames.json:
#   aks / aks_fist: per side, finger landmarks in the AKS hand's metric frame
#   <weapon>: per side, the old hand reference in camera space at rest, and for
#   the knife/dagger the PSX finger landmarks in that reference's frame.
extends SceneTree
const FpsArms = preload("res://weapons/fps_arms/fps_arms.gd")
const Shotgun = preload("res://weapons/shotgun/shotgun_weapon.gd")
var out := {}

func _initialize() -> void:
	run.call_deferred()

func v(p: Vector3) -> Array:
	return [p.x, p.y, p.z]

func xf(t: Transform3D) -> Array:
	var b := t.basis.orthonormalized()
	return [v(b.x), v(b.y), v(b.z), v(t.origin)]

# finger landmarks (index/pinky knuckles, all fingertip joints, wrist) in `frame`
func landmarks(sk: Skeleton3D, frame: Transform3D, names: Dictionary) -> Dictionary:
	var inv := Transform3D(frame.basis.orthonormalized(), frame.origin).affine_inverse()
	var d := {}
	for key in names:
		var pts := []
		for prefix in names[key]:
			for b in sk.get_bone_count():
				if sk.get_bone_name(b).begins_with(prefix):
					pts.append(v(inv * (sk.global_transform * sk.get_bone_global_pose(b)).origin))
					break
		d[key] = pts
	return d

func run() -> void:
	for fist in [false, true]:
		var arms: Node3D = FpsArms.new()
		arms.fist = fist
		root.add_child(arms)
		await process_frame
		var sk: Skeleton3D = arms.skeleton
		var entry := {}
		for side in ["r", "l"]:
			var hand: Transform3D = sk.global_transform * sk.get_bone_global_pose(arms._arms[side]["hand"])
			# AKS: palm_2/finger_2x = index ... palm_5/finger_5x = pinky; *_x3 = last joint
			entry[side] = landmarks(sk, hand, {
				"index": ["finger_21_%s_" % side], "pinky": ["finger_51_%s_" % side],
				"tips": ["finger_23_%s_" % side, "finger_33_%s_" % side, "finger_43_%s_" % side, "finger_53_%s_" % side],
				"wrist": ["hand_%s_0" % side]})
		out["aks_fist" if fist else "aks"] = entry
		arms.queue_free()
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	await process_frame
	var player: Node = main.get_node("Player")
	player.set_process_unhandled_input(false)
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var pump: Node3D = Shotgun.new(); pump.name = "Shotgun"; player.add_weapon(pump, false)
	var weapons := {"knife": cam.get_node("Knife"), "dagger": cam.get_node("Dagger"), "crop_duster": cam.get_node("CropDuster"), "pump": pump}
	for name in weapons:
		var w: Node3D = weapons[name]
		w.set_meta("purchased", true)
		player.switch_weapon(player.weapons.find(w))
		for i in 45:
			await process_frame
		var arms: Node = w.find_child("FpsArms", true, false)
		var entry := {}
		for side in ["r", "l"]:
			var ref: Node3D = arms.right_ref if side == "r" else arms.left_ref
			var e := {"ref_in_camera": xf(cam.global_transform.affine_inverse() * ref.global_transform)}
			if name in ["knife", "dagger"]:
				var sk: Skeleton3D = w.find_child("Skeleton3D", true, false)
				e.merge(landmarks(sk, ref.global_transform, {
					"index": ["index_01_%s" % side], "pinky": ["pinky_01_%s" % side],
					"tips": ["index_03_%s" % side, "middle_03_%s" % side, "ring_03_%s" % side, "pinky_03_%s" % side],
					"wrist": ["hand_%s" % side]}))
			entry[side] = e
		out[name] = entry
	var f := FileAccess.open(OS.get_cmdline_user_args()[0].path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("saved frames ", out.keys())
	quit()
