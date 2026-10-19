# Turns the static morel-headed creature GLB into the rigged, animated Lancer.
#
#   godot --headless --path . --script res://tools/build_lancer.gd
#   godot --headless --path . --import          # first run only (new albedo PNG)
#   godot --headless --path . --script res://tools/build_lancer.gd
#
# The source is a T-pose: arms straight out along X, forearms ending in long
# bone lances, morel cap for a head, bird-clawed feet.
# Steps
#   1. scale to HEIGHT metres, turn to face -Z (Godot forward), feet at y = 0
#   2. skeleton: 18 bones placed from measured landmarks of this model
#   3. skin weights straight from position (the T-pose keeps the parts apart):
#      arms by distance out from the shoulder, legs by side and height, the
#      torso by smooth height ramps; every joint blends over a short band.
#      No vertex is moved or dropped, so the mesh stays watertight
#   4. auto LODs for crowds, 1024 px albedo with nearest filtering
#   5. keyframed clips authored here (editable in Godot's animation editor)
# Output: res://enemies/lancer/lancer_model.tscn (+ albedo, material, anims)
extends SceneTree

const SRC := "res://enemies/lancer/source/stylized_creature.glb"
const OUT_DIR := "res://enemies/lancer/"
const OUT_SCENE := OUT_DIR + "lancer_model.tscn"
const ALBEDO := OUT_DIR + "lancer_albedo.png"
const HEIGHT := 1.85
const TEX_SIZE := 1024

# Bones in SOURCE space (model faces +Z, its right side is -X).
# [name, parent, head (joint), tail]
const BONES := [
	["root", "", Vector3(0, 0, 0), Vector3(0, 0.02, 0)],
	["hips", "root", Vector3(0, 0.34, -0.005), Vector3(0, 0.40, -0.005)],
	["spine", "hips", Vector3(0, 0.40, -0.005), Vector3(0, 0.46, -0.01)],
	["chest", "spine", Vector3(0, 0.46, -0.01), Vector3(0, 0.545, -0.005)],
	["neck", "chest", Vector3(0, 0.545, -0.005), Vector3(0, 0.572, 0)],
	["head", "neck", Vector3(0, 0.572, 0), Vector3(0, 0.73, 0)],
	["arm_r", "chest", Vector3(-0.075, 0.505, -0.012), Vector3(-0.172, 0.51, -0.012)],
	["forearm_r", "arm_r", Vector3(-0.172, 0.51, -0.012), Vector3(-0.258, 0.512, -0.012)],
	["lance_r", "forearm_r", Vector3(-0.258, 0.512, -0.012), Vector3(-0.49, 0.512, -0.014)],
	["arm_l", "chest", Vector3(0.075, 0.505, -0.012), Vector3(0.172, 0.51, -0.012)],
	["forearm_l", "arm_l", Vector3(0.172, 0.51, -0.012), Vector3(0.258, 0.512, -0.012)],
	["lance_l", "forearm_l", Vector3(0.258, 0.512, -0.012), Vector3(0.49, 0.512, -0.014)],
	["thigh_r", "hips", Vector3(-0.042, 0.33, 0.0), Vector3(-0.052, 0.205, 0.005)],
	["shin_r", "thigh_r", Vector3(-0.052, 0.205, 0.005), Vector3(-0.068, 0.075, -0.02)],
	["foot_r", "shin_r", Vector3(-0.068, 0.075, -0.02), Vector3(-0.09, 0.0, 0.06)],
	["thigh_l", "hips", Vector3(0.042, 0.33, 0.0), Vector3(0.052, 0.205, 0.005)],
	["shin_l", "thigh_l", Vector3(0.052, 0.205, 0.005), Vector3(0.068, 0.075, -0.02)],
	["foot_l", "shin_l", Vector3(0.068, 0.075, -0.02), Vector3(0.09, 0.0, 0.06)],
]
# Source-space bands where neighbouring bones share weight.
const SHOULDER := [0.064, 0.104]    # |x|: chest -> upper arm
const ARM_TOP := 0.556              # y: above this it's the cap / collar, never arm
const ARM_BOTTOM := 0.455           # y: below this it's the shirt and legs, never arm
const ELBOW := [0.158, 0.186]       # |x|: upper arm -> forearm
const WRIST := [0.249, 0.263]       # |x|: forearm -> lance (the lance stays rigid)
const HIP := [0.295, 0.37]          # y: hips -> thighs
const MID := 0.014                  # |x| under this: the crotch, shared by both legs
const KNEE := [0.18, 0.235]         # y: thigh -> shin
const ANKLE := [0.058, 0.092]       # y: shin -> foot
# torso joints: [height, half-width of the blend]
const TORSO := {"spine": [0.40, 0.03], "chest": [0.46, 0.03], "neck": [0.545, 0.014], "head": [0.566, 0.01]}

var scale_f := 1.0
var bone_index := {}

func bone_of(name: String) -> int:
	return bone_index[name]

func to_final(p: Vector3) -> Vector3:
	# turn 180 degrees so the model faces -Z, then scale
	return Vector3(-p.x, p.y, -p.z) * scale_f

func _initialize() -> void:
	for i in BONES.size():
		bone_index[BONES[i][0]] = i
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(SRC), st)
	assert(err == OK, "cannot read " + SRC)
	var gm: GLTFMesh = st.get_meshes()[0]
	var arr := gm.mesh.get_surface_arrays(0)
	var src_v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var top := 0.0
	for p in src_v:
		top = maxf(top, p.y)
	scale_f = HEIGHT / top
	print("source height %.3f -> scale %.3f" % [top, scale_f])

	# albedo: 4096 -> 1024, nearest-sampled in game like the other zombies
	if not FileAccess.file_exists(ALBEDO):
		var img: Image = st.get_images()[0].get_image()
		img.decompress()
		img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(ALBEDO))
		print("wrote ", ALBEDO, " — run --import, then run this script again")
		quit()
		return

	var v := PackedVector3Array()
	var n := PackedVector3Array()
	v.resize(src_v.size())
	n.resize(src_v.size())
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	var counts := {}
	for i in src_v.size():
		v[i] = to_final(src_v[i])
		n[i] = Vector3(-src_n[i].x, src_n[i].y, -src_n[i].z)
		var acc := weights_at(src_v[i])
		var pairs := []
		for b in acc:
			if acc[b] > 0.002:
				pairs.append([b, acc[b]])
		pairs.sort_custom(func(p, q): return p[1] > q[1])
		pairs = pairs.slice(0, 4)
		var s := 0.0
		for p in pairs:
			s += p[1]
		for k in 4:
			bones.append(pairs[k][0] if k < pairs.size() else 0)
			wts.append(pairs[k][1] / s if k < pairs.size() else 0.0)
		var main_b: String = BONES[pairs[0][0]][0]
		counts[main_b] = counts.get(main_b, 0) + 1
	print("vertices per bone: ", counts)

	# skeleton (rest rotations are identity, so animation axes are model axes:
	# +X = the Lancer's right, -Z = forward, +Y = up; arms rest straight out)
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	for b in BONES:
		var i := skel.get_bone_count()
		skel.add_bone(b[0])
		var parent_final := Vector3.ZERO
		if b[1] != "":
			skel.set_bone_parent(i, bone_index[b[1]])
			parent_final = to_final(BONES[bone_index[b[1]]][2])
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, to_final(b[2]) - parent_final))
	skel.reset_bone_poses()

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(ALBEDO)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.9
	mat.metallic_specular = 0.2
	# double-sided: the ragged shirt hem and sleeve tufts are single sheets
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ResourceSaver.save(mat, OUT_DIR + "lancer_material.tres")
	mat.take_over_path(OUT_DIR + "lancer_material.tres")

	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = v
	surface[Mesh.ARRAY_NORMAL] = n
	surface[Mesh.ARRAY_TEX_UV] = uv
	surface[Mesh.ARRAY_INDEX] = idx
	surface[Mesh.ARRAY_BONES] = bones
	surface[Mesh.ARRAY_WEIGHTS] = wts
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, surface, [], {}, mat, "body")
	var bone_xf := []
	for i in skel.get_bone_count():
		bone_xf.append(skel.get_bone_global_rest(i))
	im.generate_lods(25.0, 60.0, bone_xf)
	var mesh := im.get_mesh()
	for l in im.get_surface_lod_count(0):
		print("   lod %d: %d tris" % [l, im.get_surface_lod_indices(0, l).size() / 3])

	var root := Node3D.new()
	root.name = "LancerModel"
	root.add_child(skel)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = mesh
	skel.add_child(mi)
	mi.skin = skel.create_skin_from_rest_transforms()
	mi.skeleton = NodePath("..")
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var lib := AnimationLibrary.new()
	for clip in make_clips():
		lib.add_animation(clip[0], clip[1])
	ResourceSaver.save(lib, OUT_DIR + "lancer_anims.tres")
	lib.take_over_path(OUT_DIR + "lancer_anims.tres")
	ap.add_animation_library("", lib)
	ap.playback_default_blend_time = 0.2
	ap.autoplay = "idle"
	for c in root.get_children():
		own(c, root)
	var ps := PackedScene.new()
	ps.pack(root)
	err = ResourceSaver.save(ps, OUT_SCENE)
	print("saved ", OUT_SCENE, " err=", err, "  tris ", idx.size() / 3, "  bones ", skel.get_bone_count())
	root.free()
	quit()

func own(nd: Node, owner: Node) -> void:
	nd.owner = owner
	for c in nd.get_children():
		own(c, owner)

# ------------------------------------------------------------ weights ----
func ramp(band: Array, x: float) -> float:
	return smoothstep(band[0], band[1], x)

func weights_at(p: Vector3) -> Dictionary:
	var acc := {}
	var side := "r" if p.x < 0.0 else "l"
	var ax := absf(p.x)
	# torso chain by height
	var chain := ["hips", "spine", "chest", "neck", "head"]
	var ts := [1.0]
	for k in range(1, chain.size()):
		var j: Array = TORSO[chain[k]]
		ts.append(smoothstep(j[0] - j[1], j[0] + j[1], p.y))
	ts.append(0.0)
	var body := {}
	for k in chain.size():
		var wk: float = ts[k] * (1.0 - ts[k + 1])
		if wk > 0.0:
			body[chain[k]] = wk
	# legs: below the hips, split by side (the crotch shared)
	var leg := 1.0 - ramp(HIP, p.y)
	if leg > 0.0:
		var to_l := smoothstep(-MID, MID, p.x)
		var knee := ramp(KNEE, p.y)       # 1 = thigh
		var ankle := ramp(ANKLE, p.y)     # 1 = shin
		var chainw := {"thigh": knee, "shin": (1.0 - knee) * ankle, "foot": (1.0 - knee) * (1.0 - ankle)}
		for b in body:
			body[b] *= (1.0 - leg)
		for part in chainw:
			for s in ["l", "r"]:
				var ws: float = leg * chainw[part] * (to_l if s == "l" else 1.0 - to_l)
				if ws > 0.0:
					body[part + "_" + s] = body.get(part + "_" + s, 0.0) + ws
	# arms: straight out along X, below the cap
	var arm := 0.0
	if p.y < ARM_TOP:
		arm = ramp(SHOULDER, ax) * (1.0 - smoothstep(ARM_TOP - 0.012, ARM_TOP, p.y)) * smoothstep(ARM_BOTTOM - 0.02, ARM_BOTTOM, p.y)
	if arm > 0.0:
		var elbow := ramp(ELBOW, ax)
		var wrist := ramp(WRIST, ax)
		for b in body:
			body[b] *= (1.0 - arm)
		body["arm_" + side] = arm * (1.0 - elbow)
		body["forearm_" + side] = arm * elbow * (1.0 - wrist)
		body["lance_" + side] = arm * wrist
	for b in body:
		if body[b] > 0.0:
			acc[bone_of(b)] = body[b]
	return acc

# --------------------------------------------------------- animations ----
# Rotations are Euler degrees (YXZ) on model axes. Rest rotations are identity:
#   torso pointing up: -X leans forward, +Y turns to its left
#   legs hanging down: +X swings them forward; shin -X bends the knee
#   arms rest straight out sideways:
#     arm_r: -Z lowers it to the side, then +X swings it forward, +Y aims it forward
#     arm_l: +Z lowers it, +X swings forward, -Y aims forward  (mirror: y, z negated)
#     forearm/lance: +Y (right) / -Y (left) bends the elbow/wrist forward
# Write the right side and mirror it with L() for the left.
func rest_pos(bone: String) -> Vector3:
	var b: Array = BONES[bone_index[bone]]
	var parent_head: Vector3 = Vector3.ZERO if b[1] == "" else BONES[bone_index[b[1]]][2]
	return to_final(b[2]) - to_final(parent_head)

func add_rot(anim: Animation, bone: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t, "Skeleton3D:" + bone)
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		var e: Vector3 = k[1]
		anim.rotation_track_insert_key(t, k[0], Basis.from_euler(e * (PI / 180.0)).get_rotation_quaternion())

func add_pos(anim: Animation, bone: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(t, "Skeleton3D:" + bone)
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		anim.position_track_insert_key(t, k[0], rest_pos(bone) + (k[1] as Vector3))

static func L(e: Vector3) -> Vector3:
	return Vector3(e.x, -e.y, -e.z)

# Looping clip sampled from functions of phase (0..TAU).
func cyclic(length: float, samples: int, rot_fns: Dictionary, pos_fns: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	for bone in rot_fns:
		var keys := []
		for s in samples + 1:
			keys.append([length * s / samples, rot_fns[bone].call(TAU * s / samples)])
		add_rot(a, bone, keys)
	for bone in pos_fns:
		var keys := []
		for s in samples + 1:
			keys.append([length * s / samples, pos_fns[bone].call(TAU * s / samples)])
		add_pos(a, bone, keys)
	return a

# Clip from pose keyframes. poses: [[t, {bone: euler}], ...]; a bone missing
# from a pose holds the base pose. hips_y: [[t, metres]] (+ optional z).
func keyed(length: float, base: Dictionary, poses: Array, hips: Array, loop := false) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var bones := {}
	for b in base:
		bones[b] = true
	for p in poses:
		for b in p[1]:
			bones[b] = true
	for b in bones:
		var keys := []
		for p in poses:
			keys.append([p[0], p[1].get(b, base.get(b, Vector3.ZERO))])
		add_rot(a, b, keys)
	if not hips.is_empty():
		add_pos(a, "hips", hips)
	return a

# The neutral stance every clip starts from: hunched, knees bent, lances
# hanging forward and low, points just off the floor.
func stance() -> Dictionary:
	var r := {
		"spine": Vector3(-10, 0, 0), "chest": Vector3(-8, 0, 0), "neck": Vector3(6, 0, 0), "head": Vector3(8, 0, 0),
		"arm_r": Vector3(22, 6, -72), "forearm_r": Vector3(0, 28, 0), "lance_r": Vector3(0, 8, 0),
		"thigh_r": Vector3(14, 0, 2), "shin_r": Vector3(-24, 0, 0), "foot_r": Vector3(10, 0, 0),
	}
	r["arm_l"] = L(r["arm_r"])
	r["forearm_l"] = L(r["forearm_r"])
	r["lance_l"] = L(r["lance_r"])
	r["thigh_l"] = L(r["thigh_r"])
	r["shin_l"] = r["shin_r"]
	r["foot_l"] = r["foot_r"]
	return r

func with(base: Dictionary, over: Dictionary, mirror_arms := true) -> Dictionary:
	var r := base.duplicate()
	for b in over:
		r[b] = over[b]
		if mirror_arms and (b as String).ends_with("_r") and not over.has((b as String).trim_suffix("_r") + "_l"):
			r[(b as String).trim_suffix("_r") + "_l"] = L(over[b])
	return r

const CROUCH := -0.06     # metres the hips sit lower in the stance (bent knees)

func make_clips() -> Array:
	var V := func(x: float, y := 0.0, z := 0.0) -> Vector3: return Vector3(x, y, z)
	var S := stance()
	var clips := []

	# IDLE: breathing, cap twitching, lances scraping and flexing.
	clips.append(["idle", cyclic(2.4, 12, {
		"spine": func(p): return V.call(-10 + 2 * sin(p), 0, 1.5 * sin(p + 0.7)),
		"chest": func(p): return V.call(-8 + 3 * sin(p + 0.5), 5 * sin(p), 0),
		"neck": func(p): return V.call(6 + 3 * sin(p + 1.0), 10 * sin(p * 0.5 + 0.3), 4 * sin(p)),
		"head": func(p): return V.call(8 + 4 * sin(p + 1.3), 14 * sin(p * 0.5 + 0.6) + 8 * pow(sin(p * 2.0), 9), 6 * sin(p + 0.2)),
		"arm_r": func(p): return V.call(22 + 4 * sin(p + 0.4), 6, -72 + 3 * sin(p)),
		"forearm_r": func(p): return V.call(0, 28 + 6 * sin(p + 1.1), 0),
		"lance_r": func(p): return V.call(10 * sin(p * 2.0), 8 + 5 * sin(p + 2.0), 0),
		"arm_l": func(p): return L(V.call(22 + 4 * sin(p + 2.0), 6, -72 + 3 * sin(p + 1.6))),
		"forearm_l": func(p): return L(V.call(0, 28 + 6 * sin(p + 2.7), 0)),
		"lance_l": func(p): return L(V.call(-10 * sin(p * 2.0 + 1.0), 8 + 5 * sin(p + 3.6), 0)),
		"thigh_r": func(p): return S["thigh_r"],
		"shin_r": func(p): return S["shin_r"],
		"foot_r": func(p): return S["foot_r"],
		"thigh_l": func(p): return S["thigh_l"],
		"shin_l": func(p): return S["shin_l"],
		"foot_l": func(p): return S["foot_l"],
	}, {"hips": func(p): return V.call(0, CROUCH + 0.008 * sin(p), 0)})])

	# STALK: long predatory strides, body low and level, lances swinging
	# opposite the legs. One cycle = two steps, 1.1 s (~1.3 m/s, lancer.gd).
	clips.append(["stalk", cyclic(1.1, 16, {
		"spine": func(p): return V.call(-16, 6 * sin(p), 0),
		"chest": func(p): return V.call(-10 + 2 * sin(p * 2.0), -10 * sin(p), -3 * sin(p)),
		"neck": func(p): return V.call(10 + 2 * sin(p * 2.0 + 1.0), 5 * sin(p), 3 * sin(p + 0.5)),
		"head": func(p): return V.call(10 + 3 * sin(p * 2.0 + 1.4), 4 * sin(p), 4 * sin(p + 0.5)),
		"arm_r": func(p): return V.call(24 - 22 * sin(p), 8, -70),
		"forearm_r": func(p): return V.call(0, 30 + 10 * maxf(0.0, -sin(p)), 0),
		"lance_r": func(p): return V.call(0, 10 + 6 * sin(p + 0.8), 0),
		"arm_l": func(p): return L(V.call(24 + 22 * sin(p), 8, -70)),
		"forearm_l": func(p): return L(V.call(0, 30 + 10 * maxf(0.0, sin(p)), 0)),
		"lance_l": func(p): return L(V.call(0, 10 + 6 * sin(p + 0.8 + PI), 0)),
		"thigh_r": func(p): return V.call(14 + 28 * sin(p), 0, 2),
		"shin_r": func(p): return V.call(-(16 + 44 * maxf(0.0, sin(p + 1.6))), 0, 0),
		"foot_r": func(p): return V.call(10 + 14 * sin(p + 0.5), 0, 0),
		"thigh_l": func(p): return V.call(14 - 28 * sin(p), 0, -2),
		"shin_l": func(p): return V.call(-(16 + 44 * maxf(0.0, sin(p + 1.6 + PI))), 0, 0),
		"foot_l": func(p): return V.call(10 - 14 * sin(p + 0.5), 0, 0),
	}, {"hips": func(p): return V.call(0.012 * sin(p), CROUCH - 0.03 + 0.03 * absf(sin(p)), 0)})])

	# PRY: drives both lances between the boards, then levers back and up.
	# The board comes off at 0.95 s (PRY_MOMENT in lancer.gd).
	var stab := with(S, {"spine": V.call(-22), "chest": V.call(-14), "arm_r": V.call(0, 64, 26), "forearm_r": V.call(0, 10, 0), "lance_r": V.call(0, 4, 0),
		"thigh_r": V.call(28, 0, 2), "shin_r": V.call(-34), "thigh_l": V.call(-4, 0, -2), "shin_l": V.call(-20)}, true)
	stab["thigh_l"] = V.call(-4, 0, -2)
	var lever := with(S, {"spine": V.call(4), "chest": V.call(8, 0, 0), "neck": V.call(-4), "head": V.call(-6), "arm_r": V.call(0, 70, 26),
		"forearm_r": V.call(0, 6, 0), "lance_r": V.call(0, -14, 0), "thigh_r": V.call(10, 0, 2), "shin_r": V.call(-30), "thigh_l": V.call(-12, 0, -2), "shin_l": V.call(-14)}, true)
	lever["thigh_l"] = V.call(-12, 0, -2)
	var draw := with(S, {"spine": V.call(-8), "chest": V.call(-4, 0, 0), "arm_r": V.call(0, 18, -24), "forearm_r": V.call(0, 70, 0), "lance_r": V.call(0, 20, 0)}, true)
	clips.append(["pry", keyed(1.4, S, [
		[0.0, draw], [0.32, stab], [0.5, stab], [0.95, lever], [1.15, lever], [1.4, draw]],
		[[0.0, V.call(0, CROUCH, 0)], [0.32, V.call(0, CROUCH - 0.05, -0.08)], [0.95, V.call(0, CROUCH + 0.02, 0.06)], [1.4, V.call(0, CROUCH, 0)]], true)])

	# LUNGE: rears back with both lances cocked, then lunges and drives them
	# forward together. Hit lands at 0.58 s (LUNGE_HIT in lancer.gd).
	var cock := with(S, {"spine": V.call(6), "chest": V.call(10, 0, 0), "neck": V.call(-6), "head": V.call(-10),
		"arm_r": V.call(0, -28, 28), "forearm_r": V.call(0, 96, 0), "lance_r": V.call(0, 30, 0),
		"thigh_r": V.call(-6, 0, 2), "shin_r": V.call(-40), "thigh_l": V.call(30, 0, -2), "shin_l": V.call(-48)}, true)
	cock["thigh_l"] = V.call(30, 0, -2)
	cock["shin_l"] = V.call(-48)
	var thrust := with(S, {"spine": V.call(-26), "chest": V.call(-18, 0, 0), "neck": V.call(12), "head": V.call(14),
		"arm_r": V.call(0, 82, 40), "forearm_r": V.call(0, 4, 0), "lance_r": V.call(0, 0, 0),
		"thigh_r": V.call(-24, 0, 2), "shin_r": V.call(-10), "thigh_l": V.call(52, 0, -2), "shin_l": V.call(-56)}, true)
	thrust["thigh_l"] = V.call(52, 0, -2)
	thrust["shin_l"] = V.call(-56)
	clips.append(["lunge", keyed(1.3, S, [
		[0.0, S], [0.42, cock], [0.58, thrust], [0.78, thrust], [1.3, S]],
		[[0.0, V.call(0, CROUCH, 0)], [0.42, V.call(0, CROUCH - 0.08, 0.12)], [0.58, V.call(0, CROUCH - 0.12, -0.34)],
		 [0.78, V.call(0, CROUCH - 0.12, -0.34)], [1.3, V.call(0, CROUCH, 0)]])])

	# CLIMB: lances hooked over the sill, hauls itself through (moved by code).
	var hook := with(S, {"spine": V.call(-40), "chest": V.call(-30), "neck": V.call(18), "head": V.call(16),
		"arm_r": V.call(70, 30, -40), "forearm_r": V.call(0, 60, 0), "lance_r": V.call(0, 30, 0)}, true)
	var haul_a := with(hook, {"thigh_r": V.call(78, 0, 4), "shin_r": V.call(-92), "thigh_l": V.call(30, 0, -4), "shin_l": V.call(-60)}, false)
	var haul_b := with(hook, {"thigh_r": V.call(36, 0, 4), "shin_r": V.call(-56), "thigh_l": V.call(74, 0, -4), "shin_l": V.call(-90),
		"arm_r": V.call(30, 20, -60), "arm_l": L(V.call(30, 20, -60))}, false)
	clips.append(["climb", keyed(1.6, S, [
		[0.0, S], [0.3, haul_a], [0.75, haul_b], [1.2, haul_a], [1.6, S]],
		[[0.0, V.call(0, CROUCH, 0)], [0.3, V.call(0, -0.16, 0.02)], [1.2, V.call(0, -0.16, 0.02)], [1.6, V.call(0, CROUCH, 0)]])])

	# FLINCH: snaps upright and back, lances flung wide.
	var hit := with(S, {"spine": V.call(10), "chest": V.call(16, 10, 6), "neck": V.call(-12, 0, -6), "head": V.call(-14, 0, -8),
		"arm_r": V.call(-6, -10, -40), "forearm_r": V.call(0, 10, 0)}, true)
	clips.append(["flinch", keyed(0.45, S, [[0.0, S], [0.09, hit], [0.45, S]],
		[[0.0, V.call(0, CROUCH, 0)], [0.09, V.call(0, CROUCH + 0.02, 0.08)], [0.45, V.call(0, CROUCH, 0)]])])

	# DEATH: lances drop, knees go, pitches forward onto its cap.
	var buckle := with(S, {"spine": V.call(-26), "chest": V.call(-16, 12, 0), "neck": V.call(14), "head": V.call(16, 0, 8),
		"arm_r": V.call(-10, 0, -82), "forearm_r": V.call(0, 6, 0), "lance_r": V.call(0, 0, 0),
		"thigh_r": V.call(60, 0, 4), "shin_r": V.call(-96), "thigh_l": V.call(50, 0, -4), "shin_l": V.call(-88)}, true)
	buckle["thigh_l"] = V.call(50, 0, -4)
	buckle["shin_l"] = V.call(-88)
	var down := with(S, {"root": V.call(-80), "spine": V.call(6), "chest": V.call(4, 6, 0), "neck": V.call(-10, 0, 14), "head": V.call(-12, 0, 22),
		"arm_r": V.call(150, 0, -70), "forearm_r": V.call(0, 4, 0), "lance_r": V.call(0, 0, 0),
		"thigh_r": V.call(20, 0, 4), "shin_r": V.call(-30), "thigh_l": V.call(12, 0, -4), "shin_l": V.call(-22)}, true)
	down["thigh_l"] = V.call(12, 0, -4)
	down["shin_l"] = V.call(-22)
	var root0 := with(S, {"root": V.call(0)}, false)
	buckle["root"] = V.call(0)
	var death := keyed(1.8, root0, [[0.0, root0], [0.4, buckle], [1.15, down], [1.8, with(down, {"root": V.call(-84), "head": V.call(-14, 0, 26)}, false)]],
		[[0.0, V.call(0, CROUCH, 0)], [0.4, V.call(0, -0.3, 0.04)], [1.15, V.call(0, -0.12, 0)], [1.8, V.call(0, -0.12, 0)]])
	add_pos(death, "root", [[0.0, V.call(0)], [0.4, V.call(0)], [1.15, V.call(0, 0.12, 0)], [1.8, V.call(0, 0.12, 0)]])
	clips.append(["death", death])
	return clips
