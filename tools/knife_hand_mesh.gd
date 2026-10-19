# Derives Cleatimus's right knife hand from the supplied sculpt
# (weapons/knife/source/reference_hand_with_dagger.glb, left untouched).
#
# The sculpt is ONE closed mesh: sleeve, cuff, gloved fist and a dagger pushed
# through the fist, all fused. This script:
#   1. classifies every triangle by the colour its UVs land on in the sculpt's
#      own base-colour texture (orange sleeve, brown cuff, teal dagger handle,
#      skin, dark glove / blade) and by where it sits along the dagger;
#   2. separates the dagger: everything beyond the guard (blade, guard, orange
#      ring) and the teal handle surface near the handle axis (the neck above
#      the fist, the strip between the fingers, the pommel below);
#   3. moves the fist into OUR knife's space: the sculpt's handle axis becomes
#      the knife's -Z axis, the side of the hand facing the camera in the
#      sculpt's own front view faces the camera at idle, and the finger stack
#      spans our handle between guard and pommel;
#   4. opens the grip channel so the fingers wrap our (thicker) handle exactly:
#      the finger layer between the old handle and the outside of the fist is
#      remapped onto [our handle surface, outside], which keeps the outer
#      silhouette and never turns a finger inside out;
#   5. lengthens the sleeve along the forearm so it runs off-screen.
# The viewmodel builder then skins the result to hand_r / lowerarm_r.
extends RefCounted

const SRC := "res://weapons/knife/source/reference_hand_with_dagger.glb"

# --- fit (knife space: metres, tip toward -Z, spine +Y, origin = grip) ----
const AXIAL_SCALE := 0.235          # sculpt units -> m along the handle (finger stack ~9.4 cm)
const RADIAL_SCALE := 0.30          # sculpt units -> m across the handle
const FIST_TOP_Z := -0.0435         # top of the index finger; our guard's lower face is at -0.048
const GRIP_MARGIN := 0.0012         # glove surface sits this far off the handle
const CHANNEL_OUTER := 2.1          # remap the finger layer out to this many handle radii
const ROLL_TWEAK_DEG := 0.0         # extra turn of the hand about the knife axis
const SLEEVE_REACH := 0.34          # m from the wrist to the far end of the sleeve
const SKIN_AS_GLOVE := true         # reference shows fully gloved fingers
const SLEEVE_UV_REPEAT := 0.64      # m of sleeve per UV unit (the shader tiles the fabric 16x per unit)

# Colour prototypes measured from the sculpt texture (k-means, sRGB 0..255).
const PROTOS := [
	[Color8(199, 59, 13), "orange"], [Color8(58, 49, 42), "brown"],
	[Color8(28, 69, 81), "teal"], [Color8(163, 133, 103), "skin"],
	[Color8(43, 48, 51), "dark"], [Color8(37, 40, 41), "dark"],
	[Color8(63, 62, 64), "dark"], [Color8(92, 90, 91), "dark"],
]

# Region ids understood by arms_viewmodel.gdshader (UV2.x).
const SLEEVE := 0
const CUFF := 1
const GLOVE := 2
const SKIN := 3
const NATIVE := 4      # vertex colour is the albedo (the sculpt's own dagger)

# --- alternative: keep the sculpt's dagger ---------------------------------
const DAGGER_SCALE := 0.29          # sculpt units -> m, uniform (dagger ~26 cm)
const DAGGER_GRIP_SH := -0.19       # fist centre along the handle axis, below the neck (sculpt units)
const POMMEL_FROM := -0.22          # handle below here (past the little finger) is the pommel
const POMMEL_KEEP := 0.12            # keep this much of the pommel's length

static func _load() -> Dictionary:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(SRC), st)
	assert(err == OK, "cannot read " + SRC)
	var arr := (st.get_meshes()[0] as GLTFMesh).mesh.get_surface_arrays(0)
	var img: Image = null
	for i in st.get_images().size():
		var name: String = st.json["images"][i].get("name", "")
		if name.ends_with("_basecolor.jpg"):
			img = (st.get_images()[i] as Texture2D).get_image()
	assert(img != null, "sculpt base colour texture not found")
	img.decompress()
	return {"v": arr[Mesh.ARRAY_VERTEX], "n": arr[Mesh.ARRAY_NORMAL], "uv": arr[Mesh.ARRAY_TEX_UV], "i": arr[Mesh.ARRAY_INDEX], "img": img}

static func _sample(img: Image, uv: Vector2) -> Color:
	var x := clampi(int(fposmod(uv.x, 1.0) * img.get_width()), 0, img.get_width() - 1)
	var y := clampi(int(fposmod(uv.y, 1.0) * img.get_height()), 0, img.get_height() - 1)
	return img.get_pixel(x, y)

static func _classify(c: Color) -> String:
	var best := ""
	var bd := INF
	for p in PROTOS:
		var pc: Color = p[0]
		var d := Vector3(c.r - pc.r, c.g - pc.g, c.b - pc.b).length_squared()
		if d < bd:
			bd = d
			best = p[1]
	return best

static func _principal_axis(pts: PackedVector3Array) -> Array:
	var mean := Vector3.ZERO
	for p in pts:
		mean += p
	mean /= pts.size()
	var cov := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	for p in pts:
		var d := p - mean
		cov.x += d * d.x
		cov.y += d * d.y
		cov.z += d * d.z
	var e := Vector3(0.1, 1.0, 0.1).normalized()
	for it in 60:
		e = (cov * e).normalized()
	return [mean, e]

static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

# face_dir: the camera's +Z (toward the viewer) expressed in knife space at the
# idle pose. handle: [centre Vector2, Array of [z, half_x, half_y]] from the
# knife mesh. Returns per-corner (unwelded) arrays plus fit data, in knife space.
# bend_to: forearm direction (knife space) the sleeve should already point along
# at idle; the wrist is pre-bent to it here so the skeleton only adds small bends.
# keep_dagger: the alternative build. The sculpt's own dagger stays in its
# hand (the fingers were sculpted round it, so no channel fitting is needed);
# the straightened handle axis becomes the weapon's -Z, scaled uniformly by DAGGER_SCALE, and
# the dagger keeps the sculpt's own colours (region NATIVE).
static func build(face_dir: Vector3, handle: Array, bend_to: Vector3 = Vector3.ZERO, keep_dagger := false) -> Dictionary:
	var src := _load()
	var v: PackedVector3Array = src["v"]
	var nrm: PackedVector3Array = src["n"]
	var uv: PackedVector2Array = src["uv"]
	var idx: PackedInt32Array = src["i"]
	var img: Image = src["img"]
	var tri_count := idx.size() / 3

	# 1. per-triangle centre and colour class
	var cent := PackedVector3Array()
	var cls: Array[String] = []
	cent.resize(tri_count)
	for t in tri_count:
		var a := idx[t * 3]
		var b := idx[t * 3 + 1]
		var c := idx[t * 3 + 2]
		cent[t] = (v[a] + v[b] + v[c]) / 3.0
		cls.append(_classify(_sample(img, (uv[a] + uv[b] + uv[c]) / 3.0)))

	# blade axis from the blade tip region; s = position along the dagger
	var tip_pts := PackedVector3Array()
	for p in v:
		if p.y > 0.62:
			tip_pts.append(p)
	var pa := _principal_axis(tip_pts)
	var c0: Vector3 = pa[0]
	var blade: Vector3 = pa[1]
	if blade.y < 0.0:
		blade = -blade
	# handle axis: neck (teal just under the guard) to pommel (teal under the pinky)
	var neck := Vector3.ZERO
	var pommel := Vector3.ZERO
	var nn := 0
	var np := 0
	for t in tri_count:
		if cls[t] != "teal":
			continue
		var s := (cent[t] - c0).dot(blade)
		if s > -0.32 and s <= -0.27:
			neck += cent[t]
			nn += 1
		elif s > -0.68 and s <= -0.56:
			pommel += cent[t]
			np += 1
	assert(nn > 20 and np > 20, "dagger handle not found where expected")
	neck /= nn
	pommel /= np
	var axis := (neck - pommel).normalized()
	print("  sculpt: blade ", blade, " handle axis ", axis, " neck ", neck, " pommel ", pommel)

	# 2. separate the dagger
	var keep := PackedByteArray()
	keep.resize(tri_count)
	var is_dagger := PackedByteArray()
	is_dagger.resize(tri_count)
	var removed := 0
	for t in tri_count:
		var s := (cent[t] - c0).dot(blade)
		var sh := (cent[t] - neck).dot(axis)
		var r := (cent[t] - neck - axis * sh).length()
		var dagger := s > -0.27                                           # blade, guard
		dagger = dagger or (cls[t] == "orange" and s > -0.33 and r < 0.07)   # orange ring
		dagger = dagger or (cls[t] == "teal" and r < 0.075 and sh > -0.47)   # handle surface
		is_dagger[t] = 1 if dagger else 0
		keep[t] = 0 if dagger and not keep_dagger else 1
		if keep[t] == 0:
			removed += 1

	# wrist and forearm in the sculpt: the sleeve's cut end faces the elbow
	var cap_n := Vector3.ZERO
	var wrist := Vector3.ZERO
	var nw := 0
	for t in tri_count:
		var fnorm := (nrm[idx[t * 3]] + nrm[idx[t * 3 + 1]] + nrm[idx[t * 3 + 2]]).normalized()
		if fnorm.y < -0.8 and cent[t].y < 0.06:
			cap_n += fnorm
		if cls[t] == "brown" and cent[t].y > 0.22 and (cent[t] - c0).dot(blade) < -0.55:
			wrist += cent[t]
			nw += 1
	assert(cap_n.length() > 0.0 and nw > 10, "sleeve end or cuff top not found")
	var forearm := cap_n.normalized()     # points from the wrist toward the elbow
	wrist /= maxi(nw, 1)
	print("  sculpt: wrist ", wrist, " forearm ", forearm, " face_dir ", face_dir)

	# 3. sculpt frame -> knife frame
	# dagger mode: straighten and shorten the sculpt's handle first. Its blade
	# sits 22° off the handle (it reads bent) and the pommel pokes well below the
	# fist. The blade, guard and neck are turned about the neck onto the handle
	# line (fading in over the neck, so the fist top doesn't move), and the
	# pommel's own vertices are pulled up toward the bottom of the fist.
	var straightened := 0
	var shortened := 0
	if keep_dagger:
		var only_dagger := {}
		for t in tri_count:
			for j in 3:
				var i := idx[t * 3 + j]
				only_dagger[i] = (only_dagger.get(i, true) as bool) and is_dagger[t] == 1
		var turn_axis := blade.cross(axis).normalized()
		var turn := blade.angle_to(axis)
		for i in v.size():
			var sh := (v[i] - neck).dot(axis)
			if sh > -0.02:
				var w := smoothstep(-0.02, 0.04, sh)
				var rot := Basis(turn_axis, turn * w)
				v[i] = neck + rot * (v[i] - neck)
				nrm[i] = rot * nrm[i]
				straightened += 1
			elif sh < POMMEL_FROM and only_dagger.get(i, false):
				v[i] += axis * (POMMEL_FROM - sh) * (1.0 - POMMEL_KEEP)
				shortened += 1
		print("  dagger: handle straightened (%.1f deg, %d verts), pommel pulled in (%d verts)" % [rad_to_deg(turn), straightened, shortened])
	var grip_axis := axis
	var pivot := neck + axis * DAGGER_GRIP_SH if keep_dagger else neck
	var s_face := (Vector3(0, 0, 1) - grip_axis * grip_axis.z).normalized()
	var s_side := grip_axis.cross(s_face)
	var k_axis := Vector3(0, 0, -1)
	var k_face := face_dir.slide(k_axis).normalized().rotated(k_axis, deg_to_rad(ROLL_TWEAK_DEG))
	var k_side := k_axis.cross(k_face)
	var to_frame := Basis(s_side, grip_axis, s_face).inverse()     # sculpt -> (side, axis, face) coords
	var from_frame := Basis(k_side, k_axis, k_face)           # (side, axis, face) coords -> knife
	var scale := Basis.from_scale(Vector3(RADIAL_SCALE, AXIAL_SCALE, RADIAL_SCALE))
	if keep_dagger:
		scale = Basis.from_scale(Vector3.ONE * DAGGER_SCALE)
	var lin := from_frame * scale * to_frame
	var hc: Vector2 = handle[0] if not keep_dagger else Vector2.ZERO
	var origin := Vector3(hc.x, hc.y, FIST_TOP_Z) if not keep_dagger else Vector3.ZERO
	var normal_m := lin.inverse().transposed()
	var kv := PackedVector3Array()
	var kn := PackedVector3Array()
	kv.resize(v.size())
	kn.resize(v.size())
	for i in v.size():
		kv[i] = lin * (v[i] - pivot) + origin
		kn[i] = (normal_m * nrm[i]).normalized()
	var k_wrist := lin * (wrist - pivot) + origin
	var k_forearm := (lin * forearm).normalized()

	# 4. open the grip channel around our handle
	var used := {}
	for t in tri_count:
		if keep[t] == 1:
			for j in 3:
				used[idx[t * 3 + j]] = true
	var profile: Array = handle[1] if not keep_dagger else []
	var opened := 0
	for i in (used if not keep_dagger else {}):
		var p := kv[i]
		var half := _handle_half(profile, p.z)
		if half == Vector2.ZERO:
			continue
		var rx := half.x + GRIP_MARGIN
		var ry := half.y + GRIP_MARGIN
		var d := Vector2(p.x - hc.x, p.y - hc.y)
		var e := sqrt(pow(d.x / rx, 2.0) + pow(d.y / ry, 2.0))
		if e >= CHANNEL_OUTER or e < 1e-5:
			continue
		var e_min := 0.15
		var ne := 1.0 + (maxf(e, e_min) - e_min) * (CHANNEL_OUTER - 1.0) / (CHANNEL_OUTER - e_min)
		if ne <= e:
			continue
		# fade the opening out over the last few mm past either end of the handle
		var fade := _handle_fade(profile, p.z)
		var k := lerpf(1.0, ne / e, fade)
		kv[i] = Vector3(hc.x + d.x * k, hc.y + d.y * k, p.z)
		opened += 1

	# 5. lengthen the sleeve toward the elbow
	var far := 0.0
	var cuff_end := 0.0
	for t in tri_count:
		if keep[t] == 0:
			continue
		for j in 3:
			var a := (kv[idx[t * 3 + j]] - k_wrist).dot(k_forearm)
			far = maxf(far, a)
			if cls[t] == "brown":
				cuff_end = maxf(cuff_end, a)
	var sleeve_start := cuff_end   # the cuff keeps its shape; only the sleeve past it lengthens
	var stretch := (SLEEVE_REACH - sleeve_start) / maxf(far - sleeve_start, 0.001)
	for i in used:
		var a := (kv[i] - k_wrist).dot(k_forearm)
		if a > sleeve_start:
			kv[i] += k_forearm * (a - sleeve_start) * (stretch - 1.0)

	# 5b. pre-bend the wrist: rotate the sleeve about the wrist toward bend_to,
	# spreading the turn across the cuff like a bent tube
	var pre_bend := 0.0
	if bend_to != Vector3.ZERO:
		var to := bend_to.normalized()
		pre_bend = k_forearm.angle_to(to)
		var bend_axis := k_forearm.cross(to).normalized()
		if pre_bend > 0.001:
			var turned := {}
			for t in tri_count:
				if keep[t] == 0:
					continue
				for j in 3:
					var i := idx[t * 3 + j]
					if turned.has(i):
						continue
					turned[i] = true
					var a := (kv[i] - k_wrist).dot(k_forearm)
					var w := smoothstep(-0.004, cuff_end, a)
					if w <= 0.0:
						continue
					var rot := Basis(bend_axis, pre_bend * w)
					kv[i] = k_wrist + rot * (kv[i] - k_wrist)
					kn[i] = (rot * kn[i]).normalized()
			k_forearm = to

	# 6. per-corner output with region ids and painted shading as vertex colour
	var proto_lum := {}
	for p in PROTOS:
		if not proto_lum.has(p[1]):
			proto_lum[p[1]] = _lum(p[0])
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_uv2 := PackedVector2Array()
	var out_c := PackedColorArray()
	# the lengthened sleeve gets cylindrical UVs (so the fabric isn't smeared
	# along it) and round normals (so the stretched end cap shades smoothly)
	var ring_x := k_forearm.cross(Vector3.UP if absf(k_forearm.y) < 0.9 else Vector3.RIGHT).normalized()
	var ring_y := k_forearm.cross(ring_x)
	for t in tri_count:
		if keep[t] == 0:
			continue
		var s := (cent[t] - c0).dot(blade)
		var kind := GLOVE
		if keep_dagger and is_dagger[t] == 1 and (cent[t] - neck).dot(axis) > -0.03:
			kind = NATIVE   # blade, guard and the neck above the fist
		elif keep_dagger and is_dagger[t] == 1:
			kind = GLOVE    # handle inside / under the fist: reads as glove, so the grip looks short
		elif cls[t] == "orange" and s < -0.6:
			kind = SLEEVE
		elif cls[t] == "brown" and s < -0.5:
			kind = CUFF
		elif cls[t] == "skin" and not SKIN_AS_GLOVE:
			kind = SKIN
		var first_angle := 0.0
		for j in 3:
			var i := idx[t * 3 + j]
			out_v.append(kv[i])
			var rel := kv[i] - k_wrist
			var along := rel.dot(k_forearm)
			if kind == SLEEVE and along > cuff_end:
				var radial := rel - k_forearm * along
				var angle := atan2(radial.dot(ring_y), radial.dot(ring_x))
				if j == 0:
					first_angle = angle
				angle = first_angle + wrapf(angle - first_angle, -PI, PI)   # no wrap across a triangle
				var blend := clampf((along - cuff_end) / 0.02, 0.0, 1.0)
				out_n.append(kn[i].lerp(radial.normalized(), blend).normalized())
				out_uv.append(Vector2(angle * 0.035, along) / SLEEVE_UV_REPEAT)
			else:
				out_n.append(kn[i])
				out_uv.append(uv[i])
			out_uv2.append(Vector2(kind, 0))
			var c := _sample(img, uv[i])
			if kind == NATIVE:
				out_c.append(Color(c.r, c.g, c.b).srgb_to_linear())   # the dagger keeps its painted colours
				continue
			var ref: float = proto_lum[cls[t]] if proto_lum.has(cls[t]) else 0.2
			var shade := clampf(_lum(c) / maxf(ref, 0.02), 0.6, 1.3)
			out_c.append(Color(shade, shade, shade))
	return {
		"vertices": out_v, "normals": out_n, "uv": out_uv, "uv2": out_uv2, "colors": out_c,
		"wrist": k_wrist, "forearm": k_forearm, "cuff_end": cuff_end,
		"removed": removed, "kept": tri_count - removed, "opened": opened, "stretch": stretch,
		"pre_bend": rad_to_deg(pre_bend),
	}

# Half-size of our handle cross-section at depth z (zero outside the handle).
static func _handle_half(profile: Array, z: float) -> Vector2:
	var first: Array = profile[0]
	var last: Array = profile[-1]
	if z < first[0] - 0.004 or z > last[0] + 0.004:
		return Vector2.ZERO
	var best: Array = profile[0]
	for row in profile:
		if absf(row[0] - z) < absf(best[0] - z):
			best = row
	return Vector2(best[1], best[2])

static func _handle_fade(profile: Array, z: float) -> float:
	var first: Array = profile[0]
	var last: Array = profile[-1]
	return clampf(1.0 - maxf(first[0] - z, z - last[0]) / 0.004, 0.0, 1.0)
