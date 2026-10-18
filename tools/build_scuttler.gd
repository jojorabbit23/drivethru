# Turns the static glowing-mushroom GLB into the rigged, animated Scuttler.
#
#   godot --headless --path . --script res://tools/build_scuttler.gd
#   godot --headless --path . --import          # first run only (new PNGs)
#   godot --headless --path . --script res://tools/build_scuttler.gd
#
# The model was sculpted mid-stride (left boot planted forward, right boot
# lifted behind). Legs are therefore animated with two-bone IK: each clip says
# where the ankles go and how the boots are pitched, and the hip / knee / ankle
# rotations are solved from that. Boots stay flat, the stance is symmetrical
# even though the sculpt isn't, and feet don't slide or sink.
#
# Skeleton (final space: faces -Z, +Y up, its left side is -X):
#   root ─ hips ─┬─ body ─ cap
#                ├─ thigh_l ─ shin_l ─ foot_l
#                └─ thigh_r ─ shin_r ─ foot_r
# Legs hang off hips (not body) so the body and cap can squash and wobble
# without dragging the legs.
# Output: res://enemies/scuttler/scuttler_model.tscn (+ textures, material, anims)
extends SceneTree

const SRC := "res://enemies/scuttler/source/Mushroom_AllAround_Glow_1.glb"
const OUT := "res://enemies/scuttler/"
const HEIGHT := 1.05        # cap top above the floor, metres
const TEX_SIZE := 1024
const FPS := 30.0

# Source space (faces +Z; its LEFT is +X). [name, parent, head, tail]
const BONES := [
	["root", "", Vector3(0, 0, 0), Vector3(0, 0.02, 0)],
	["hips", "root", Vector3(0, 0.30, 0), Vector3(0, 0.38, 0)],
	["body", "hips", Vector3(0, 0.38, 0), Vector3(0, 0.54, 0)],
	["cap", "body", Vector3(0, 0.56, 0), Vector3(0, 0.95, 0)],
	["thigh_l", "hips", Vector3(0.10, 0.32, 0.0), Vector3(0.16, 0.20, 0.03)],
	["shin_l", "thigh_l", Vector3(0.16, 0.20, 0.03), Vector3(0.21, 0.11, 0.06)],
	["foot_l", "shin_l", Vector3(0.21, 0.11, 0.06), Vector3(0.24, 0.03, 0.22)],
	["thigh_r", "hips", Vector3(-0.11, 0.32, -0.02), Vector3(-0.18, 0.23, -0.12)],
	["shin_r", "thigh_r", Vector3(-0.18, 0.23, -0.12), Vector3(-0.24, 0.15, -0.21)],
	["foot_r", "shin_r", Vector3(-0.24, 0.15, -0.21), Vector3(-0.27, 0.02, -0.18)],
]
const RADII := {"hips": 0.13, "body": 0.16, "thigh_l": 0.075, "shin_l": 0.07, "foot_l": 0.085,
	"thigh_r": 0.075, "shin_r": 0.07, "foot_r": 0.085}
const LEG_TOP := 0.29        # trousers start here; above is mushroom flesh
const CAP_Y := 0.62          # everything above this is cap
const CAP_BRIM_Y := 0.50     # ...and above this, outside the stalk radius
const STALK_R := 0.19
const BLEND_R := {"thigh_l": 0.05, "shin_l": 0.035, "foot_l": 0.03, "thigh_r": 0.05, "shin_r": 0.035, "foot_r": 0.03}

var s := 1.0                 # source -> metres
var bi := {}                 # bone name -> index
var rest_g := {}             # bone name -> global rest head (final space)
var foot_axis := {}          # side -> measured boot direction heel->toe (final space)

func F(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, -p.z) * s

func _initialize() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path(SRC), st) == OK)
	var arr := (st.get_meshes()[0] as GLTFMesh).mesh.get_surface_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var top := 0.0
	for p in v:
		top = maxf(top, p.y)
	s = HEIGHT / top
	print("source height %.3f -> scale %.3f" % [top, s])

	# textures: the repainted cap colour and the orange-spot glow mask
	var albedo := OUT + "scuttler_albedo.png"
	var glow := OUT + "scuttler_glow.png"
	if not FileAccess.file_exists(albedo):
		var by_name := {}
		for t in st.get_images():
			by_name[t.resource_name] = t
		var imgs: Array = st.get_images()
		var names := []
		for i in imgs.size():
			names.append(st.json["images"][i].get("name", ""))
		var ai := names.find("Cap_AllAround_Colour")
		var gi := names.find("Cap_Orange_Spot_Glow")
		assert(ai >= 0 and gi >= 0, "expected Cap_AllAround_Colour and Cap_Orange_Spot_Glow images")
		for pair in [[ai, albedo], [gi, glow]]:
			var img: Image = (imgs[pair[0]] as Texture2D).get_image()
			img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			if pair[1] == glow:
				# emission ignores alpha: bake it in so only the spots glow
				for y in img.get_height():
					for x in img.get_width():
						var c := img.get_pixel(x, y)
						img.set_pixel(x, y, Color(c.r * c.a, c.g * c.a, c.b * c.a, 1.0))
			img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_LANCZOS)
			img.save_png(ProjectSettings.globalize_path(pair[1]))
		print("wrote textures — run --import, then this script again")
		quit()
		return

	var w := skin_weights(v, idx)
	var labels: Array = w[0]
	var bw: Array = w[1]
	# measure each boot's real direction (principal axis of its vertices)
	for side in ["l", "r"]:
		var fi := bone_i("foot_" + side)
		var pts := []
		for i in v.size():
			if labels[i] == fi:
				pts.append(F(v[i]))
		foot_axis[side] = principal_axis(pts)
		print("boot %s: %d verts, axis %s" % [side, pts.size(), str(foot_axis[side].snapped(Vector3.ONE * 0.01))])
	assert(open_edges(v, idx) == 0, "mesh must stay watertight")

	var fv := PackedVector3Array()
	var fn := PackedVector3Array()
	fv.resize(v.size())
	fn.resize(v.size())
	for i in v.size():
		fv[i] = F(v[i])
		fn[i] = Vector3(-nrm[i].x, nrm[i].y, -nrm[i].z)
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	for i in v.size():
		var pairs: Array = bw[i]
		for k in 4:
			bones.append(pairs[k][0] if k < pairs.size() else 0)
			wts.append(pairs[k][1] if k < pairs.size() else 0.0)

	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	for b in BONES:
		var i := skel.get_bone_count()
		skel.add_bone(b[0])
		bi[b[0]] = i
		rest_g[b[0]] = F(b[2])
		var parent_head := Vector3.ZERO
		if b[1] != "":
			skel.set_bone_parent(i, bi[b[1]])
			parent_head = F(BONES[bi[b[1]]][2])
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, F(b[2]) - parent_head))
	skel.reset_bone_poses()

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(albedo)
	mat.emission_enabled = true
	mat.emission_texture = load(glow)
	mat.emission = Color.WHITE
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY  # default ADD would glow white everywhere
	mat.emission_energy_multiplier = 1.8
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.85
	mat.metallic_specular = 0.25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ResourceSaver.save(mat, OUT + "scuttler_material.tres")
	mat.take_over_path(OUT + "scuttler_material.tres")

	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = fv
	surface[Mesh.ARRAY_NORMAL] = fn
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
	for l in im.get_surface_lod_count(0):
		print("   lod %d: %d tris" % [l, im.get_surface_lod_indices(0, l).size() / 3])

	var root := Node3D.new()
	root.name = "ScuttlerModel"
	root.add_child(skel)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = im.get_mesh()
	skel.add_child(mi)
	mi.skin = skel.create_skin_from_rest_transforms()
	mi.skeleton = NodePath("..")
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	var lib := AnimationLibrary.new()
	for c in make_clips():
		lib.add_animation(c[0], c[1])
	ResourceSaver.save(lib, OUT + "scuttler_anims.tres")
	lib.take_over_path(OUT + "scuttler_anims.tres")
	ap.add_animation_library("", lib)
	ap.playback_default_blend_time = 0.12
	ap.autoplay = "idle"
	for c in root.get_children():
		_own(c, root)
	var ps := PackedScene.new()
	ps.pack(root)
	print("saved ", OUT + "scuttler_model.tscn", " err=", ResourceSaver.save(ps, OUT + "scuttler_model.tscn"),
		"  tris ", idx.size() / 3, "  bones ", skel.get_bone_count())
	root.free()
	quit()

func _own(n: Node, owner: Node) -> void:
	n.owner = owner
	for c in n.get_children():
		_own(c, owner)

# ------------------------------------------------------------ weights ----
func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func bone_i(name: String) -> int:
	for i in BONES.size():
		if BONES[i][0] == name:
			return i
	return -1

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

func skin_weights(v: PackedVector3Array, idx: PackedInt32Array) -> Array:
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
				adj[a][b] = true
				adj[b][a] = true
	# labels: cap by region, the rest to the nearest limb-sized capsule
	var label := PackedInt32Array()
	label.resize(nw)
	var cap_i := bone_i("cap")
	for i in nw:
		var p: Vector3 = wpos[i]
		var r := Vector2(p.x, p.z).length()
		if p.y >= CAP_Y or (p.y >= CAP_BRIM_Y and r >= STALK_R):
			label[i] = cap_i
			continue
		var best := 1
		var bd := INF
		for b in range(1, BONES.size()):
			var bn: String = BONES[b][0]
			if bn == "cap":
				continue
			if (bn.begins_with("thigh") or bn.begins_with("shin") or bn.begins_with("foot")) and p.y > LEG_TOP:
				continue  # the bulb above the trousers stays with the body
			var d: float = seg_dist(p, BONES[b][2], BONES[b][3]) - RADII.get(bn, 0.08)
			if d < bd:
				bd = d
				best = b
		label[i] = best
	# stray patches rejoin their neighbours
	for pass_i in 3:
		var comp := PackedInt32Array()
		comp.resize(nw)
		comp.fill(-1)
		var comps := []
		for i in nw:
			if comp[i] >= 0:
				continue
			var members := [i]
			comp[i] = comps.size()
			var k := 0
			while k < members.size():
				for j in adj[members[k]]:
					if comp[j] < 0 and label[j] == label[i]:
						comp[j] = comps.size()
						members.append(j)
				k += 1
			comps.append(members)
		var biggest := {}
		for c in comps.size():
			var b: int = label[comps[c][0]]
			if not biggest.has(b) or comps[c].size() > comps[biggest[b]].size():
				biggest[b] = c
		var moved := 0
		for c in comps.size():
			var b: int = label[comps[c][0]]
			if biggest[b] == c:
				continue
			var votes := {}
			for u in comps[c]:
				for j in adj[u]:
					if label[j] != b:
						votes[label[j]] = votes.get(label[j], 0) + 1
			var win := b
			var top := -1
			for nb in votes:
				if votes[nb] > top:
					top = votes[nb]
					win = nb
			for u in comps[c]:
				label[u] = win
			moved += comps[c].size()
		print("clean-up pass %d: %d stray vertices rejoined" % [pass_i + 1, moved])
		if moved == 0:
			break
	var counts := {}
	for i in nw:
		counts[BONES[label[i]][0]] = counts.get(BONES[label[i]][0], 0) + 1
	print("vertices per bone: ", counts)
	# weights: hips->body->cap ramp by height (the stalk bends smoothly), the
	# cap brim is solid cap, legs blend half-and-half at each joint
	var w := []
	var hips_i := bone_i("hips")
	var body_i := bone_i("body")
	for i in nw:
		var p: Vector3 = wpos[i]
		var lb: String = BONES[label[i]][0]
		var acc := {}
		if lb == "cap" or lb == "body" or lb == "hips":
			var r := Vector2(p.x, p.z).length()
			if p.y >= CAP_BRIM_Y and r >= STALK_R:
				acc[cap_i] = 1.0
			else:
				var t1 := smoothstep(0.34, 0.42, p.y)   # hips -> body
				var t2 := smoothstep(0.52, 0.62, p.y)   # body -> cap
				acc[hips_i] = 1.0 - t1
				acc[body_i] = t1 * (1.0 - t2)
				acc[cap_i] = t2
		else:
			var b := label[i]
			var hj: Vector3 = BONES[b][2]
			var dir: Vector3 = (BONES[b][3] - BONES[b][2]).normalized()
			var sp := (p - hj).dot(dir)
			var rr: float = BLEND_R.get(lb, 0.035)
			var wp := clampf(0.5 * (1.0 - sp / rr), 0.0, 1.0)
			acc[b] = 1.0 - wp
			if wp > 0.0:
				acc[bone_i(BONES[b][1])] = wp
		# parent side: blend into a child leg bone near its joint
		for ci in BONES.size():
			var cn: String = BONES[ci][0]
			if not BLEND_R.has(cn) or bone_i(BONES[ci][1]) != label[i]:
				continue
			if cn.begins_with("thigh") and p.y > LEG_TOP + 0.015:
				continue  # the round belly above the trousers must not follow the legs
			var hj2: Vector3 = BONES[ci][2]
			var cdir: Vector3 = (BONES[ci][3] - BONES[ci][2]).normalized()
			var s2 := (p - hj2).dot(cdir)
			var rr2: float = BLEND_R[cn]
			if s2 > -rr2 and p.distance_to(hj2) < float(RADII.get(cn, 0.07)) * 1.6 + rr2:
				var wc := clampf(0.5 * (1.0 + s2 / rr2), 0.0, 0.5)
				for k in acc:
					acc[k] *= (1.0 - wc)
				acc[ci] = acc.get(ci, 0.0) + wc
		w.append(acc)
	for it in 2:
		var nwts := []
		for i in nw:
			var acc := {}
			var total := 1.0
			for b in w[i]:
				acc[b] = w[i][b]
			for j in adj[i]:
				# only smooth across bones that are actually joined
				var ok := true
				for b in w[j]:
					if not _related(label[i], b):
						ok = false
				if ok:
					for b in w[j]:
						acc[b] = acc.get(b, 0.0) + w[j][b]
					total += 1.0
			for b in acc:
				acc[b] /= total
			nwts.append(acc)
		w = nwts
	var per_vertex := []
	for i in v.size():
		var acc: Dictionary = w[weld[i]]
		var pairs := []
		for b in acc:
			pairs.append([b, acc[b]])
		pairs.sort_custom(func(p, q): return p[1] > q[1])
		pairs = pairs.slice(0, 4)
		var sum := 0.0
		for p in pairs:
			sum += p[1]
		for p in pairs:
			p[1] /= sum
		per_vertex.append(pairs)
	var lab := []
	for i in v.size():
		lab.append(label[weld[i]])
	return [lab, per_vertex]

func _related(a: int, b: int) -> bool:
	if a == b:
		return true
	var torso := [bone_i("hips"), bone_i("body"), bone_i("cap")]
	if a in torso and b in torso:
		return true
	return BONES[a][1] == BONES[b][0] or BONES[b][1] == BONES[a][0]

# ------------------------------------------------------- IK animation ----
# A pose is a Dictionary, all optional:
#   root_pos, root_rot (euler deg), hips_pos (offset m), hips_rot,
#   body_rot, body_scale (Vector3), cap_rot, cap_scale,
#   ankle_l, ankle_r (model-space ankle targets, metres), pitch_l, pitch_r
#   (boot pitch in degrees, + = toe up), lift (bool: unused)
# Unspecified ankles stay at the neutral stance.

func q(e: Vector3) -> Quaternion:
	return Basis.from_euler(e * (PI / 180.0)).get_rotation_quaternion()

func arc(a: Vector3, b: Vector3) -> Quaternion:
	a = a.normalized()
	b = b.normalized()
	var d := a.dot(b)
	if d > 0.99999:
		return Quaternion.IDENTITY
	if d < -0.99999:
		var ax := a.cross(Vector3.RIGHT)
		if ax.length() < 1e-3:
			ax = a.cross(Vector3.UP)
		return Quaternion(ax.normalized(), PI)
	return Quaternion(a.cross(b).normalized(), acos(clampf(d, -1.0, 1.0)))

func stance(side: String) -> Vector3:
	# neutral standing ankle position: under the hip, splayed out a little
	var x := -0.19 if side == "l" else 0.19   # its left is -X
	return Vector3(x, 0.11, 0.0) * s

func foot_flat(side: String) -> Quaternion:
	# The planted left boot is the reference: it stays as sculpted. The lifted
	# right boot is turned to match it, mirrored.
	if side == "l":
		return Quaternion.IDENTITY
	var l: Vector3 = foot_axis["l"]
	return arc(foot_axis["r"], Vector3(-l.x, l.y, l.z))

func principal_axis(pts: Array) -> Vector3:
	var mean := Vector3.ZERO
	for p in pts:
		mean += p
	mean /= pts.size()
	var cov := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	var c := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for p in pts:
		var d: Vector3 = p - mean
		for i in 3:
			for j in 3:
				c[i][j] += d[i] * d[j]
	var e := Vector3(0.1, -0.2, -1.0).normalized()
	for it in 60:
		e = Vector3(c[0][0] * e.x + c[0][1] * e.y + c[0][2] * e.z,
			c[1][0] * e.x + c[1][1] * e.y + c[1][2] * e.z,
			c[2][0] * e.x + c[2][1] * e.y + c[2][2] * e.z).normalized()
	if e.z > 0.0:
		e = -e   # point toward the toe (forward is -Z)
	return e

# Solves one leg; returns local rotations for thigh, shin, foot.
func solve_leg(side: String, parent_rot: Quaternion, hip_world: Vector3, target: Vector3, root_rot: Quaternion, pitch: float) -> Array:
	var H0: Vector3 = rest_g["thigh_" + side]
	var K0: Vector3 = rest_g["shin_" + side]
	var A0: Vector3 = rest_g["foot_" + side]
	var a := H0.distance_to(K0)
	var b := K0.distance_to(A0)
	var to_t := target - hip_world
	var c := clampf(to_t.length(), absf(a - b) + 0.001, a + b - 0.001)
	var u := to_t.normalized()
	var pole := root_rot * Vector3(0, 0, -1)                    # knees bend forward
	pole += root_rot * Vector3(-0.35 if side == "l" else 0.35, 0, 0)  # ...and a touch outward
	var vv := (pole - u * pole.dot(u)).normalized()
	var cos_a := (a * a + c * c - b * b) / (2.0 * a * c)
	var K := hip_world + u * a * cos_a + vv * a * sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var T := hip_world + u * c
	var g1 := arc(parent_rot * (K0 - H0), K - hip_world) * parent_rot
	var g2 := arc(g1 * (A0 - K0), T - K) * g1
	var gf := root_rot * q(Vector3(-pitch, 0, 0)) * foot_flat(side)
	return [parent_rot.inverse() * g1, g1.inverse() * g2, g2.inverse() * gf]

func pose_tracks(pose: Dictionary) -> Dictionary:
	var out := {}
	var rr := q(pose.get("root_rot", Vector3.ZERO))
	var rp: Vector3 = pose.get("root_pos", Vector3.ZERO)
	var hr := q(pose.get("hips_rot", Vector3.ZERO))
	var hp: Vector3 = rest_g["hips"] + pose.get("hips_pos", Vector3.ZERO)
	out["root"] = {"rot": rr, "pos": rp}
	out["hips"] = {"rot": hr, "pos": hp}
	out["body"] = {"rot": q(pose.get("body_rot", Vector3.ZERO)), "scale": pose.get("body_scale", Vector3.ONE)}
	out["cap"] = {"rot": q(pose.get("cap_rot", Vector3.ZERO)), "scale": pose.get("cap_scale", Vector3.ONE)}
	var hips_global := rr * hr
	for side in ["l", "r"]:
		var hip_world: Vector3 = rp + rr * (hp + hr * (rest_g["thigh_" + side] - rest_g["hips"]))
		var tgt: Vector3 = pose.get("ankle_" + side, stance(side))
		tgt = rp + rr * tgt   # ankle targets are given in the root's frame
		var rots := solve_leg(side, hips_global, hip_world, tgt, rr, pose.get("pitch_" + side, 0.0))
		out["thigh_" + side] = {"rot": rots[0]}
		out["shin_" + side] = {"rot": rots[1]}
		out["foot_" + side] = {"rot": rots[2]}
	return out

func bake(name: String, length: float, loop: bool, f: Callable) -> Array:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	var n := int(round(length * FPS))
	for k in n + 1:
		var t := length * k / n
		var tr := pose_tracks(f.call(t))
		for bone in tr:
			for kind in tr[bone]:
				var key: String = bone + ":" + kind
				if not tracks.has(key):
					var type: int = {"rot": Animation.TYPE_ROTATION_3D, "pos": Animation.TYPE_POSITION_3D, "scale": Animation.TYPE_SCALE_3D}[kind]
					var ti := anim.add_track(type)
					anim.track_set_path(ti, "Skeleton3D:" + bone)
					anim.track_set_interpolation_type(ti, Animation.INTERPOLATION_LINEAR)
					tracks[key] = ti
				var ti2: int = tracks[key]
				match kind:
					"rot": anim.rotation_track_insert_key(ti2, t, tr[bone][kind])
					"pos": anim.position_track_insert_key(ti2, t, tr[bone][kind])
					"scale": anim.scale_track_insert_key(ti2, t, tr[bone][kind])
	return [name, anim]

static func ease_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

static func seg(t: float, a: float, b: float) -> float:
	return ease_io((t - a) / maxf(b - a, 1e-4))

func make_clips() -> Array:
	var clips := []
	var M := s   # 1 source unit -> metres

	# IDLE 1.6 s: weight shifts side to side, cap sways a beat behind, breathing
	clips.append(bake("idle", 1.6, true, func(t: float):
		var p: float = TAU * t / 1.6
		return {
			"hips_pos": Vector3(0.012 * sin(p), -0.006 + 0.004 * sin(p * 2.0), 0),
			"hips_rot": Vector3(0, 0, 3.0 * sin(p)),
			"body_rot": Vector3(-2.0, 0, -3.0 * sin(p - 0.5)),
			"cap_rot": Vector3(2.0 * sin(p * 2.0 + 0.6), 4.0 * sin(p * 0.5), -4.0 * sin(p - 1.0)),
			"body_scale": Vector3(1.0 + 0.02 * sin(p * 2.0), 1.0 - 0.025 * sin(p * 2.0), 1.0 + 0.02 * sin(p * 2.0)),
			"pitch_l": 0.0, "pitch_r": 0.0}))

	# RUN 0.36 s per two steps: ankles trace a loop (plant -> push back ->
	# lift -> swing forward); body leans in, bounces twice; cap lags behind.
	var stride := 0.30 * M     # half-stride reach either side of the hip
	var lift := 0.13 * M
	var foot_path := func(ph: float, side: String) -> Dictionary:
		# ph 0..1: 0-0.5 stance (moves back on the ground), 0.5-1 swing (lifted, forward)
		var base: Vector3 = stance(side)
		var z: float
		var y: float = base.y
		var pitch := 0.0
		if ph < 0.5:
			var k := ph / 0.5
			z = lerpf(-stride, stride, k)        # forward (-Z) to back (+Z)
			pitch = lerpf(0.0, -25.0, maxf(0.0, (k - 0.6) / 0.4))  # toe-off
		else:
			var k := (ph - 0.5) / 0.5
			z = lerpf(stride, -stride, ease_io(k))
			y += lift * sin(PI * k)
			pitch = lerpf(-25.0, 15.0, k)        # toe up before heel strike
		return {"p": Vector3(base.x, y, z), "pitch": pitch}
	clips.append(bake("run", 0.36, true, func(t: float):
		var ph: float = t / 0.36
		var fl: Dictionary = foot_path.call(fposmod(ph, 1.0), "l")
		var fr: Dictionary = foot_path.call(fposmod(ph + 0.5, 1.0), "r")
		var bounce := absf(sin(TAU * ph))
		return {
			"hips_pos": Vector3(0, -0.03 * M + 0.035 * M * bounce, 0),
			"hips_rot": Vector3(-14.0, 6.0 * sin(TAU * ph), 4.0 * sin(TAU * ph)),
			"body_rot": Vector3(-6.0, 0, -3.0 * sin(TAU * ph - 0.6)),
			"cap_rot": Vector3(8.0 - 4.0 * bounce, 0, -5.0 * sin(TAU * ph - 1.2)),
			"body_scale": Vector3(1.0 + 0.04 * (1.0 - bounce), 1.0 - 0.05 * (1.0 - bounce), 1.0 + 0.04 * (1.0 - bounce)),
			"ankle_l": fl["p"], "pitch_l": fl["pitch"],
			"ankle_r": fr["p"], "pitch_r": fr["pitch"]}))

	# RAM 0.9 s (one board): crouch, spring forward-up, cap smashes the board
	# at 0.42 s, rebound, land. Root motion is in the clip (forward and back).
	clips.append(bake("ram", 0.9, true, func(t: float):
		var crouch := seg(t, 0.0, 0.22) * (1.0 - seg(t, 0.22, 0.32))
		var air := seg(t, 0.24, 0.42) * (1.0 - seg(t, 0.46, 0.7))
		var land := seg(t, 0.68, 0.76) * (1.0 - seg(t, 0.76, 0.9))
		var hit := seg(t, 0.40, 0.44) * (1.0 - seg(t, 0.44, 0.56))
		var up := 0.42 * M * air
		var fwd := -0.22 * M * air
		var tuck := air
		return {
			"root_pos": Vector3(0, up, fwd),
			"root_rot": Vector3(-28.0 * air + 10.0 * crouch, 0, 0),
			"hips_pos": Vector3(0, -0.08 * M * crouch - 0.05 * M * land, 0),
			"body_scale": Vector3(1.0 + 0.12 * crouch + 0.1 * land, 1.0 - 0.14 * crouch - 0.12 * land + 0.08 * tuck, 1.0 + 0.12 * crouch + 0.1 * land),
			"cap_scale": Vector3(1.0 + 0.1 * hit, 1.0 - 0.22 * hit, 1.0 + 0.1 * hit),
			"cap_rot": Vector3(-12.0 * crouch + 18.0 * hit, 0, 0),
			"ankle_l": stance("l") + Vector3(0, 0.12 * M * tuck, 0.1 * M * tuck),
			"ankle_r": stance("r") + Vector3(0, 0.12 * M * tuck, 0.1 * M * tuck),
			"pitch_l": -30.0 * tuck, "pitch_r": -30.0 * tuck}))

	# DIVE 0.8 s: through the gap in the boards. Code moves the body; the clip
	# squashes the cap flat, tucks the boots and pitches forward.
	clips.append(bake("dive", 0.8, false, func(t: float):
		var crouch := seg(t, 0.0, 0.15) * (1.0 - seg(t, 0.15, 0.22))
		var tuck := seg(t, 0.15, 0.3) * (1.0 - seg(t, 0.55, 0.7))
		var land := seg(t, 0.66, 0.72) * (1.0 - seg(t, 0.72, 0.8))
		return {
			"root_rot": Vector3(-35.0 * tuck, 0, 0),
			"hips_pos": Vector3(0, -0.07 * M * (crouch + land), 0),
			"body_scale": Vector3(1.0 + 0.1 * crouch, 1.0 - 0.25 * tuck - 0.12 * crouch, 1.0 + 0.1 * crouch),
			"cap_scale": Vector3(1.0 - 0.1 * tuck, 1.0 - 0.45 * tuck, 1.0 + 0.08 * tuck),
			"ankle_l": stance("l") + Vector3(0.04 * M * tuck, 0.16 * M * tuck, 0.18 * M * tuck),
			"ankle_r": stance("r") + Vector3(-0.04 * M * tuck, 0.16 * M * tuck, 0.18 * M * tuck),
			"pitch_l": -40.0 * tuck, "pitch_r": -40.0 * tuck}))

	# KICK 0.75 s: hop at you and dropkick with both boots, hit at 0.3 s.
	clips.append(bake("kick", 0.75, false, func(t: float):
		var crouch := seg(t, 0.0, 0.12) * (1.0 - seg(t, 0.12, 0.18))
		var air := seg(t, 0.14, 0.28) * (1.0 - seg(t, 0.4, 0.58))
		var ext := seg(t, 0.2, 0.3) * (1.0 - seg(t, 0.38, 0.5))
		var land := seg(t, 0.56, 0.62) * (1.0 - seg(t, 0.62, 0.75))
		return {
			"root_pos": Vector3(0, 0.2 * M * air, 0),
			"root_rot": Vector3(28.0 * ext, 0, 0),
			"hips_pos": Vector3(0, -0.07 * M * (crouch + land), 0),
			"body_scale": Vector3(1.0 + 0.1 * (crouch + land), 1.0 - 0.12 * (crouch + land), 1.0 + 0.1 * (crouch + land)),
			"cap_rot": Vector3(-14.0 * ext, 0, 0),
			"ankle_l": stance("l") + Vector3(0.04 * M, 0.1 * M * air, -0.24 * M * ext),
			"ankle_r": stance("r") + Vector3(-0.04 * M, 0.1 * M * air, -0.24 * M * ext),
			"pitch_l": 35.0 * ext, "pitch_r": 35.0 * ext}))

	# FLINCH 0.35 s: knocked back, cap squashes, boots stagger
	clips.append(bake("flinch", 0.35, false, func(t: float):
		var k := seg(t, 0.0, 0.06) * (1.0 - seg(t, 0.06, 0.35))
		return {
			"hips_rot": Vector3(16.0 * k, 0, 6.0 * k),
			"body_rot": Vector3(10.0 * k, 0, 0),
			"cap_rot": Vector3(14.0 * k, 0, -8.0 * k),
			"cap_scale": Vector3(1.0 + 0.12 * k, 1.0 - 0.18 * k, 1.0 + 0.12 * k),
			"ankle_r": stance("r") + Vector3(0, 0.06 * M * k, 0.06 * M * k),
			"pitch_r": -15.0 * k}))

	# DEATH 1.3 s: legs buckle, it keels over sideways onto its cap, boots kick
	# twice and go still.
	clips.append(bake("death", 1.3, false, func(t: float):
		var buckle := seg(t, 0.0, 0.25)
		var fall := seg(t, 0.2, 0.62)
		var kick1 := seg(t, 0.62, 0.72) * (1.0 - seg(t, 0.72, 0.84))
		var kick2 := seg(t, 0.86, 0.94) * (1.0 - seg(t, 0.94, 1.1)) * 0.6
		var kk := kick1 + kick2
		return {
			"root_rot": Vector3(-10.0 * fall, 0, 96.0 * fall),
			"root_pos": Vector3(-0.2 * M * fall, 0.2 * M * fall - 0.06 * M * buckle * (1.0 - fall), 0),
			"hips_pos": Vector3(0, -0.06 * M * buckle * (1.0 - fall), 0),
			"cap_rot": Vector3(0, 0, -10.0 * fall),
			"cap_scale": Vector3(1.0 + 0.08 * buckle * (1.0 - fall), 1.0 - 0.12 * buckle * (1.0 - fall), 1.0),
			"ankle_l": stance("l") + Vector3(0.05 * M * fall, (0.08 + 0.14 * kk) * M * fall, -0.12 * M * kk),
			"ankle_r": stance("r") + Vector3(-0.05 * M * fall, (0.05 + 0.1 * kk) * M * fall, 0.1 * M * kk),
			"pitch_l": 20.0 * fall, "pitch_r": -10.0 * fall}))
	return clips
