extends SceneTree
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1
func press_e(player: Node) -> void:
 player._update_focus()
 var key:=InputEventKey.new()
 key.physical_keycode=KEY_E
 key.pressed=true
 player._unhandled_input(key)
func bottle_for(main: Node3D) -> Node3D:
 var bottle: Node3D=main.drop_health_pickup(Vector3(3,0,-2))
 for i in 45:await physics_frame
 bottle.set_process(false)
 return bottle
func aim(player: Node3D,bottle: Node3D) -> void:
 player.global_position=Vector3(3,0.05,-0.6)
 player.camera.look_at(bottle.global_position)
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 var player: Node3D=main.player
 player.set_physics_process(false)
 check(is_equal_approx(main.health_drop_chance,0.075),"default independent death roll is 7.5 percent")
 player.health=20.0
 check(player.heal(25)==25 and player.health==45,"heals exactly twenty-five when injured")
 player.health=90.0
 check(player.heal(25)==10 and player.health==100,"healing caps at maximum")
 check(player.heal(-10)==0 and player.health==100,"negative healing cannot damage")
 var bottle: Node3D=await bottle_for(main)
 aim(player,bottle)
 await physics_frame
 player._update_focus()
 check(player.focus==bottle,"look ray targets the landed health bottle")
 check(bottle.prompt(player)=="HEALTH FULL","full-health prompt is clear")
 press_e(player)
 check(not bottle._taken,"full health does not waste a bottle")
 player.health=40.0
 check(bottle.prompt(player).contains("E") and bottle.prompt(player).contains("25 HP"),"use prompt states E and 25 HP")
 press_e(player)
 bottle.interact(player)
 check(player.health==65 and bottle._taken and player.focus==null,"pressing E applies twenty-five only once and clears its prompt")
 await process_frame
 bottle=await bottle_for(main)
 aim(player,bottle)
 await physics_frame
 player.health=0.0
 bottle.interact(player)
 check(player.health==0 and not bottle._taken,"dead players cannot use the bottle")
 player.health=20.0
 bottle.set_process(true)
 var home: Vector3=bottle._home
 MushroomPickup.auto_collect=true
 for i in 50:await physics_frame
 check(player.health==20 and is_instance_valid(bottle) and not bottle._magnet and bottle.global_position.distance_to(home)<0.1,"nearby bottle stays put and does not auto-heal even with F2")
 MushroomPickup.auto_collect=false
 bottle.set_process(false)
 player.camera.look_at(player.camera.global_position+Vector3.FORWARD)
 bottle.interact(player)
 check(player.health==20 and not bottle._taken,"looking away cannot use a bottle")
 aim(player,bottle)
 var wall:=StaticBody3D.new()
 wall.collision_layer=1
 var collision:=CollisionShape3D.new()
 var box:=BoxShape3D.new()
 box.size=Vector3(1,2,0.1)
 collision.shape=box
 wall.add_child(collision)
 main.add_child(wall)
 wall.global_position=(player.camera.global_position+bottle.global_position)*0.5
 await physics_frame
 bottle.interact(player)
 check(player.health==20 and not bottle._taken,"E cannot heal through a wall")
 wall.free()
 player.global_position.z=2.0
 player.camera.look_at(bottle.global_position)
 await physics_frame
 bottle.interact(player)
 check(player.health==20 and not bottle._taken,"E cannot heal beyond interaction range")
 aim(player,bottle)
 player.health=90
 await physics_frame
 press_e(player)
 check(player.health==100 and bottle._taken,"E bottle heals only missing HP up to maximum")
 await process_frame
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
