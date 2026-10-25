extends SceneTree
# args: base_path ... ; writes base.lods.json with {lods:[{tris, file}]}
func f32(path: String) -> PackedFloat32Array:
	return FileAccess.get_file_as_bytes(path).to_float32_array()
func _initialize() -> void:
	for base in OS.get_cmdline_user_args():
		var p := f32(base + ".pos"); var n := f32(base + ".nrm"); var u := f32(base + ".uv")
		var idx_b := FileAccess.get_file_as_bytes(base + ".idx")
		var idx := PackedInt32Array(); idx.resize(idx_b.size() / 4)
		for k in idx.size(): idx[k] = idx_b.decode_u32(k * 4)
		var vc := p.size() / 3
		var verts := PackedVector3Array(); var nrms := PackedVector3Array(); var uvs := PackedVector2Array()
		verts.resize(vc); nrms.resize(vc); uvs.resize(vc)
		for i in vc:
			verts[i] = Vector3(p[i*3], p[i*3+1], p[i*3+2]); nrms[i] = Vector3(n[i*3], n[i*3+1], n[i*3+2]); uvs[i] = Vector2(u[i*2], u[i*2+1])
		var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts; arrays[Mesh.ARRAY_NORMAL] = nrms; arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_INDEX] = idx
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		im.generate_lods(25.0, 60.0, [])
		var after: Array = im.get_surface_arrays(0)
		var vc2: int = (after[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var out := {"verts_before": vc, "verts_after": vc2, "lods": []}
		for l in im.get_surface_lod_count(0):
			var li: PackedInt32Array = im.get_surface_lod_indices(0, l)
			var fn := base + ".lod%d" % l
			var fa := FileAccess.open(fn, FileAccess.WRITE)
			for v in li: fa.store_32(v)
			fa.close()
			out["lods"].append({"tris": li.size() / 3, "file": fn, "size": im.get_surface_lod_size(0, l)})
		if vc2 != vc:
			var fv := FileAccess.open(base + ".verts_after", FileAccess.WRITE)
			var av: PackedVector3Array = after[Mesh.ARRAY_VERTEX]
			var au: PackedVector2Array = after[Mesh.ARRAY_TEX_UV]
			for k in av.size():
				fv.store_float(av[k].x); fv.store_float(av[k].y); fv.store_float(av[k].z); fv.store_float(au[k].x); fv.store_float(au[k].y)
			fv.close()
		FileAccess.open(base + ".lods.json", FileAccess.WRITE).store_string(JSON.stringify(out))
		print(base, " ", JSON.stringify(out).left(400))
	quit()
