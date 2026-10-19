# Makes a mesh a little blockier, to match the voxel Shambler: fewer triangles
# (meshoptimizer simplification via ImporterMesh LODs) and flat, faceted
# shading. Used by build_knife.gd and build_knife_viewmodel.gd.
#   arrays = BlockyMesh.weld(arrays)            # per-corner -> indexed
#   arrays = BlockyMesh.simplify(arrays, 0.5)   # keep about half the triangles
#   arrays = BlockyMesh.flat(arrays)            # one normal per face
extends RefCounted

const PER_VERTEX := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]

static func triangle_count(arrays: Array) -> int:
	var idx: Variant = arrays[Mesh.ARRAY_INDEX]
	if idx != null:
		return (idx as PackedInt32Array).size() / 3
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3

# Merges corners that share every attribute, so the simplifier sees one surface.
static func weld(arrays: Array) -> Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var keys := {}
	var remap := PackedInt32Array()
	var first := PackedInt32Array()
	remap.resize(v.size())
	for i in v.size():
		var key := [Vector3i(roundi(v[i].x * 1e5), roundi(v[i].y * 1e5), roundi(v[i].z * 1e5))]
		for a in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR, Mesh.ARRAY_NORMAL]:
			if arrays[a] != null:
				key.append(arrays[a][i])
		for a in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			if arrays[a] != null:
				key.append(arrays[a].slice(i * 4, i * 4 + 4))
		var h := str(key)
		if not keys.has(h):
			keys[h] = first.size()
			first.append(i)
		remap[i] = keys[h]
	var out := _gather(arrays, first)
	var idx := PackedInt32Array()
	var src_idx: Variant = arrays[Mesh.ARRAY_INDEX]
	if src_idx != null:
		for i in (src_idx as PackedInt32Array):
			idx.append(remap[i])
	else:
		idx = remap
	out[Mesh.ARRAY_INDEX] = idx
	return out

# Keeps roughly `keep` of the triangles, using the closest generated LOD.
static func simplify(arrays: Array, keep: float) -> Array:
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var full: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var best := full
	for l in im.get_surface_lod_count(0):
		var ids := im.get_surface_lod_indices(0, l)
		if absf(float(ids.size()) / full.size() - keep) < absf(float(best.size()) / full.size() - keep):
			best = ids
	var out := arrays.duplicate()
	out[Mesh.ARRAY_INDEX] = best
	return out

# Unwelds into per-corner data with one normal per triangle (faceted look).
static func flat(arrays: Array) -> Array:
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out := _gather(arrays, idx)
	out[Mesh.ARRAY_INDEX] = null
	var v: PackedVector3Array = out[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = out[Mesh.ARRAY_NORMAL]
	for t in range(0, v.size(), 3):
		var fn := (v[t + 2] - v[t]).cross(v[t + 1] - v[t])   # Godot winding is clockwise
		var smooth := n[t] + n[t + 1] + n[t + 2]
		if fn.length_squared() < 1e-20:
			fn = smooth
		elif fn.dot(smooth) < 0.0:
			fn = -fn
		fn = fn.normalized()
		n[t] = fn
		n[t + 1] = fn
		n[t + 2] = fn
	out[Mesh.ARRAY_NORMAL] = n
	out[Mesh.ARRAY_TANGENT] = null
	return out

static func _gather(arrays: Array, order: PackedInt32Array) -> Array:
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for a in PER_VERTEX:
		var src: Variant = arrays[a]
		if src == null:
			continue
		var dst: Variant
		match a:
			Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL:
				dst = PackedVector3Array()
			Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2:
				dst = PackedVector2Array()
			Mesh.ARRAY_COLOR:
				dst = PackedColorArray()
		for i in order:
			dst.append(src[i])
		out[a] = dst
	for a in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
		var src: Variant = arrays[a]
		if src == null:
			continue
		var dst: Variant = PackedInt32Array() if a == Mesh.ARRAY_BONES else PackedFloat32Array()
		for i in order:
			dst.append_array(src.slice(i * 4, i * 4 + 4))
		out[a] = dst
	return out
