# Turns the static voxel-zombie GLB into a rigged, animated Shambler model.
#
#   godot --headless --path . --script res://tools/build_zombie.gd
#   godot --headless --path . --import          # first run only (new albedo PNG)
#   godot --headless --path . --script res://tools/build_zombie.gd
#
# Steps
#   1. scale to HEIGHT metres, turn to face -Z (Godot forward), feet at y = 0
#   2. skeleton: 20 bones placed from measured landmarks of this model
#   3. skin weights: each bone owns a capsule sized to its limb (fat for the
#      club, slim for the normal arm); the cap is its own region above the gap
#      over the shoulders; the spine and neck blend smoothly by height; limb
#      joints blend half-and-half. Every triangle is kept: the mesh stays
#      watertight (checked), so there's nothing to see through
#   4. auto LODs for crowds, 1024 px albedo with nearest filtering
#   5. keyframed clips authored here (editable in Godot's animation editor)
# Output: res://enemies/shambler/shambler_model.tscn (+ albedo PNG)
extends SceneTree

const SRC := "res://enemies/shambler/source/voxel_zombie.glb"
const OUT_DIR := "res://enemies/shambler/"
const OUT_SCENE := OUT_DIR + "shambler_model.tscn"
const ALBEDO := OUT_DIR + "shambler_albedo.png"
const HEIGHT := 1.8
const TEX_SIZE := 1024

# Bones in SOURCE space (model faces +Z, its right side is -X). head = joint,
# tail = end of the bone's segment, used to seed the skin weights.
const BONES := [
	["root", "", Vector3(0, 0, 0), Vector3(0, 0.02, 0)],
	["hips", "root", Vector3(0, 0.40, 0), Vector3(0, 0.47, 0)],
	["spine", "hips", Vector3(0, 0.47, 0), Vector3(0, 0.56, 0)],
	["chest", "spine", Vector3(0, 0.56, 0), Vector3(0, 0.68, 0)],
	["neck", "chest", Vector3(0, 0.69, 0), Vector3(0, 0.74, 0)],
	["head", "neck", Vector3(0, 0.74, 0), Vector3(0, 0.90, 0)],
	["arm_r", "chest", Vector3(-0.11, 0.67, 0), Vector3(-0.21, 0.53, 0)],
	["forearm_r", "arm_r", Vector3(-0.21, 0.53, 0), Vector3(-0.24, 0.40, 0)],
	["club_r", "forearm_r", Vector3(-0.24, 0.40, 0), Vector3(-0.25, 0.24, 0)],
	["arm_l", "chest", Vector3(0.11, 0.67, 0), Vector3(0.23, 0.53, 0)],
	["forearm_l", "arm_l", Vector3(0.23, 0.53, 0), Vector3(0.27, 0.42, 0)],
	["hand_l", "forearm_l", Vector3(0.27, 0.42, 0), Vector3(0.27, 0.33, 0)],
	["thigh_r", "hips", Vector3(-0.11, 0.38, 0), Vector3(-0.13, 0.22, 0)],
	["shin_r", "thigh_r", Vector3(-0.13, 0.21, 0), Vector3(-0.14, 0.07, 0)],
	["foot_r", "shin_r", Vector3(-0.14, 0.06, 0.0), Vector3(-0.14, 0.02, 0.10)],
	["thigh_l", "hips", Vector3(0.11, 0.38, 0), Vector3(0.14, 0.22, 0)],
	["shin_l", "thigh_l", Vector3(0.14, 0.21, 0), Vector3(0.15, 0.07, 0)],
	["foot_l", "shin_l", Vector3(0.15, 0.06, 0.0), Vector3(0.15, 0.02, 0.10)],
]
const CAP_LINE := 0.78     # source-space: the cap brim starts above the 2 cm gap over the shoulders
const NECK_CORE_R := 0.14  # inside this radius of the neck axis: neck/face, split by height
const NECK_AXIS := Vector2(0.0, 0.0)  # (x, z)
# torso joints: [height, half-width of the blend]
const TORSO_JOINTS := {"spine": [0.47, 0.035], "chest": [0.56, 0.04], "neck": [0.685, 0.025], "head": [0.745, 0.025]}
# limb joints: blend distance either side
const BLEND_R := {
	"arm_r": 0.045, "forearm_r": 0.04, "club_r": 0.04,
	"arm_l": 0.055, "forearm_l": 0.035, "hand_l": 0.025,
	"thigh_r": 0.06, "shin_r": 0.05, "foot_r": 0.03,
	"thigh_l": 0.06, "shin_l": 0.05, "foot_l": 0.03,
}

func open_edges(v: PackedVector3Array, idx: PackedInt32Array) -> int:
	var key := {}
	var weld := PackedInt32Array()
	weld.resize(v.size())
	for i in v.size():
		var k := Vector3i(roundi(v[i].x * 1e4), roundi(v[i].y * 1e4), roundi(v[i].z * 1e4))
		if not key.has(k):
			key[k] = key.size()
		weld[i] = key[k]
	var edges := {}
	for t in range(0, idx.size(), 3):
		for e in [[0, 1], [1, 2], [2, 0]]:
			var a := weld[idx[t + e[0]]]
			var b := weld[idx[t + e[1]]]
			var k2 := Vector2i(mini(a, b), maxi(a, b))
			edges[k2] = edges.get(k2, 0) + 1
	var n := 0
	for k in edges:
		if edges[k] == 1:
			n += 1
	return n
const RADII := {
	"hips": 0.11, "spine": 0.11, "chest": 0.12, "neck": 0.06, "head": 0.10,
	"arm_r": 0.09, "forearm_r": 0.10, "club_r": 0.10,
	"arm_l": 0.05, "forearm_l": 0.045, "hand_l": 0.05,
	"thigh_r": 0.07, "shin_r": 0.06, "foot_r": 0.06,
	"thigh_l": 0.07, "shin_l": 0.07, "foot_l": 0.08,
}

func bone_of(name: String) -> int:
	for i in BONES.size():
		if BONES[i][0] == name:
			return i
	return -1

var scale_f := 1.0
var bone_index := {}

func to_final(p: Vector3) -> Vector3:
	# turn 180 degrees so the model faces -Z, then scale
	return Vector3(-p.x, p.y, -p.z) * scale_f

func _initialize() -> void:
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

	# albedo: 4096 -> 1024, nearest-sampled in game
	if not FileAccess.file_exists(ALBEDO):
		var img: Image = st.get_images()[0].get_image()
		img.decompress()
		img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(ALBEDO))
		print("wrote ", ALBEDO, " — run --import, then run this script again")
		quit()
		return

	var weights := skin_weights(src_v, idx)
	var labels: Array = weights[0]
	var bw: Array = weights[1]
	assert(open_edges(src_v, idx) == 0, "skinned mesh must stay watertight")

	# final vertex data
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	v.resize(src_v.size())
	n.resize(src_v.size())
	for i in src_v.size():
		v[i] = to_final(src_v[i])
		n[i] = Vector3(-src_n[i].x, src_n[i].y, -src_n[i].z)
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	for i in src_v.size():
		var pairs: Array = bw[i]
		for k in 4:
			bones.append(pairs[k][0] if k < pairs.size() else 0)
			wts.append(pairs[k][1] if k < pairs.size() else 0.0)

	# skeleton (rest rotations are identity, so animation axes are model axes:
	# +X = the zombie's right / club side, -Z = forward, +Y = up)
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	for b in BONES:
		var i := skel.get_bone_count()
		skel.add_bone(b[0])
		bone_index[b[0]] = i
		var head_final := to_final(b[2])
		var parent_final := Vector3.ZERO
		if b[1] != "":
			skel.set_bone_parent(i, bone_index[b[1]])
			parent_final = to_final(BONES[bone_index[b[1]]][2])
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, head_final - parent_final))
	skel.reset_bone_poses()

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(ALBEDO)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.9
	mat.metallic_specular = 0.2
	# Double-sided: wherever a deforming joint folds a sliver of surface over,
	# you see the inside of the shirt rather than through the body.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ResourceSaver.save(mat, OUT_DIR + "shambler_material.tres")
	mat.take_over_path(OUT_DIR + "shambler_material.tres")

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
	print("LOD levels: ", im.get_surface_lod_count(0))
	for l in im.get_surface_lod_count(0):
		print("   lod %d: %d tris (from %.2f m screen error)" % [l, im.get_surface_lod_indices(0, l).size() / 3, im.get_surface_lod_size(0, l)])

	var root := Node3D.new()
	root.name = "ShamblerModel"
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
	ResourceSaver.save(lib, OUT_DIR + "shambler_anims.tres")
	lib.take_over_path(OUT_DIR + "shambler_anims.tres")
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

func own(n: Node, owner: Node) -> void:
	n.owner = owner
	for c in n.get_children():
		own(c, owner)

# ------------------------------------------------------------ weights ----
func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func skin_weights(v: PackedVector3Array, idx: PackedInt32Array) -> Array:
	# weld duplicate positions (UV seams) so the surface graph is connected
	var key := {}
	var weld := PackedInt32Array()
	weld.resize(v.size())
	var wpos := []
	for i in v.size():
		var k := Vector3i(roundi(v[i].x * 1e4), roundi(v[i].y * 1e4), roundi(v[i].z * 1e4))
		if not key.has(k):
			key[k] = wpos.size()
			wpos.append(v[i])
		weld[i] = key[k]
	var nw := wpos.size()
	var adj := []
	adj.resize(nw)
	for i in nw:
		adj[i] = {}
	for t in range(0, idx.size(), 3):
		for e in [[0, 1], [1, 2], [2, 0]]:
			var a := weld[idx[t + e[0]]]
			var b := weld[idx[t + e[1]]]
			if a != b:
				var d: float = (wpos[a] as Vector3).distance_to(wpos[b])
				adj[a][b] = d
				adj[b][a] = d
	# Labels. The mushroom cap is everything above the 2 cm gap over the
	# shoulders (outside the neck); the neck/face core is split by height;
	# everything else goes to the bone whose limb-sized capsule is nearest.
	var label := PackedInt32Array()
	label.resize(nw)
	var torso_only := ["hips", "spine", "chest", "neck", "head"]
	for i in nw:
		var p: Vector3 = wpos[i]
		var r := Vector2(p.x - NECK_AXIS.x, p.z - NECK_AXIS.y).length()
		if p.y >= CAP_LINE and r >= NECK_CORE_R:
			label[i] = bone_of("head")
			continue
		if r < NECK_CORE_R and p.y >= 0.69:
			label[i] = bone_of("head") if p.y >= 0.745 else bone_of("neck")
			continue
		var best := 1
		var bd := INF
		for bi in range(1, BONES.size()):
			var bn: String = BONES[bi][0]
			if (bn == "head" or bn == "neck") and p.y < 0.66:
				continue
			if bn.begins_with("thigh") and p.y > 0.39:
				continue  # the shirt hem hangs over the thighs; it stays with the torso
			var d: float = seg_dist(p, BONES[bi][2], BONES[bi][3]) - RADII.get(bn, 0.06)
			if d < bd:
				bd = d
				best = bi
		label[i] = best
	# Clean-up: any patch of a bone that isn't connected to that bone's main
	# body (a shard of club stuck to the leg, say) joins its neighbours.
	for pass_i in 3:
		var comp_id := PackedInt32Array()
		comp_id.resize(nw)
		comp_id.fill(-1)
		var comps := []
		for i in nw:
			if comp_id[i] >= 0:
				continue
			var cid := comps.size()
			var members := [i]
			comp_id[i] = cid
			var k := 0
			while k < members.size():
				for j in adj[members[k]]:
					if comp_id[j] < 0 and label[j] == label[i]:
						comp_id[j] = cid
						members.append(j)
				k += 1
			comps.append(members)
		var biggest := {}
		for cid in comps.size():
			var b: int = label[comps[cid][0]]
			if not biggest.has(b) or comps[cid].size() > comps[biggest[b]].size():
				biggest[b] = cid
		var moved := 0
		for cid in comps.size():
			var b: int = label[comps[cid][0]]
			if biggest[b] == cid:
				continue
			var votes := {}
			for u in comps[cid]:
				for j in adj[u]:
					if label[j] != b:
						votes[label[j]] = votes.get(label[j], 0) + 1
			var winner := b
			var top := -1
			for nb in votes:
				if votes[nb] > top:
					top = votes[nb]
					winner = nb
			for u in comps[cid]:
				label[u] = winner
			moved += comps[cid].size()
		print("clean-up pass %d: %d stray vertices rejoined" % [pass_i + 1, moved])
		if moved == 0:
			break
	if OS.get_cmdline_user_args().has("--diag"):
		var armset := ["arm_l", "forearm_l", "hand_l", "arm_r", "forearm_r", "club_r"]
		var torso := ["spine", "hips", "chest", "thigh_l", "thigh_r"]
		var bridges := {}
		for t in range(0, idx.size(), 3):
			var ls := []
			var ys := 0.0
			for k in 3:
				ls.append(BONES[label[weld[idx[t + k]]]][0])
				ys += (wpos[weld[idx[t + k]]] as Vector3).y / 3.0
			var arm_b := ""
			var tor_b := ""
			for l in ls:
				if l in armset: arm_b = l
				if l in torso: tor_b = l
			if arm_b != "" and tor_b != "" and ys < 0.63:
				var k2: String = arm_b + "+" + tor_b
				bridges[k2] = bridges.get(k2, 0) + 1
		print("arm-to-body bridge triangles below the shoulder: ", bridges)
	var counts := {}
	for i in nw:
		counts[BONES[label[i]][0]] = counts.get(BONES[label[i]][0], 0) + 1
	print("vertices per bone: ", counts)
	if OS.get_cmdline_user_args().has("--diag"):
		var club := {}
		for i in nw:
			var p: Vector3 = wpos[i]
			if p.x < -0.2 and p.y > 0.25 and p.y < 0.64:
				club[BONES[label[i]][0]] = club.get(BONES[label[i]][0], 0) + 1
		print("club-region labels: ", club)
	# Weights.
	#  torso (hips..head): smooth ramps by height across each joint, so the
	#    spine and neck bend instead of creasing; the cap is 100% head
	#  limbs: half-and-half at each joint, fading over BLEND_R either side
	var related := []
	for bi in BONES.size():
		var rel := {bi: true}
		for bj in BONES.size():
			if BONES[bj][1] == BONES[bi][0] or BONES[bi][1] == BONES[bj][0]:
				rel[bj] = true
		related.append(rel)
	var chain := ["hips", "spine", "chest", "neck", "head"]
	var w := []
	for i in nw:
		var p: Vector3 = wpos[i]
		var lb: String = BONES[label[i]][0]
		var acc := {}
		var r := Vector2(p.x - NECK_AXIS.x, p.z - NECK_AXIS.y).length()
		if lb == "head" and p.y >= CAP_LINE and r >= NECK_CORE_R:
			acc[label[i]] = 1.0
		elif lb in chain:
			# ramp: weight of chain[k] = t_k * (1 - t_{k+1})
			var ts := [1.0]
			for k in range(1, chain.size()):
				var jh: float = TORSO_JOINTS[chain[k]][0]
				var hw: float = TORSO_JOINTS[chain[k]][1]
				ts.append(smoothstep(jh - hw, jh + hw, p.y))
			ts.append(0.0)
			for k in chain.size():
				var wk: float = ts[k] * (1.0 - ts[k + 1])
				if wk > 0.001:
					acc[bone_of(chain[k])] = wk
		else:
			var bi := label[i]
			var head_j: Vector3 = BONES[bi][2]
			var dir: Vector3 = (BONES[bi][3] - BONES[bi][2]).normalized()
			var sp := (p - head_j).dot(dir)
			var rr: float = BLEND_R.get(lb, 0.035)
			var wp := clampf(0.5 * (1.0 - sp / rr), 0.0, 1.0)
			acc[bi] = 1.0 - wp
			if wp > 0.0:
				acc[bone_of(BONES[bi][1])] = wp
		# parent side of a limb joint: blend into the child limb
		for ci in BONES.size():
			var cn: String = BONES[ci][0]
			if not BLEND_R.has(cn) or BONES[ci][1] == "" or bone_of(BONES[ci][1]) != label[i]:
				continue
			var hj: Vector3 = BONES[ci][2]
			var cdir: Vector3 = (BONES[ci][3] - BONES[ci][2]).normalized()
			var s2 := (p - hj).dot(cdir)
			var rr2: float = BLEND_R[cn]
			var reach: float = RADII.get(cn, 0.06) * (2.4 if cn == "arm_l" else 1.6) + rr2  # armpits need a wide blend
			if s2 > -rr2 and p.distance_to(hj) < reach:
				var wc := clampf(0.5 * (1.0 + s2 / rr2), 0.0, 0.5)
				for k in acc:
					acc[k] *= (1.0 - wc)
				acc[ci] = acc.get(ci, 0.0) + wc
		w.append(acc)
	# two light smoothing passes between connected bones to remove jaggies
	for iter in 2:
		var nwts := []
		for i in nw:
			var acc := {}
			var own_l := label[i]
			var total := 1.0
			for b in w[i]:
				acc[b] = w[i][b]
			for j in adj[i]:
				var ok := true
				for b in w[j]:
					if not related[own_l].has(b) and not (BONES[b][0] in chain and BONES[own_l][0] in chain):
						ok = false
				if ok:
					for b in w[j]:
						acc[b] = acc.get(b, 0.0) + w[j][b]
					total += 1.0
			for b in acc:
				acc[b] /= total
			nwts.append(acc)
		w = nwts
	# top 4, normalised, mapped back to the unwelded vertices
	var per_vertex := []
	for i in v.size():
		var acc: Dictionary = w[weld[i]]
		var pairs := []
		for b in acc:
			pairs.append([b, acc[b]])
		pairs.sort_custom(func(p, q): return p[1] > q[1])
		pairs = pairs.slice(0, 4)
		var s := 0.0
		for p in pairs:
			s += p[1]
		for p in pairs:
			p[1] /= s
		per_vertex.append(pairs)
	var lab := []
	for i in v.size():
		lab.append(label[weld[i]])
	return [lab, per_vertex]

# --------------------------------------------------------- animations ----
# Rotations are Euler degrees on model axes. With rest rotations at identity:
#   legs/arms hanging down: +X swings them forward (toward -Z)
#   spine/neck/head pointing up: -X leans forward
#   right (club) arm: +Z lifts it outward; left arm: -Z lifts it outward
#   +Y twists left-to-right as seen from above
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
		anim.position_track_insert_key(t, k[0], rest_pos(bone) + (k[1] as Vector3) * scale_f)

# Looping clip sampled from functions of phase (0..TAU).
func cyclic(length: float, samples: int, rot_fns: Dictionary, pos_fns: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	for bone in rot_fns:
		var keys := []
		for s in samples + 1:
			var ph := TAU * s / samples
			keys.append([length * s / samples, rot_fns[bone].call(ph)])
		add_rot(a, bone, keys)
	for bone in pos_fns:
		var keys := []
		for s in samples + 1:
			var ph := TAU * s / samples
			keys.append([length * s / samples, pos_fns[bone].call(ph)])
		add_pos(a, bone, keys)
	return a

# One-shot clip from pose keyframes: {bone: [[t, euler], ...]}
func posed(length: float, rots: Dictionary, poss: Dictionary, loop := false) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for bone in rots:
		add_rot(a, bone, rots[bone])
	for bone in poss:
		add_pos(a, bone, poss[bone])
	return a

func make_clips() -> Array:
	var V := func(x: float, y := 0.0, z := 0.0) -> Vector3: return Vector3(x, y, z)
	var clips := []

	# IDLE: swaying, breathing, head lolling, club hanging heavy.
	clips.append(["idle", cyclic(2.6, 12, {
		"hips": func(p): return V.call(0, 4 * sin(p), 2 * sin(p + 1)),
		"spine": func(p): return V.call(-8 + 2 * sin(p), 0, 0),
		"chest": func(p): return V.call(-8 + 3 * sin(p + 0.6), 6 * sin(p), 3 * sin(p)),
		"neck": func(p): return V.call(4 + 2 * sin(p + 1.2), 4 * sin(p), 5 * sin(p + 0.4)),
		"head": func(p): return V.call(6 + 2 * sin(p + 1.2), 4 * sin(p), 5 * sin(p + 0.4)),
		"arm_r": func(p): return V.call(4 + 3 * sin(p + 1), 0, 8 + 3 * sin(p)),
		"forearm_r": func(p): return V.call(10, 0, 0),
		"arm_l": func(p): return V.call(18 + 8 * sin(p), 0, -6),
		"forearm_l": func(p): return V.call(22 + 6 * sin(p + 0.5), 0, 0),
		"hand_l": func(p): return V.call(15 * sin(p + 1.5), 0, 0),
		"thigh_r": func(p): return V.call(6, 0, 3),
		"shin_r": func(p): return V.call(-10, 0, 0),
		"thigh_l": func(p): return V.call(-6, 0, -6),
		"shin_l": func(p): return V.call(-14, 0, 0),
		"foot_l": func(p): return V.call(12, 0, 0),
	}, {"hips": func(p): return V.call(0, -0.012 + 0.006 * sin(p * 2.0), 0)})])

	# SHAMBLE: limping walk — boot leg strides, rooted leg drags; club swings.
	# One cycle = two steps, 1.5 s; matches ~0.9 m/s (see shambler.gd).
	clips.append(["shamble", cyclic(1.5, 16, {
		"hips": func(p): return V.call(0, 9 * sin(p), 7 * sin(p)),
		"spine": func(p): return V.call(-12, -4 * sin(p), 0),
		"chest": func(p): return V.call(-10 + 3 * sin(p * 2.0), -12 * sin(p), -5 * sin(p)),
		"neck": func(p): return V.call(8 + 2 * sin(p * 2.0 + 1), 3 * sin(p), 5 * sin(p + 0.5)),
		"head": func(p): return V.call(10 + 2 * sin(p * 2.0 + 1), 3 * sin(p), 5 * sin(p + 0.5)),
		"arm_r": func(p): return V.call(6 - 16 * sin(p), 0, 12 + 4 * sin(p * 2.0)),
		"forearm_r": func(p): return V.call(10 + 8 * sin(p + 0.8), 0, 0),
		"club_r": func(p): return V.call(6 * sin(p + 1.6), 0, 0),
		"arm_l": func(p): return V.call(62 + 10 * sin(p * 2.0), 0, -10),
		"forearm_l": func(p): return V.call(18 + 8 * sin(p * 2.0 + 0.5), 0, 0),
		"hand_l": func(p): return V.call(18 * sin(p * 2.0 + 1.2), 0, 0),
		"thigh_r": func(p): return V.call(26 * sin(p), 0, 3),
		"shin_r": func(p): return V.call(-(8 + 34 * maxf(0.0, sin(p + 1.7))), 0, 0),
		"foot_r": func(p): return V.call(12 * sin(p + 0.6), 0, 0),
		"thigh_l": func(p): return V.call(-16 * sin(p), 0, -7),
		"shin_l": func(p): return V.call(-(16 + 14 * maxf(0.0, sin(-p + 1.7))), 0, 0),
		"foot_l": func(p): return V.call(10 - 8 * sin(p), 0, 0),
	}, {"hips": func(p): return V.call(0.004 * sin(p), -0.02 - 0.012 * absf(cos(p)), 0)})])

	# RIP: club arm hooks a board, yanks it free. Board comes off at 1.05 s.
	var rip_r := [[0.0, V.call(20, 0, 10)], [0.45, V.call(115, 0, 18)], [0.75, V.call(75, 0, 8)],
		[1.05, V.call(-25, 0, 14)], [1.5, V.call(20, 0, 10)]]
	clips.append(["rip", posed(1.5, {
		"arm_r": rip_r,
		"forearm_r": [[0.0, V.call(10)], [0.45, V.call(35)], [0.75, V.call(10)], [1.05, V.call(40)], [1.5, V.call(10)]],
		"chest": [[0.0, V.call(-8)], [0.45, V.call(6, 10, 0)], [0.75, V.call(-26, -6, 0)], [1.05, V.call(4, -22, 0)], [1.5, V.call(-8)]],
		"spine": [[0.0, V.call(-8)], [0.75, V.call(-18)], [1.05, V.call(-4)], [1.5, V.call(-8)]],
		"neck": [[0.0, V.call(4)], [0.45, V.call(8)], [0.75, V.call(-2)], [1.05, V.call(6, 0, 4)], [1.5, V.call(4)]],
		"head": [[0.0, V.call(6)], [0.45, V.call(10)], [0.75, V.call(0)], [1.05, V.call(6, 0, 5)], [1.5, V.call(6)]],
		"arm_l": [[0.0, V.call(55, 0, -8)], [0.45, V.call(65, 0, -12)], [0.75, V.call(60)], [1.05, V.call(35)], [1.5, V.call(55, 0, -8)]],
		"forearm_l": [[0.0, V.call(25)], [0.75, V.call(10)], [1.05, V.call(45)], [1.5, V.call(25)]],
		"thigh_r": [[0.0, V.call(10)], [0.75, V.call(22)], [1.05, V.call(-6)], [1.5, V.call(10)]],
		"shin_r": [[0.0, V.call(-12)], [0.75, V.call(-24)], [1.5, V.call(-12)]],
		"thigh_l": [[0.0, V.call(-8, 0, -6)], [1.05, V.call(-14, 0, -6)], [1.5, V.call(-8, 0, -6)]],
		"shin_l": [[0.0, V.call(-16)], [1.5, V.call(-16)]],
	}, {"hips": [[0.0, V.call(0, -0.02, 0)], [0.75, V.call(0, -0.045, -0.02)], [1.05, V.call(0, -0.02, 0.02)], [1.5, V.call(0, -0.02, 0)]]}, true)])

	# SWING: big horizontal club swing at the player. Hit lands at 0.62 s.
	clips.append(["swing", posed(1.2, {
		"arm_r": [[0.0, V.call(6, 0, 10)], [0.38, V.call(45, 0, 78)], [0.62, V.call(80, 0, 15)], [0.85, V.call(48, 0, -12)], [1.2, V.call(6, 0, 10)]],
		"forearm_r": [[0.0, V.call(10)], [0.38, V.call(30)], [0.62, V.call(8)], [1.2, V.call(10)]],
		"chest": [[0.0, V.call(-8)], [0.38, V.call(0, 38, 4)], [0.62, V.call(-18, -36, 0)], [0.85, V.call(-14, -48, -4)], [1.2, V.call(-8)]],
		"spine": [[0.0, V.call(-8)], [0.38, V.call(-2, 14, 0)], [0.62, V.call(-12, -14, 0)], [1.2, V.call(-8)]],
		"neck": [[0.0, V.call(4)], [0.38, V.call(4, -8, 0)], [0.62, V.call(6, 9, 0)], [1.2, V.call(4)]],
		"head": [[0.0, V.call(6)], [0.38, V.call(4, -8, 0)], [0.62, V.call(8, 9, 0)], [1.2, V.call(6)]],
		"arm_l": [[0.0, V.call(40, 0, -10)], [0.38, V.call(20, 0, -40)], [0.62, V.call(30, 0, -20)], [1.2, V.call(40, 0, -10)]],
		"thigh_r": [[0.0, V.call(6)], [0.38, V.call(-10)], [0.62, V.call(24)], [1.2, V.call(6)]],
		"shin_r": [[0.0, V.call(-10)], [0.62, V.call(-26)], [1.2, V.call(-10)]],
		"thigh_l": [[0.0, V.call(-6, 0, -6)], [0.62, V.call(-18, 0, -8)], [1.2, V.call(-6, 0, -6)]],
		"shin_l": [[0.0, V.call(-14)], [0.62, V.call(-20)], [1.2, V.call(-14)]],
	}, {"hips": [[0.0, V.call(0, -0.015, 0)], [0.62, V.call(0, -0.05, -0.03)], [1.2, V.call(0, -0.015, 0)]]})])

	# CLIMB: hunched scramble through a window (the body is moved by code).
	clips.append(["climb", posed(1.6, {
		"spine": [[0.0, V.call(-10)], [0.3, V.call(-38)], [1.2, V.call(-42)], [1.6, V.call(-10)]],
		"chest": [[0.0, V.call(-8)], [0.3, V.call(-34)], [1.2, V.call(-30)], [1.6, V.call(-8)]],
		"neck": [[0.0, V.call(4)], [0.3, V.call(14)], [1.6, V.call(4)]],
		"head": [[0.0, V.call(6)], [0.3, V.call(14)], [1.6, V.call(6)]],
		"arm_r": [[0.0, V.call(10, 0, 10)], [0.3, V.call(85, 0, 12)], [0.8, V.call(40, 0, 10)], [1.6, V.call(6, 0, 10)]],
		"arm_l": [[0.0, V.call(40)], [0.3, V.call(65, 0, -8)], [0.8, V.call(45)], [1.6, V.call(30)]],
		"forearm_l": [[0.0, V.call(20)], [0.3, V.call(30)], [1.6, V.call(20)]],
		"thigh_r": [[0.0, V.call(6)], [0.35, V.call(70)], [0.75, V.call(35)], [1.2, V.call(60)], [1.6, V.call(6)]],
		"shin_r": [[0.0, V.call(-10)], [0.35, V.call(-80)], [0.75, V.call(-45)], [1.2, V.call(-75)], [1.6, V.call(-10)]],
		"thigh_l": [[0.0, V.call(-6)], [0.35, V.call(25)], [0.75, V.call(65)], [1.2, V.call(30)], [1.6, V.call(-6)]],
		"shin_l": [[0.0, V.call(-14)], [0.35, V.call(-50)], [0.75, V.call(-80)], [1.2, V.call(-35)], [1.6, V.call(-14)]],
	}, {"hips": [[0.0, V.call(0, -0.02, 0)], [0.3, V.call(0, -0.16, 0.02)], [1.2, V.call(0, -0.16, 0.02)], [1.6, V.call(0, -0.02, 0)]]})])

	# FLINCH: snap back from a hit.
	clips.append(["flinch", posed(0.42, {
		"chest": [[0.0, V.call(-8)], [0.08, V.call(16, 8, 6)], [0.42, V.call(-8)]],
		"spine": [[0.0, V.call(-8)], [0.08, V.call(6)], [0.42, V.call(-8)]],
		"neck": [[0.0, V.call(4)], [0.08, V.call(-10, 0, -5)], [0.42, V.call(4)]],
		"head": [[0.0, V.call(6)], [0.08, V.call(-10, 0, -5)], [0.42, V.call(6)]],
		"arm_r": [[0.0, V.call(6, 0, 10)], [0.1, V.call(-12, 0, 24)], [0.42, V.call(6, 0, 10)]],
		"arm_l": [[0.0, V.call(40)], [0.1, V.call(10, 0, -40)], [0.42, V.call(40)]],
	}, {})])

	# DEATH: knees buckle, topples forward, stays down.
	clips.append(["death", posed(1.7, {
		"root": [[0.0, V.call(0)], [0.35, V.call(0)], [1.1, V.call(-82)], [1.7, V.call(-86)]],
		"spine": [[0.0, V.call(-8)], [0.35, V.call(-22)], [1.1, V.call(6)], [1.7, V.call(4)]],
		"chest": [[0.0, V.call(-8)], [0.35, V.call(-14, 12, 0)], [1.1, V.call(4, 6, 0)], [1.7, V.call(2, 6, 0)]],
		"neck": [[0.0, V.call(4)], [0.35, V.call(10)], [1.1, V.call(-10, 0, 14)], [1.7, V.call(-8, 0, 16)]],
		"head": [[0.0, V.call(6)], [0.35, V.call(12)], [1.1, V.call(-14, 0, 18)], [1.7, V.call(-12, 0, 22)]],
		"arm_r": [[0.0, V.call(6, 0, 10)], [0.35, V.call(-20, 0, 20)], [1.1, V.call(150, 0, 20)], [1.7, V.call(160, 0, 26)]],
		"arm_l": [[0.0, V.call(40)], [0.35, V.call(20, 0, -30)], [1.1, V.call(130, 0, -20)], [1.7, V.call(140, 0, -24)]],
		"thigh_r": [[0.0, V.call(6)], [0.35, V.call(45)], [1.1, V.call(20)], [1.7, V.call(14)]],
		"shin_r": [[0.0, V.call(-10)], [0.35, V.call(-70)], [1.1, V.call(-30)], [1.7, V.call(-20)]],
		"thigh_l": [[0.0, V.call(-6)], [0.35, V.call(35)], [1.1, V.call(10)], [1.7, V.call(6)]],
		"shin_l": [[0.0, V.call(-14)], [0.35, V.call(-65)], [1.1, V.call(-20)], [1.7, V.call(-10)]],
	}, {"hips": [[0.0, V.call(0, -0.015, 0)], [0.35, V.call(0, -0.13, 0.02)], [1.1, V.call(0, -0.05, 0)], [1.7, V.call(0, -0.05, 0)]],
		"root": [[0.0, V.call(0)], [0.35, V.call(0)], [1.1, V.call(0, 0.08, 0)], [1.7, V.call(0, 0.08, 0)]]})])
	return clips
