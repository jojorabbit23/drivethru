extends Node3D
var head: Node3D
var target: Node3D
var eyes: Array[MeshInstance3D]=[]
func _ready() -> void:
	head=Node3D.new()
	head.name="Head"
	add_child(head)
	head.rotation.y=-PI/2.0
	var black:=StandardMaterial3D.new()
	black.albedo_color=Color.BLACK
	black.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	# Seated torso stays fixed in the chair while only the head tracks the player.
	var torso:=MeshInstance3D.new()
	torso.name="SeatedBody"
	var body_box:=BoxMesh.new()
	body_box.size=Vector3(0.30,0.52,0.38)
	torso.mesh=body_box
	torso.position=Vector3(0,-0.36,0.015)
	torso.material_override=black
	torso.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(torso)
	var cube:=MeshInstance3D.new()
	cube.name="BlackCube"
	var box:=BoxMesh.new()
	box.size=Vector3.ONE*0.27
	cube.mesh=box
	cube.material_override=black
	cube.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(cube)
	var white:=StandardMaterial3D.new()
	white.albedo_color=Color.WHITE
	white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for x: float in [-0.063,0.063]:
		var dot:=MeshInstance3D.new()
		dot.name="WhiteDotLeft" if x<0 else "WhiteDotRight"
		var sphere:=SphereMesh.new()
		sphere.radius=0.020
		sphere.height=0.040
		sphere.radial_segments=8
		sphere.rings=4
		dot.mesh=sphere
		dot.position=Vector3(x,0.025,-0.137)
		dot.material_override=white
		dot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(dot)
		eyes.append(dot)
	target=get_tree().get_first_node_in_group("player") as Node3D
func _process(delta: float) -> void:
	if not is_instance_valid(target):return
	var aim: Vector3=target.global_position+Vector3(0,1.55,0)
	var camera: Node3D=target.get_node_or_null("Head/Camera3D") as Node3D
	if camera:aim=camera.global_position
	var local_aim: Vector3=to_local(aim)
	if local_aim.length_squared()<0.01:return
	var desired_yaw: float=atan2(-local_aim.x,-local_aim.z)
	var desired_pitch: float=atan2(local_aim.y,Vector2(local_aim.x,local_aim.z).length())
	head.rotation.y=lerp_angle(head.rotation.y,desired_yaw,1.0-exp(-delta*7.0))
	head.rotation.x=lerp_angle(head.rotation.x,clampf(desired_pitch,-0.35,0.35),1.0-exp(-delta*7.0))
