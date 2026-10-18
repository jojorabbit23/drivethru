# Turns the static knife GLB into a first-person weapon model.
#
#   godot --headless --path . --script res://tools/build_knife.gd
#   godot --headless --path . --import          # first run only (new albedo PNG)
#   godot --headless --path . --script res://tools/build_knife.gd
#
# The source lies diagonally at an arbitrary scale, so the script works out
# the knife's own axes from its shape:
#   length axis  principal axis of the vertices
#   tip end      the end whose cross-section is thinnest (blade vs handle)
#   spine side   the thicker long edge of the blade (the edge is ground thin)
# then rescales it to LENGTH metres with these axes:
#   -Z = toward the tip, +Y = spine (serrated back), +X = right flat
# and the origin on the grip, where a hand would hold it.
# Output: res://weapons/knife/knife_model.tscn (+ mesh, material, albedo)
extends SceneTree

const SRC := "res://weapons/knife/source/knife_3d_model.glb"
const OUT := "res://weapons/knife/"
const LENGTH := 0.32        # a big survival knife, tip to pommel
const GRIP_AT := 0.16       # grip centre, as a fraction of length from the pommel
const TEX_SIZE := 512

func _initialize() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path(SRC), st) == OK)
	var albedo_path := OUT + "knife_albedo.png"
	if not FileAccess.file_exists(albedo_path):
		var img: Image = st.get_images()[0].get_image()
		img.decompress()
		img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(albedo_path))
		print("wrote ", albedo_path, " — run --import, then this script again")
		quit()
		return
	var arr := (st.get_meshes()[0] as GLTFMesh).mesh.get_surface_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]

	# --- principal axes ---------------------------------------------------
	var mean := Vector3.ZERO
	for p in v:
		mean += p
	mean /= v.size()
	var cov := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for p in v:
		var d := p - mean
		for i in 3:
			for j in 3:
				cov[i][j] += d[i] * d[j]
	var axes := []
	var deflated := cov.duplicate(true)
	for k in 3:
		var e := Vector3(0.3, 0.7, 0.2).normalized()
		for it in 100:
			var ne := Vector3(
				deflated[0][0] * e.x + deflated[0][1] * e.y + deflated[0][2] * e.z,
				deflated[1][0] * e.x + deflated[1][1] * e.y + deflated[1][2] * e.z,
				deflated[2][0] * e.x + deflated[2][1] * e.y + deflated[2][2] * e.z)
			for a in axes:
				ne -= a * ne.dot(a)
			if ne.length() < 1e-12:
				break
			e = ne.normalized()
		var lam := 0.0
		for i in 3:
			for j in 3:
				lam += e[i] * deflated[i][j] * e[j]
		for i in 3:
			for j in 3:
				deflated[i][j] -= lam * e[i] * e[j]
		axes.append(e)
	var L: Vector3 = axes[0]   # length
	var W: Vector3 = axes[1]   # blade width (spine <-> edge)
	var T: Vector3 = axes[2]   # thickness (flat normal)

	# --- which end is the tip? thickness profile along the length ---------
	var lmin := INF
	var lmax := -INF
	for p in v:
		var l := (p - mean).dot(L)
		lmin = minf(lmin, l)
		lmax = maxf(lmax, l)
	var bins := 20
	var tmin := []
	var tmax := []
	for b in bins:
		tmin.append(INF)
		tmax.append(-INF)
	for p in v:
		var d := p - mean
		var b := clampi(int((d.dot(L) - lmin) / (lmax - lmin) * bins), 0, bins - 1)
		tmin[b] = minf(tmin[b], d.dot(T))
		tmax[b] = maxf(tmax[b], d.dot(T))
	var thick_lo := 0.0
	var thick_hi := 0.0
	for b in 6:
		thick_lo += tmax[b] - tmin[b]
		thick_hi += tmax[bins - 1 - b] - tmin[bins - 1 - b]
	if thick_hi < thick_lo:
		pass        # tip is at +L already
	else:
		L = -L      # flip so +L points at the tip
		var t := lmin
		lmin = -lmax
		lmax = -t
	print("thickness near ends: %.4f vs %.4f -> tip found" % [thick_lo, thick_hi])

	# --- which long edge is the spine? the thicker one, along the blade ----
	# measure each edge's own thickness (spread across the flat) mid-blade
	var sp_lo := INF
	var sp_hi := -INF
	var ed_lo := INF
	var ed_hi := -INF
	var wmin := INF
	var wmax := -INF
	for p in v:
		var d := p - mean
		var u := (d.dot(L) - lmin) / (lmax - lmin)
		if u > 0.55 and u < 0.85:
			wmin = minf(wmin, d.dot(W))
			wmax = maxf(wmax, d.dot(W))
	for p in v:
		var d := p - mean
		var u := (d.dot(L) - lmin) / (lmax - lmin)
		if u < 0.55 or u > 0.85:
			continue
		var w := (d.dot(W) - wmin) / maxf(wmax - wmin, 1e-6)
		if w > 0.85:
			sp_lo = minf(sp_lo, d.dot(T))
			sp_hi = maxf(sp_hi, d.dot(T))
		elif w < 0.15:
			ed_lo = minf(ed_lo, d.dot(T))
			ed_hi = maxf(ed_hi, d.dot(T))
	print("edge thickness: +W side %.4f, -W side %.4f" % [sp_hi - sp_lo, ed_hi - ed_lo])
	if sp_hi - sp_lo < ed_hi - ed_lo:
		W = -W
	T = L.cross(W).normalized()  # keep a right-handed frame
	# final frame: X = T(flat), Y = W(spine), Z = -L(back toward pommel)
	var X := T
	var Y := W
	var Z := -L
	if X.cross(Y).dot(Z) < 0.0:
		X = -X
	var scale := LENGTH / (lmax - lmin)
	# grip centre: GRIP_AT along from the pommel, centred on the handle section
	var gl := lmin + (lmax - lmin) * GRIP_AT
	var gsum := Vector3.ZERO
	var gn := 0
	for p in v:
		var d := p - mean
		if absf(d.dot(L) - gl) < (lmax - lmin) * 0.04:
			gsum += d
			gn += 1
	var grip := mean + gsum / maxf(gn, 1)
	print("source length %.3f -> scale %.4f; %d grip samples" % [lmax - lmin, scale, gn])

	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	nv.resize(v.size())
	nn.resize(v.size())
	for i in v.size():
		var d := v[i] - grip
		nv[i] = Vector3(d.dot(X), d.dot(Y), d.dot(Z)) * scale
		nn[i] = Vector3(nrm[i].dot(X), nrm[i].dot(Y), nrm[i].dot(Z))
	arr[Mesh.ARRAY_VERTEX] = nv
	arr[Mesh.ARRAY_NORMAL] = nn
	arr[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var aabb := mesh.get_aabb()
	print("knife bounds (m): ", aabb)

	# Viewmodel material: the knife is drawn shrunk toward the eye (same place
	# on screen, a tenth of the depth), so it never sinks into walls or zombies
	# you're pressed against. Works in Forward+, Mobile and Compatibility.
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_back, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap;
uniform float viewmodel = 1.0;   // 0 = draw normally (world pickups)
void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_pos.xyz *= mix(1.0, 0.1, viewmodel);
	POSITION = PROJECTION_MATRIX * view_pos;
}
void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb;
	ROUGHNESS = 0.55;
	METALLIC = 0.0;
	SPECULAR = 0.45;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo_tex", load(albedo_path))
	ResourceSaver.save(mat, OUT + "knife_material.tres")
	mat.take_over_path(OUT + "knife_material.tres")
	mesh.surface_set_material(0, mat)
	ResourceSaver.save(mesh, OUT + "knife_mesh.res")
	mesh.take_over_path(OUT + "knife_mesh.res")

	var root := Node3D.new()
	root.name = "KnifeModel"
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.owner = root
	# Tip marker: where the point is, for hit traces and effects.
	var tip := Marker3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0, 0, aabb.position.z)
	root.add_child(tip)
	tip.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	print("saved ", OUT + "knife_model.tscn", " err=", ResourceSaver.save(ps, OUT + "knife_model.tscn"))
	root.free()
	quit()
