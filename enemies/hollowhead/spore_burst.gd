extends Node3D
const P=preload("res://core/palette.gd")
const Rally=preload("res://enemies/hollowhead/horde_rally.gd")
const RADIUS: float=1.7
const DAMAGE: float=3.0
var exposed: bool=false
var age: float=0.0
var puffs: Array[MeshInstance3D]=[]
var directions: Array[Vector3]=[]
var material: StandardMaterial3D
var overlay: ColorRect
func _ready() -> void:
	add_to_group("spore_bursts")
	var player: Node3D=get_tree().get_first_node_in_group("player") as Node3D
	if player and not player.is_dead():
		var chest: Vector3=player.global_position+Vector3(0,1.1,0)
		var query:=PhysicsRayQueryParameters3D.create(global_position,chest,3)
		if chest.distance_to(global_position)<RADIUS and get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			exposed=true
			player.take_damage(DAMAGE)
	for enemy: Node3D in get_tree().get_nodes_in_group("zombies"):
		if global_position.distance_to(enemy.global_position)<8.0:Rally.apply(enemy,6.0)
	if DisplayServer.get_name()=="headless":return
	if exposed:
		var layer:=CanvasLayer.new()
		layer.layer=4
		add_child(layer)
		overlay=ColorRect.new()
		overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
		overlay.color=Color(P.OXIDISED_TEAL,.24)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(overlay)
	if get_tree().get_nodes_in_group("spore_bursts").size()>8:return
	var image:=Image.create(16,16,false,Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var distance: float=Vector2(x-7.5,y-7.5).length()/8.0
			image.set_pixel(x,y,Color(P.WARM_CHALK,maxf(0,1-distance)*.55))
	material=StandardMaterial3D.new()
	material.albedo_texture=ImageTexture.create_from_image(image)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=P.AMBER_GLOW
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var quad:=QuadMesh.new()
	quad.size=Vector2(.6,.6)
	for i in 14:
		var puff:=MeshInstance3D.new()
		puff.mesh=quad
		puff.material_override=material
		puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)
		puffs.append(puff)
		directions.append(Vector3(sin(i*2.4),cos(i*1.9)*.5,cos(i*2.4)))
func _process(delta: float) -> void:
	age+=delta
	if age>=1.6:
		queue_free()
		return
	for i in puffs.size():
		puffs[i].position=directions[i]*age*.7
		puffs[i].scale=Vector3.ONE*(.4+age)
	if material:material.albedo_color.a=1.0-age/1.6
	if overlay:overlay.color.a=.24*(1.0-age/1.6)
