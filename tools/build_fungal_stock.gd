extends SceneTree
const OUT: String="res://props/fungal_stock/"
func _initialize() -> void:
 var doc:=GLTFDocument.new();var state:=GLTFState.new()
 assert(doc.append_from_file(ProjectSettings.globalize_path(OUT+"source/fungal_cuts.glb"),state)==OK)
 var mesh: ImporterMesh=(state.get_meshes()[0] as GLTFMesh).mesh
 var arrays: Array=mesh.get_surface_arrays(0)
 var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var source: StandardMaterial3D=mesh.get_surface_material(0)
 var img: Image=source.albedo_texture.get_image();img.decompress()
 img.resize(1024,1024,Image.INTERPOLATE_LANCZOS);img.generate_mipmaps()
 var mat:=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(img);mat.roughness=0.92;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
 assert(ResourceSaver.save(mat,OUT+"stock_material.tres")==OK);mat.take_over_path(OUT+"stock_material.tres")
 var total: int=0
 for part in 6:
  var pv:=PackedVector3Array();var pn:=PackedVector3Array();var pu:=PackedVector2Array()
  for tri in range(0,indices.size(),3):
   var c: Vector3=(vertices[indices[tri]]+vertices[indices[tri+1]]+vertices[indices[tri+2]])/3.0
   var column: int=0 if c.x < -0.15 else (1 if c.x < 0.175 else 2)
   var row: int=0 if c.y < 0.27 else 1
   if row*3+column != part:continue
   for k in 3:
    var at: int=indices[tri+k];pv.append(vertices[at]);pn.append(normals[at]);pu.append(uvs[at])
  assert(pv.size()>0)
  var bounds:=AABB(pv[0],Vector3.ZERO)
  for v: Vector3 in pv:bounds=bounds.expand(v)
  var scale_factor: float=0.30/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
  var origin: Vector3=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
  for i in pv.size():pv[i]=(pv[i]-origin)*scale_factor
  var a: Array=[];a.resize(Mesh.ARRAY_MAX);a[Mesh.ARRAY_VERTEX]=pv;a[Mesh.ARRAY_NORMAL]=pn;a[Mesh.ARRAY_TEX_UV]=pu
  var built:=ArrayMesh.new();built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a);built.surface_set_material(0,mat)
  assert(ResourceSaver.save(built,OUT+"cut_%d.res"%part)==OK)
  total+=pv.size()/3
  print("Part ",part,": ",pv.size()/3," triangles; original bounds ",bounds)
 assert(total==indices.size()/3)
 print("PASS six parts, every source triangle retained once: ",total)
 quit()
