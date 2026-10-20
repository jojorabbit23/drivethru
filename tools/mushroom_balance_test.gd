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
 main.player.set_physics_process(false)
 var scuttler: Node=load("res://enemies/scuttler/scuttler.gd").new()
 var lancer: Node=load("res://enemies/lancer/lancer.gd").new()
 main.economy.stock={"brown":0,"blue":0,"red":0}
 main.player.carried={"brown":0,"blue":0,"red":0}
 var base: Dictionary=main.drop_weights(null)
 check(is_equal_approx(base.blue,.2),"empty or equal stock retains original drop odds")
 main.economy.stock={"brown":20,"blue":0,"red":20}
 var scarce: Dictionary=main.drop_weights(null)
 check(scarce.blue>.45 and scarce.blue<.5,"scarce blue gets a substantial bounded boost over twenty percent")
 main.player.carried.blue=20
 check(is_equal_approx(main.drop_weights(null).blue,.2),"carried supplies count before storage")
 main.player.carried.blue=0
 var loose: Node3D=main.drop_pickup(Vector3(30,0,30),"blue")
 loose.value=20
 check(is_equal_approx(main.drop_weights(null).blue,.2),"uncollected drops prevent needless overcorrection")
 loose._taken=true
 check(main.drop_weights(null).blue>.45,"collected pickups no longer count twice")
 loose.free()
 main._pending_mushrooms.blue=20
 check(is_equal_approx(main.drop_weights(null).blue,.2),"pending delayed drops count during rapid kills")
 main._pending_mushrooms.blue=0
 main.economy.stock={"brown":20,"blue":20,"red":0}
 var yellow: Dictionary=main.drop_weights(scuttler)
 check(yellow.red>.6 and not yellow.has("brown"),"scarce yellow becomes more likely from Scuttlers")
 main.economy.stock={"brown":0,"blue":20,"red":20}
 check(main.drop_weights(null).brown>.9,"common mushrooms also receive shortage protection")
 check(main.drop_weights(lancer)=={"red":1.0},"Lancer guaranteed yellow drop is preserved")
 seed(7164)
 var counts: Dictionary={"brown":0,"blue":0}
 for i in 2000:counts[main.drop_kind(null)]+=1
 check(counts.brown>1800 and counts.blue>0,"actual weighted selection retains randomness and enemy drop pool")
 main.economy.stock={"brown":20,"blue":0,"red":20}
 counts={"brown":0,"blue":0}
 for i in 2000:counts[main.drop_kind(null)]+=1
 check(counts.blue>850 and counts.blue<1050,"actual drops reflect scarcity probabilities")
 var enemy: Node3D=main.spawn_zombie()
 main.health_drop_chance=0
 enemy.take_damage(10000)
 var pending: int=0
 for k: String in main._pending_mushrooms:pending+=int(main._pending_mushrooms[k])
 check(pending==1,"one mushroom is reserved per real death")
 for i in 45:await physics_frame
 pending=0
 for k: String in main._pending_mushrooms:pending+=int(main._pending_mushrooms[k])
 check(pending==0 and get_nodes_in_group("pickups").size()==1,"reservation becomes exactly one normal pickup")
 scuttler.free();lancer.free();main.free()
 print("%d failure(s)" % failures)
 quit(failures)

