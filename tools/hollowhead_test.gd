extends SceneTree
const Hitscan=preload("res://core/hitscan.gd")
var failures: int=0
var main: Node3D
var player: Node3D
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func spawn(at: Vector3=Vector3(-3,0,-2)) -> Node3D:
	var enemy: Node3D=main.spawn_hollowhead()
	enemy.set_physics_process(false)
	enemy.global_position=at
	enemy.rotation.y=PI
	return enemy
func frames(count: int) -> void:
	for i in count:await physics_frame
func run() -> void:
	seed(71)
	main=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	player=main.player
	player.set_physics_process(false)
	player.max_health=10000
	player.health=10000
	player.position=Vector3(-3,0,-1)
	var enemy: Node3D=spawn()
	check(enemy.health==80 and enemy.attack_damage==8,"weak common-infected tuning")
	var mesh: ArrayMesh=enemy.get_node("Model/Skeleton3D/Body").mesh
	var weights: PackedFloat32Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_WEIGHTS]
	var normalised: bool=true
	for i in range(0,weights.size(),4):
		if absf(weights[i]+weights[i+1]+weights[i+2]+weights[i+3]-1)>.001:normalised=false
	check(normalised,"every model vertex has normalised skin influences")
	for clip: String in ["idle","shamble","rip","climb","swing","swing_left","slam","flinch","death"]:
		check(enemy.anim.has_animation(clip),"clip "+clip)
	var skeleton: Skeleton3D=enemy.get_node("Model/Skeleton3D")
	enemy.anim.play("slam",0)
	enemy.anim.seek(.62,true)
	skeleton.force_update_all_bone_transforms()
	var arrays: Array=mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var faces: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var palette: Array[Transform3D]=[]
	for bone in skeleton.get_bone_count():palette.append(skeleton.get_bone_global_pose(bone)*skeleton.get_bone_global_rest(bone).affine_inverse())
	var deformed: Array[Vector3]=[]
	for i in vertices.size():
		var vertex:=Vector3.ZERO
		for k in 4:vertex+=(palette[bones[i*4+k]]*vertices[i])*weights[i*4+k]
		deformed.append(vertex)
	var growth: float=0
	for t in range(0,faces.size(),3):
		for k in 3:
			var a: int=faces[t+k]
			var b: int=faces[t+(k+1)%3]
			growth=maxf(growth,deformed[a].distance_to(deformed[b])-vertices[a].distance_to(vertices[b]))
	check(growth<.35,"slam skin has no long hand-to-leg stretch strands")
	for damage: int in [8,8,12]:
		enemy.state=enemy.State.HUNT
		enemy._hunt(.016)
		var before: float=player.health
		enemy.anim.seek(.7,true)
		enemy._attack(.016)
		enemy._attack(.016)
		check(player.health==before-damage,"attack "+enemy.attack_clip+" deals its damage once")
	var peer: Node3D=main.spawn_zombie()
	peer.set_physics_process(false)
	peer.position=enemy.position+Vector3(1,0,0)
	var speed: float=peer.hunt_speed
	enemy.rally_nearby()
	enemy.rally_nearby()
	check(get_nodes_in_group("zombies").size()==2,"clicking alerts existing zombies without spawning a group")
	check(is_equal_approx(peer.hunt_speed,speed*1.2),"calls agitate existing zombies without stacking")
	var rally: Node=peer.get_node("HollowheadRally")
	rally.remaining=0
	rally._process(.1)
	check(is_equal_approx(peer.hunt_speed,speed),"agitation expires and restores speed")
	peer.free()
	enemy.take_damage(59)
	check(enemy.frenzy and enemy.state==enemy.State.STAGGER,"low health frenzies; ordinary melee staggers")
	enemy.state=enemy.State.HUNT
	enemy.charge_cooldown=0
	player.position=Vector3(-3,0,1)
	enemy._hunt(.016)
	check(enemy.charge_windup>0,"frenzy charge telegraphs before moving")
	var locked: Vector3=enemy.charge_direction
	player.position.x+=2
	enemy._hunt(.5)
	enemy._hunt(.1)
	check(enemy.charge_direction==locked and not enemy.charge_landed,"charge commits to a direction and can be sidestepped")
	player.position=enemy.position+locked*.8
	var before: float=player.health
	enemy._hunt(.1)
	enemy._hunt(.1)
	check(player.health==before-16,"charge deals moderate damage only once")
	enemy.take_damage(15)
	check(enemy.state==enemy.State.STAGGER and enemy.charge_time==0,"stagger interrupts charge")
	enemy.free()
	await frames(3)
	player.position=Vector3(-3,0,-1)
	enemy=spawn()
	var wall:=StaticBody3D.new()
	wall.collision_layer=1
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(2,2,.15)
	shape.shape=box
	wall.add_child(shape)
	main.add_child(wall)
	wall.position=Vector3(-3,1,-1.5)
	await frames(3)
	enemy.attack_clip="swing"
	enemy.anim.play("swing",0)
	enemy.anim.seek(.7,true)
	enemy._swing_landed=false
	before=player.health
	enemy._attack(.016)
	check(player.health==before,"swipes cannot damage through a solid wall")
	enemy.take_damage(10000)
	check(player.health==before,"death spores respect solid walls")
	await frames(45)
	wall.free()
	await frames(3)
	main.health_drop_chance=1.0
	var bottles_before: int=get_nodes_in_group("health_pickups").size()
	enemy=spawn()
	before=player.health
	enemy.take_damage(10000)
	check(player.health==before-3,"nearby death burst inflicts only three damage")
	var burst: Node=get_nodes_in_group("spore_bursts")[-1]
	check(burst.exposed,"nearby death burst marks vision exposure")
	player.position=Vector3(3,0,2)
	await frames(45)
	check(get_nodes_in_group("health_pickups").size()==bottles_before+1,"Hollowhead uses the health-bottle death roll")
	check(not get_nodes_in_group("pickups").is_empty(),"Hollowhead also supplies cooking mushrooms")
	player.position=Vector3(-3,0,-.5)
	enemy=spawn(Vector3(-3,0,-2.5))
	enemy.anim.play("idle",0)
	enemy.anim.seek(0,true)
	enemy.anim.pause()
	await frames(3)
	var head: Area3D=enemy.find_child("HeadHitbox",true,false)
	var centre: Vector3=head.get_child(0).global_position
	var result: Dictionary=Hitscan.cast(enemy.get_world_3d().direct_space_state,centre+Vector3(0,0,1.5),centre-Vector3(0,0,.5))
	check(result.get("kind")=="head","head hitbox is reachable with shared weapon rays")
	enemy.take_damage(25,true)
	check(enemy.is_dead(),"a pistol-strength headshot kills Hollowhead")
	await frames(3)
	for window: Node3D in get_nodes_in_group("windows"):
		while not window.is_breached():window.rip_board()
		enemy=main.spawn_hollowhead(window)
		enemy.position=window.breach_point()
		enemy.state=enemy.State.BREACH
		await frames(180)
		check(enemy.state==enemy.State.HUNT or enemy.state==enemy.State.ATTACK,"climbs through "+window.name+" and hunts")
		enemy.free()
	main._spawned=0
	main._start_wave(1)
	main._spawn_t=0
	main.auto_spawn=true
	main._physics_process(.016)
	main.auto_spawn=false
	var roster: Array=get_nodes_in_group("zombies")
	check(roster.size()==1 and roster[0].get_script().resource_path.ends_with("hollowhead.gd"),"Hollowhead appears in common wave-one slots")
	main.free()
	await frames(3)
	print("%d failure(s)" % failures)
	quit(failures)
