extends SceneTree
const OUT: String="res://props/empty_bottle/"
func _initialize() -> void:
	var doc:=GLTFDocument.new()
	var state:=GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path(OUT+"source/bottle.glb"),state)==OK)
	var mesh: ImporterMesh=(state.get_meshes()[0] as GLTFMesh).mesh
	var arrays: Array=mesh.get_surface_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var bounds:=AABB(vertices[0],Vector3.ZERO)
	for vertex: Vector3 in vertices:bounds=bounds.expand(vertex)
	for i in vertices.size():vertices[i]=(vertices[i]-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z))*(0.27/bounds.size.y)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var built:=ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var source: StandardMaterial3D=mesh.get_surface_material(0)
	var image: Image=source.albedo_texture.get_image()
	image.decompress()
	image.resize(512,512,Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var material:=StandardMaterial3D.new()
	material.albedo_texture=ImageTexture.create_from_image(image)
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness=0.8
	built.surface_set_material(0,material)
	assert(ResourceSaver.save(built,OUT+"bottle_mesh.res")==OK)
	print("Built empty decorative bottle, height 0.27m, vertices ",vertices.size())
	quit()

