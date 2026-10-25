# Exports hand point clouds for tools/fps_arms_fit.py, which solves the FITS
# offsets in weapons/fps_arms/fps_arms.gd (how the shared AKS hand sits in
# each weapon's old hand frame).
#   godot --headless --path . --script res://tools/fps_arms_fit_export.gd -- <out_dir>
extends SceneTree
const FpsArms = preload("res://weapons/fps_arms/fps_arms.gd")
var out_dir := ""

func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	run.call_deferred()

func save(name: String, pts: PackedVector3Array) -> void:
	var f := FileAccess.open(out_dir.path_join(name + ".f32"), FileAccess.WRITE)
	for p in pts:
		f.store_float(p.x); f.store_float(p.y); f.store_float(p.z)
	f.close()
	print("saved ", name, " ", pts.size())

func subtree(sk: Skeleton3D, root: int) -> Dictionary:
	var out := {root: true}
	for b in sk.get_bone_count():
		var p := sk.get_bone_parent(b)
		while p >= 0:
			if p == root:
				out[b] = true
				break
			p = sk.get_bone_parent(p)
	return out

# Skinned vertices of `mi` (current skeleton pose) whose main bone is under
# `bone_name`, expressed in that bone's global frame.
func skinned(mi: MeshInstance3D, sk: Skeleton3D, bone_name: String, skip_native := false) -> PackedVector3Array:
	var bone := sk.find_bone(bone_name)
	var keep := subtree(sk, bone)
	var skin: Skin = mi.skin if mi.skin else mi.mesh.get("skin")
	var mats: Array[Transform3D] = []
	var bind_bone: Array[int] = []
	for i in skin.get_bind_count():
		var b := skin.get_bind_bone(i)
		if b < 0:
			b = sk.find_bone(skin.get_bind_name(i))
		bind_bone.append(b)
		mats.append(sk.get_bone_global_pose(b) * skin.get_bind_pose(i))
	var frame_inv := sk.get_bone_global_pose(bone).affine_inverse()
	var out := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bi: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var bw: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var n := bi.size() / v.size()
		var uv2 = a[Mesh.ARRAY_TEX_UV2]
		for i in v.size():
			if skip_native and uv2 != null and int(floor((uv2 as PackedVector2Array)[i].x + 0.5)) == 4:
				continue   # the dagger's blade/guard, not hand
			var best := 0
			var p := Vector3.ZERO
			for k in n:
				var w := bw[i * n + k]
				if w > bw[i * n + best]:
					best = k
				if w > 0.0:
					p += (mats[bi[i * n + k]] * v[i]) * w
			if keep.has(bind_bone[bi[i * n + best]]):
				out.append(frame_inv * p)
	return out

func rigid(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		out.append_array(mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return out

func run() -> void:
	# the shared arms at their captured grip pose (open and fist)
	for fist in [false, true]:
		var arms: Node3D = FpsArms.new()
		arms.fist = fist
		root.add_child(arms)
		await process_frame
		var sk: Skeleton3D = arms.skeleton
		for side in ["r", "l"]:
			var bone_name: String = sk.get_bone_name(arms._arms[side]["hand"])
			save("aks_%s%s" % [side, "_fist" if fist else ""], skinned(arms.mesh, sk, bone_name))
		arms.queue_free()
	# rigid old hands
	var pump: Node3D = load("res://weapons/shotgun/shotgun_model.tscn").instantiate()
	root.add_child(pump)
	save("pump_r", rigid(pump.get_node("GripSocket/RightHand")))
	save("pump_l", rigid(pump.get_node("Pump/PumpSocket/LeftHand")))
	var pistol: Node3D = load("res://weapons/pistol/pistol_viewmodel.tscn").instantiate()
	root.add_child(pistol)
	save("pistol_r", rigid(pistol.get_node("Model/GripSocket/RightHand")))
	save("pistol_l", rigid(pistol.get_node("Model/SupportSocket/LeftHand")))
	var crop: Node3D = load("res://weapons/crop_duster/crop_duster_viewmodel.tscn").instantiate()
	root.add_child(crop)
	save("crop_r", rigid(crop.find_child("fp_pump_shotgun_hand_r", true, false)))
	save("crop_l", rigid(crop.find_child("fp_pump_shotgun_hand_l", true, false)))
	# knife: PSX arms at the idle pose, hands in their bone frames
	var knife: Node3D = load("res://weapons/knife/knife_viewmodel.tscn").instantiate()
	root.add_child(knife)
	var ap: AnimationPlayer = knife.find_child("AnimationPlayer", true, false)
	ap.play("kitchen_knife_idle")
	ap.seek(0.0, true)
	ap.pause()
	await process_frame
	var ksk: Skeleton3D = knife.find_child("Skeleton3D", true, false)
	save("knife_r", skinned(knife.find_child("RightHand", true, false), ksk, "hand_r"))
	save("knife_l", skinned(knife.find_child("fp_arms_mesh", true, false), ksk, "hand_l"))
	var dagger: Node3D = load("res://weapons/knife/dagger_viewmodel.tscn").instantiate()
	root.add_child(dagger)
	var dap: AnimationPlayer = dagger.find_child("AnimationPlayer", true, false)
	dap.play("kitchen_knife_idle")
	dap.seek(0.0, true)
	dap.pause()
	await process_frame
	var dsk: Skeleton3D = dagger.find_child("Skeleton3D", true, false)
	save("dagger_r", skinned(dagger.find_child("RightHand", true, false), dsk, "hand_r", true))
	quit()
