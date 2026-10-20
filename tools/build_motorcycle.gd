extends SceneTree
const OUT: String="res://props/motorcycle/"
func _initialize() -> void:
 var doc:=GLTFDocument.new();var state:=GLTFState.new()
 assert(doc.append_from_file(ProjectSettings.globalize_path(OUT+"source/motorcycle.glb"),state)==OK)
 var source: ImporterMesh=(state.get_meshes()[0] as GLTFMesh).mesh
 var bounds:=AABB()
 var first: bool=true
 for surface in source.get_surface_count():
  var vertices: PackedVector3Array=source.get_surface_arrays(surface)[Mesh.ARRAY_VERTEX]
  for v: Vector3 in vertices:
   bounds=AABB(v,Vector3.ZERO) if first else bounds.expand(v);first=false
 var scale_factor: float=2.35/bounds.size.z
 var centre:=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
 var built:=ImporterMesh.new()
 var triangles: int=0
 for surface in source.get_surface_count():
  var arrays: Array=source.get_surface_arrays(surface)
  var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  for i in vertices.size():vertices[i]=(vertices[i]-centre)*scale_factor
  arrays[Mesh.ARRAY_VERTEX]=vertices
  # Discard zero-area source faces before LOD simplification.
  var input_indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  if input_indices.is_empty():
   for i in vertices.size():input_indices.append(i)
  var clean:=PackedInt32Array()
  for i in range(0,input_indices.size(),3):
   var a: int=input_indices[i];var b: int=input_indices[i+1];var c: int=input_indices[i+2]
   if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length_squared()>0.000000000001:
    clean.append_array(PackedInt32Array([a,b,c]))
  arrays[Mesh.ARRAY_INDEX]=clean
  var material: StandardMaterial3D=source.get_surface_material(surface).duplicate()
  var img: Image=material.albedo_texture.get_image();img.decompress();img.resize(1024,1024,Image.INTERPOLATE_LANCZOS);img.generate_mipmaps()
  material.albedo_texture=ImageTexture.create_from_image(img)
  material.normal_enabled=false;material.normal_texture=null
  material.metallic_texture=null;material.roughness_texture=null
  material.metallic=.15;material.roughness=.85
  material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
  built.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},material)
  var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  triangles+=indices.size()/3 if not indices.is_empty() else vertices.size()/3
 built.generate_lods(25,60,[])
 var mesh: ArrayMesh=built.get_mesh()
 assert(ResourceSaver.save(mesh,OUT+"motorcycle_mesh.res")==OK)
 print("Motorcycle: ",triangles," triangles; bounds ",mesh.get_aabb(),"; 1024px supplied colour texture, LODs")
 quit()
