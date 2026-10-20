extends SceneTree
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok:failures+=1
func run() -> void:
	var main: Node3D=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	var player: Node3D=main.player
	check(is_equal_approx(main.health_drop_chance,0.10),"default death roll is ten percent")
	player.health=20.0
	check(player.heal(50)==50 and player.health==70,"heals exactly fifty when injured")
	check(player.heal(50)==30 and player.health==100,"healing caps at maximum")
	check(player.heal(-10)==0 and player.health==100,"negative healing cannot damage")
	var bottle: Node3D=main.drop_health_pickup(Vector3(3,0,2))
	bottle._collect(player)
	check(not bottle._taken,"full health does not waste a bottle")
	player.health=40.0
	bottle._collect(player)
	bottle._collect(player)
	check(player.health==90 and bottle._taken,"one bottle applies fifty only once")
	await process_frame
	player.health=0.0
	bottle=main.drop_health_pickup(Vector3(3,0,2))
	bottle._collect(player)
	check(player.health==0 and not bottle._taken,"dead players cannot be revived by pickup")
	bottle.free()
	player.health=20.0
	bottle=main.drop_health_pickup(player.global_position)
	for i in 75:await physics_frame
	check(player.health==70 and not is_instance_valid(bottle),"walking near a landed bottle heals automatically")
	player.health=player.max_health
	main.health_drop_chance=1.0
	for scene: PackedScene in [main.SHAMBLER,main.SCUTTLER,main.LANCER]:
		var enemy: Node3D=main.spawn_enemy(scene)
		enemy.take_damage(10000)
	for i in 50:await physics_frame
	check(get_nodes_in_group("health_pickups").size()==3,"all three zombie types can drop health")
	check(get_nodes_in_group("pickups").size()==3,"normal mushroom drops are preserved")
	main.health_drop_chance=0.0
	var enemy: Node3D=main.spawn_enemy(main.SHAMBLER)
	enemy.take_damage(10000)
	for i in 50:await physics_frame
	check(get_nodes_in_group("health_pickups").size()==3,"failed death roll does not add a bottle")
	check(get_nodes_in_group("pickups").size()==4,"failed health roll still drops mushroom")
	main.free()
	for i in 3:await process_frame
	print("%d failure(s)" % failures)
	quit(failures)
