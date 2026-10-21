extends RefCounted
var v:=PackedVector3Array()
var n:=PackedVector3Array()
var c:=PackedColorArray()
static var finish_material: StandardMaterial3D
func tri(a: Vector3,b: Vector3,d: Vector3,colour: Color) -> void:
 var normal: Vector3=(d-a).cross(b-a).normalized()
 for point in [a,b,d]:v.append(point);n.append(normal);c.append(colour)
func shape(mesh: Mesh,at: Vector3,colour: Color,rotation: Vector3=Vector3.ZERO) -> void:
 var arr: Array=mesh.surface_get_arrays(0)
 var points: PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
 var ids: PackedInt32Array=arr[Mesh.ARRAY_INDEX]
 var transform:=Transform3D(Basis.from_euler(rotation),at)
 for i in range(0,ids.size(),3):tri(transform*points[ids[i]],transform*points[ids[i+1]],transform*points[ids[i+2]],colour)
func box(at: Vector3,size: Vector3,colour: Color,rotation: Vector3=Vector3.ZERO) -> void:
 var mesh:=BoxMesh.new();mesh.size=size;shape(mesh,at,colour,rotation)
func cylinder(at: Vector3,radius: float,height: float,colour: Color,top: float=-1.0,rotation: Vector3=Vector3.ZERO) -> void:
 var mesh:=CylinderMesh.new();mesh.top_radius=radius if top<0 else top;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=8;mesh.rings=1
 shape(mesh,at,colour,rotation)
func beam(a: Vector3,b: Vector3,width: float,colour: Color) -> void:
 var mesh:=BoxMesh.new();mesh.size=Vector3(width,a.distance_to(b),width)
 var basis:=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
 shape(mesh,(a+b)*.5,colour,basis.get_euler())
func finish() -> ArrayMesh:
 if finish_material==null:
  finish_material=StandardMaterial3D.new();finish_material.vertex_color_use_as_albedo=true;finish_material.vertex_color_is_srgb=true;finish_material.roughness=.9
 var arr:=[];arr.resize(Mesh.ARRAY_MAX);arr[Mesh.ARRAY_VERTEX]=v;arr[Mesh.ARRAY_NORMAL]=n;arr[Mesh.ARRAY_COLOR]=c
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr);mesh.surface_set_material(0,finish_material)
 return mesh
