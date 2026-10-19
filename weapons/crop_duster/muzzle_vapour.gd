# Eight reused low-poly puffs; no per-shot nodes or particle emitters.
extends Node3D
const P=preload("res://core/palette.gd")
var puffs: Array[MeshInstance3D]=[]
var age: float=1.0
var origin:=Vector3.ZERO
func _ready() -> void:
 var mesh:=SphereMesh.new()
 mesh.radius=1.0
 mesh.height=2.0
 mesh.radial_segments=6
 mesh.rings=3
 for i in 8:
  var puff:=MeshInstance3D.new()
  puff.mesh=mesh
  puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var material:=ShaderMaterial.new()
  material.shader=preload("res://weapons/crop_duster/vapour.gdshader")
  puff.material_override=material
  add_child(puff)
  puff.hide()
  puffs.append(puff)
func clear() -> void:
 age=1.0
 for puff in puffs:puff.hide()
func release(position: Vector3,camera: Camera3D) -> void:
 origin=camera.to_local(position)
 age=0.0
 advance(0.0)
func advance(delta: float) -> void:
 age+=delta
 for i in puffs.size():
  var puff: MeshInstance3D=puffs[i]
  var t: float=age-float(i)*0.018
  puff.visible=t>=0.0 and t<0.48
  if not puff.visible:continue
  var camera: Camera3D=get_parent().get_parent()
  var drift:=Vector3(sin(float(i)*2.4)*0.035,t*0.14,-t*0.20)
  puff.global_position=camera.to_global(origin+drift)
  puff.scale=Vector3.ONE*(0.009+t*0.055)*(0.8+float(i%3)*0.12)
  var colour: Color=P.WARM_CHALK.lerp(P.CONCRETE_GREY,0.4)
  colour.a=0.19*(1.0-t/0.48)
  (puff.material_override as ShaderMaterial).set_shader_parameter("colour",colour)
