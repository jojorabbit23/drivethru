# Builds the armoured school bus (the first customer vehicle) from the
# owner's GLB in vehicles/school_bus/source/.
#   godot --headless --path . --script res://tools/build_bus.gd   # first run writes the texture
#   godot --headless --path . --import
#   godot --headless --path . --script res://tools/build_bus.gd
# The source faces +Z (snow plough at the front). Output faces -Z like every
# other model here, origin on the ground at the middle, LENGTH metres long,
# Geometry and normals are kept as sculpted: simplifying it (as the knife is)
# shredded the wheels, plough and roof cargo, so the bus is left whole.
# Output: res://vehicles/school_bus/bus_model.tscn (+ bus_mesh.res, bus_material.tres, bus_albedo.png)
extends SceneTree

const BlockyMesh = preload("res://tools/blocky_mesh.gd")
const SRC := "res://vehicles/school_bus/source/armored_school_bus.glb"
const OUT := "res://vehicles/school_bus/"
const LENGTH := 6.0
const TEX_SIZE := 2048
# The sculpt is one fused mesh. The four tyres are cut out by shape so they
# can roll: triangles whose corners all lie inside the tyre's cylinder
# (source units: radius WHEEL_R about the axle, outboard of WHEEL_IN, below
# WHEEL_TOP so the mudguards above stay on the body).
const WHEELS := {"Wheel_RL": Vector3(1, 0.09, -0.283), "Wheel_RR": Vector3(-1, 0.09, -0.283),
	"Wheel_FL": Vector3(1, 0.09, 0.258), "Wheel_FR": Vector3(-1, 0.09, 0.258)}
const WHEEL_R := 0.12          # below the axle line (nothing else down there)
const WHEEL_R_UP := 0.104      # above it, tighter: the mudguards sit just outside
const WHEEL_IN := 0.09
const WHEEL_TOP := 0.192

func _initialize() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path(SRC), st) == OK)
	var albedo := OUT + "bus_albedo.png"
	if not FileAccess.file_exists(albedo):
		for i in st.get_images().size():
			var name: String = st.json["images"][i].get("name", "")
			if name.ends_with("_basecolor.jpg"):
				var img: Image = (st.get_images()[i] as Texture2D).get_image()
				img.decompress()
				img.convert(Image.FORMAT_RGB8)
				img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_LANCZOS)
				img.save_png(ProjectSettings.globalize_path(albedo))
		print("wrote ", albedo, " - run --import, then this script again")
		quit()
		return
	var arr := (st.get_meshes()[0] as GLTFMesh).mesh.get_surface_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var aabb := AABB(v[0], Vector3.ZERO)
	for p in v:
		aabb = aabb.expand(p)
	var s := LENGTH / aabb.size.z
	var c := aabb.get_center()
	var source_v := PackedVector3Array(v)   # untouched copy, for cutting out the tyres
	for i in v.size():
		var p := (v[i] - Vector3(c.x, aabb.position.y, c.z)) * s
		v[i] = Vector3(-p.x, p.y, -p.z)      # turn 180° so the front faces -Z
		n[i] = Vector3(-n[i].x, n[i].y, -n[i].z)
	# which wheel (if any) owns each triangle, decided in source space
	var src := source_v
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var owner_of := PackedInt32Array()
	owner_of.resize(idx.size() / 3)
	var names: Array = WHEELS.keys()
	for t in idx.size() / 3:
		owner_of[t] = -1
		for w in names.size():
			var wc: Vector3 = WHEELS[names[w]]
			var inside := true
			for k in 3:
				var p := src[idx[t * 3 + k]]
				var lim := WHEEL_R if p.y < wc.y + 0.03 else WHEEL_R_UP
				if p.x * wc.x < WHEEL_IN or p.y > WHEEL_TOP or Vector2(p.z - wc.z, p.y - wc.y).length() > lim:
					inside = false
					break
			if inside:
				owner_of[t] = w
				break
	var parts := []   # [name, arrays, centre (final space)]
	for w in range(-1, names.size()):
		var centre := Vector3.ZERO
		if w >= 0:
			var wc: Vector3 = WHEELS[names[w]]
			var xs := 0.0
			var nx := 0
			for t in idx.size() / 3:
				if owner_of[t] == w:
					for k in 3:
						xs += src[idx[t * 3 + k]].x
						nx += 1
			var c_src := Vector3(xs / maxi(nx, 1), wc.y, wc.z)
			var q := (c_src - Vector3(c.x, aabb.position.y, c.z)) * s
			centre = Vector3(-q.x, q.y, -q.z)
		var pv := PackedVector3Array()
		var pn := PackedVector3Array()
		var pu := PackedVector2Array()
		var pi := PackedInt32Array()
		var remap := {}
		for t in idx.size() / 3:
			if owner_of[t] != w:
				continue
			for k in 3:
				var i := idx[t * 3 + k]
				if not remap.has(i):
					remap[i] = pv.size()
					pv.append(v[i] - centre)
					pn.append(n[i])
					pu.append(uv[i])
				pi.append(remap[i])
		var pa := []
		pa.resize(Mesh.ARRAY_MAX)
		pa[Mesh.ARRAY_VERTEX] = pv
		pa[Mesh.ARRAY_NORMAL] = pn
		pa[Mesh.ARRAY_TEX_UV] = pu
		pa[Mesh.ARRAY_INDEX] = pi
		parts.append(["Body" if w < 0 else names[w], pa, centre])
	var before := BlockyMesh.triangle_count(arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(albedo)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.8
	mat.metallic_specular = 0.3
	ResourceSaver.save(mat, OUT + "bus_material.tres")
	mat.take_over_path(OUT + "bus_material.tres")
	var size := aabb.size * s
	var root_node := Node3D.new()
	root_node.name = "SchoolBus"
	var counts := []
	for part in parts:
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part[1])
		m.surface_set_material(0, mat)
		var path: String = OUT + ("bus_mesh.res" if part[0] == "Body" else "bus_%s.res" % (part[0] as String).to_lower())
		ResourceSaver.save(m, path)
		m.take_over_path(path)
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		mi.mesh = m
		mi.position = part[2]
		root_node.add_child(mi)
		mi.owner = root_node
		counts.append("%s %d" % [part[0], BlockyMesh.triangle_count(part[1])])
	var body := StaticBody3D.new()   # bullets stop on it
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	root_node.add_child(body)
	body.owner = root_node
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x * 0.85, size.y * 0.8, size.z * 0.85)
	cs.shape = box
	cs.position = Vector3(0, size.y * 0.45, 0)
	body.add_child(cs)
	cs.owner = root_node
	root_node.set_meta("size", size)
	root_node.set_meta("wheel_radius", WHEEL_R * s)
	var ps := PackedScene.new()
	ps.pack(root_node)
	var err := ResourceSaver.save(ps, OUT + "bus_model.tscn")
	print("bus: %d triangles (%s), size %s m, wheel radius %.2f m, saved err=%d" % [before, ", ".join(counts), str(size.snapped(Vector3.ONE * 0.01)), WHEEL_R * s, err])
	root_node.free()
	quit()
