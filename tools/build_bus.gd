# Builds the armoured school bus (the first customer vehicle) from the
# owner's GLB in vehicles/school_bus/source/.
#   godot --headless --path . --script res://tools/build_bus.gd   # first run writes the texture
#   godot --headless --path . --import
#   godot --headless --path . --script res://tools/build_bus.gd
# The source faces +Z (snow plough at the front). Output faces -Z like every
# other model here, origin on the ground at the middle, LENGTH metres long,
# a little blockier (fewer triangles, flat shaded) to sit with the zombies.
# Output: res://vehicles/school_bus/bus_model.tscn (+ bus_mesh.res, bus_material.tres, bus_albedo.png)
extends SceneTree

const BlockyMesh = preload("res://tools/blocky_mesh.gd")
const SRC := "res://vehicles/school_bus/source/armored_school_bus.glb"
const OUT := "res://vehicles/school_bus/"
const LENGTH := 6.0
const TEX_SIZE := 1024
const KEEP := 0.5

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
	for i in v.size():
		var p := (v[i] - Vector3(c.x, aabb.position.y, c.z)) * s
		v[i] = Vector3(-p.x, p.y, -p.z)      # turn 180° so the front faces -Z
		n[i] = Vector3(-n[i].x, n[i].y, -n[i].z)
	var keep := []
	keep.resize(Mesh.ARRAY_MAX)
	keep[Mesh.ARRAY_VERTEX] = v
	keep[Mesh.ARRAY_NORMAL] = n
	keep[Mesh.ARRAY_TEX_UV] = arr[Mesh.ARRAY_TEX_UV]
	keep[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
	var before := BlockyMesh.triangle_count(keep)
	keep = BlockyMesh.flat(BlockyMesh.simplify(keep, KEEP))
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, keep)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(albedo)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 0.8
	mat.metallic_specular = 0.3
	ResourceSaver.save(mat, OUT + "bus_material.tres")
	mat.take_over_path(OUT + "bus_material.tres")
	mesh.surface_set_material(0, mat)
	ResourceSaver.save(mesh, OUT + "bus_mesh.res")
	mesh.take_over_path(OUT + "bus_mesh.res")
	var size := aabb.size * s
	var root_node := Node3D.new()
	root_node.name = "SchoolBus"
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = mesh
	root_node.add_child(mi)
	mi.owner = root_node
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
	var ps := PackedScene.new()
	ps.pack(root_node)
	var err := ResourceSaver.save(ps, OUT + "bus_model.tscn")
	print("bus: %d -> %d triangles, size %s m, saved err=%d" % [before, BlockyMesh.triangle_count(keep), str(size.snapped(Vector3.ONE * 0.01)), err])
	root_node.free()
	quit()
