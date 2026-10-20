# Split by connected topology after welding UV seams; exclude all three left-column morels.
extends SceneTree
const OUT: String="res://pickups/mushroom/"
var parent:=PackedInt32Array()
func find_root(i: int) -> int:
 var at: int=i
 while parent[at]!=at:
  parent[at]=parent[parent[at]];at=parent[at]
 return at
func _initialize() -> void:
 var doc:=GLTFDocument.new();var state:=GLTFState.new()
 assert(doc.append_from_file(ProjectSettings.globalize_path(OUT+"source/mushroom_pack.glb"),state)==OK)
 var mesh: ImporterMesh=(state.get_meshes()[0] as GLTFMesh).mesh
 var a: Array=mesh.get_surface_arrays(0)
 var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var n: PackedVector3Array=a[Mesh.ARRAY_NORMAL];var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV];var ix: PackedInt32Array=a[Mesh.ARRAY_INDEX]
 parent.resize(v.size())
 for i in v.size():parent[i]=i
 var seams: Dictionary={}
 for i in v.size():
  var key: Vector3=v[i].snapped(Vector3.ONE*0.00001)
  if seams.has(key):parent[find_root(i)]=find_root(int(seams[key]))
  else:seams[key]=i
 for tri in range(0,ix.size(),3):
  parent[find_root(ix[tri+1])]=find_root(ix[tri]);parent[find_root(ix[tri+2])]=find_root(ix[tri])
 var groups: Dictionary={}
 for tri in range(0,ix.size(),3):
  var key: int=find_root(ix[tri])
  if not groups.has(key):groups[key]=[]
  groups[key].append(tri)
 assert(groups.size()==9,"Expected nine complete mushrooms")
 var source: StandardMaterial3D=mesh.get_surface_material(0)
 var image: Image=source.albedo_texture.get_image();image.decompress();image.resize(1024,1024,Image.INTERPOLATE_LANCZOS);image.generate_mipmaps()
 var mat:=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(image);mat.roughness=0.85;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
 # Pickup colours must remain readable under overlapping lights and in dark lanes.
 mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.emission_enabled=false
 var halo:=ShaderMaterial.new();halo.shader=load(OUT+"pickup_glow.gdshader");halo.set_shader_parameter("glow_color",preload("res://core/palette.gd").AMBER_GLOW);mat.next_pass=halo
 assert(ResourceSaver.save(mat,OUT+"pack_material.tres")==OK);mat.take_over_path(OUT+"pack_material.tres")
 var counts: Dictionary={"brown":0,"blue":0,"red":0};var excluded: int=0
 for triangles: Array in groups.values():
  var bounds:=AABB(v[ix[triangles[0]]],Vector3.ZERO)
  for tri: int in triangles:
   for k in 3:bounds=bounds.expand(v[ix[tri+k]])
  if bounds.get_center().x < -0.25:excluded+=1;continue
  var kind: String="brown" if bounds.get_center().y>0.465 else ("blue" if bounds.get_center().y>0.23 else "red")
  var pv:=PackedVector3Array();var pn:=PackedVector3Array();var pu:=PackedVector2Array()
  var factor: float=minf(0.34/bounds.size.y,0.48/maxf(bounds.size.x,bounds.size.z))
  for tri: int in triangles:
   for k in 3:
    var at: int=ix[tri+k];pv.append((v[at]-bounds.get_center())*factor);pn.append(n[at]);pu.append(uv[at])
  var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=pv;arrays[Mesh.ARRAY_NORMAL]=pn;arrays[Mesh.ARRAY_TEX_UV]=pu
  var built:=ArrayMesh.new();built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);built.surface_set_material(0,mat)
  var slot: int=counts[kind];counts[kind]=slot+1
  assert(ResourceSaver.save(built,OUT+"pack_%s_%d.res"%[kind,slot])==OK)
  print(kind," variant ",slot,": ",triangles.size()," intact triangles")
 assert(excluded==3 and counts.values().all(func(c: int)->bool:return c==2))
 print("PASS six intact non-morel variants; three morels excluded")
 quit()
