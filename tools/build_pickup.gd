# Builds the mushroom pickup mesh + material from the same glowing-mushroom
# GLB the Scuttler is made from (it's what Shamblers and Scuttlers drop).
#   godot --headless --path . --script res://tools/build_pickup.gd
# Needs the Scuttler textures (run tools/build_scuttler.gd first).
# Output: res://pickups/mushroom/mushroom_pickup_mesh.res, mushroom_pickup_material.tres
extends SceneTree

const Palette = preload("res://core/palette.gd")
const SRC := "res://enemies/scuttler/source/Mushroom_AllAround_Glow_1.glb"
const OUT := "res://pickups/mushroom/"
const HEIGHT := 0.34   # metres, cap top to boot sole

func _initialize() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path(SRC), st) == OK)
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
	arr[Mesh.ARRAY_VERTEX] = v
	# keep only what the material uses
	var keep := []
	keep.resize(Mesh.ARRAY_MAX)
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
		keep[k] = arr[k]
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, keep)
	im.generate_lods(25.0, 60.0, [])
	var mesh := im.get_mesh()

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://enemies/scuttler/scuttler_albedo.png")
	mat.emission_enabled = true
	mat.emission_texture = load("res://enemies/scuttler/scuttler_glow.png")
	mat.emission = Color.WHITE
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mat.emission_energy_multiplier = 2.2
	mat.roughness = 0.8
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
