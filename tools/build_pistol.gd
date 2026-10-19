# Rebuild the original custom pistol with the new pack's animated hands.
extends SceneTree
const SOURCE="res://addons/psx_firearms/models/fp_pistol_model.glb"
const Common=preload("res://tools/build_crop_duster.gd")
func _initialize() -> void: build.call_deferred()
func build() -> void:
 var scene:=Node3D.new()
 scene.name="PistolViewmodel"
 var arms: Node3D=load(SOURCE).instantiate()
 arms.scene_file_path=""
 arms.name="Arms"
 arms.rotation.y=PI
 scene.add_child(arms)
 var held: Node3D=arms.find_child("fp_pistol_held",true,false)
 for mesh: MeshInstance3D in arms.find_children("*","MeshInstance3D",true,false):
  if mesh.name in ["fp_pistol","fp_pistol_forearm_l","fp_pistol_hand_r","fp_pistol_hand_l"]:
   var wrist: Vector3=Vector3(0.066006,0.078941,0.386538) if mesh.name=="fp_pistol" else Vector3.ZERO
   mesh.mesh=Common.recolour(mesh.mesh,0 if mesh.name in ["fp_pistol","fp_pistol_forearm_l"] else 2,wrist)
   mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  else: mesh.mesh=null
 var gun: Node3D=load("res://weapons/pistol/source/pistol_custom.glb").instantiate()
 gun.scene_file_path=""
 gun.name="Gun"
 gun.position=Vector3(-0.008,0.018,-0.01)
 held.add_child(gun)
 for mesh: MeshInstance3D in gun.find_children("*","MeshInstance3D",true,false):
  mesh.mesh=mesh.mesh.duplicate()
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for i in mesh.mesh.get_surface_count():
   var original: StandardMaterial3D=mesh.mesh.surface_get_material(i)
   var mat:=ShaderMaterial.new()
   mat.shader=load("res://weapons/crop_duster/viewmodel.gdshader")
   mat.set_shader_parameter("colour",original.albedo_color)
   mat.set_shader_parameter("textured",original.albedo_texture!=null)
   mat.set_shader_parameter("albedo_tex",original.albedo_texture)
   mat.set_shader_parameter("roughness",original.roughness)
   mat.set_shader_parameter("metallic",original.metallic)
   mat.set_shader_parameter("orm_tex",original.metallic_texture)
   mat.set_shader_parameter("has_orm",original.metallic_texture!=null)
   mesh.mesh.surface_set_material(i,mat)
 # The earlier custom asset only supplied a magazine baseplate. Fill the body
 # so the reload hand carries a complete magazine instead of a floating cap.
 var magazine: Node3D=gun.find_child("pistol_magazine",true,false)
 var body:=MeshInstance3D.new()
 body.name="MagazineBody"
 var box:=BoxMesh.new()
 box.size=Vector3(0.024,0.085,0.032)
 body.mesh=box
 body.position=Vector3(0,0.040,-0.010)
 body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var metal:=ShaderMaterial.new()
 metal.shader=load("res://weapons/crop_duster/viewmodel.gdshader")
 metal.set_shader_parameter("colour",preload("res://core/palette.gd").WET_CHARCOAL)
 metal.set_shader_parameter("roughness",0.75)
 metal.set_shader_parameter("metallic",0.35)
 body.material_override=metal
 magazine.add_child(body)
 root.add_child(scene)
 for ap: AnimationPlayer in scene.find_children("*","AnimationPlayer",true,false):
  ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 Common.own_children(scene,scene)
 var packed:=PackedScene.new()
 packed.pack(scene)
 var err: Error=ResourceSaver.save(packed,"res://weapons/pistol/pistol_viewmodel.tscn")
 print("Pistol viewmodel: ",err)
 scene.free()
 quit(err)
