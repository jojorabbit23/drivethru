# Builds the mushroom pickup (what Shamblers and Scuttlers drop) from the
# owner's pixelated mushroom model.
#   godot --headless --path . --script res://tools/build_pickup.gd   # writes textures on first run
#   godot --headless --path . --import
#   godot --headless --path . --script res://tools/build_pickup.gd
# Output: res://pickups/mushroom/mushroom_pickup_mesh.res, mushroom_pickup_material.tres,
#         mushroom_albedo.png, mushroom_normal.png
extends SceneTree

const Palette = preload("res://core/palette.gd")
const SRC := "res://pickups/mushroom/source/pixelated_mushroom_3d_model.glb"
const OUT := "res://pickups/mushroom/"
const HEIGHT := 0.34   # metres, cap top to stem base
const TEX_SIZE := 512

func _initialize() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path(SRC), st) == OK)
	var albedo := OUT + "mushroom_albedo.png"
	var normal := OUT + "mushroom_normal.png"
	if not FileAccess.file_exists(albedo) or not FileAccess.file_exists(normal):
		var imgs: Array = st.get_images()
		for i in imgs.size():
			var name: String = st.json["images"][i].get("name", "")
			var path := ""
			if name.ends_with("_basecolor.jpg"):
				path = albedo
			elif name.ends_with("_normal.png"):
				path = normal
			if path == "":
				continue
			var img: Image = (imgs[i] as Texture2D).get_image()
			img.decompress()
			img.convert(Image.FORMAT_RGB8)
			img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_LANCZOS)
			img.save_png(ProjectSettings.globalize_path(path))
		print("wrote textures - run --import, then this script again")
		quit()
		return

	var arr := (st.get_meshes()[0] as GLTFMesh).mesh.get_surface_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var aabb := AABB(v[0], Vector3.ZERO)
	for p in v:
		aabb = aabb.expand(p)
	var s := HEIGHT / aabb.size.y
	var centre := aabb.get_center()
	# pivot in the middle so it spins and bobs about its own centre
	for i in v.size():
		v[i] = (v[i] - centre) * s
	var keep := []
	keep.resize(Mesh.ARRAY_MAX)
	keep[Mesh.ARRAY_VERTEX] = v
	for k in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
		keep[k] = arr[k]
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, keep)
	im.generate_lods(25.0, 60.0, [])
	var mesh := im.get_mesh()

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(albedo)
	mat.normal_enabled = true
	mat.normal_texture = load(normal)
	mat.roughness = 0.8
	# a slight warm self-glow: its own colours, tinted amber, at low strength
	mat.emission_enabled = true
	mat.emission_texture = load(albedo)
	mat.emission = Palette.AMBER_GLOW
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mat.emission_energy_multiplier = 0.35
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS   # keep the pixel look
	var halo := ShaderMaterial.new()
	halo.shader = load(OUT + "pickup_glow.gdshader")
	halo.set_shader_parameter("glow_color", Palette.AMBER_GLOW)
	mat.next_pass = halo
	ResourceSaver.save(mat, OUT + "mushroom_pickup_material.tres")
	mat.take_over_path(OUT + "mushroom_pickup_material.tres")
	mesh.surface_set_material(0, mat)
	var err := ResourceSaver.save(mesh, OUT + "mushroom_pickup_mesh.res")
	print("saved pickup mesh err=%d  tris %d  size %s" % [err, (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, str((aabb.size * s).snapped(Vector3.ONE * 0.01))])
	quit()
