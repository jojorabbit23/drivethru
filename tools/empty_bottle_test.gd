extends SceneTree
var failures: int=0
const Bottle=preload("res://props/empty_bottle/empty_bottle.gd")
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func fresh(at: Vector3) -> StaticBody3D:
 var b:=StaticBody3D.new();b.set_script(Bottle);var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=0.045;cylinder.height=0.27;shape.shape=cylinder;shape.position.y=0.135;b.add_child(shape);root.add_child(b);b.global_position=at;return b
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main)
 var player: Node3D=main.player;player.set_physics_process(false);player.set_process(false)
 for w: Node3D in player.weapons:w.set_physics_process(false)
 check(get_nodes_in_group("destructible_props").size()==3,"three decorative bottles placed")
 var camera: Camera3D=player.camera;camera.global_position=Vector3(0,5,0);camera.global_rotation=Vector3.ZERO
 var before: int=get_nodes_in_group("zombies").size()
 var b: StaticBody3D=fresh(Vector3(0,4.865,-0.65))
 await physics_frame;await physics_frame
 player.weapons[0].shoot()
 check(b.broken and b.collision_layer==0,"pistol shatters bottle and removes its blocker")
 b.take_prop_damage(10);check(b.broken,"repeated pellet damage stays idempotent")
 b.free()
 camera.global_rotation=Vector3.ZERO
 b=fresh(Vector3(0,4.865,-0.65));await physics_frame;await physics_frame
 var knife: Node3D=player.weapons[1];knife._attack_kind="slash";knife._strike()
 check(b.broken,"knife slash breaks bottle")
 b.free();camera.global_rotation=Vector3.ZERO
 b=fresh(Vector3(0,4.865,-0.65));await physics_frame;await physics_frame
 var pump: Node3D=load("res://weapons/shotgun/shotgun_weapon.gd").new();player.add_weapon(pump);pump.set_physics_process(false)
 pump._draw_t=0;pump._cycle=0;pump.shoot();check(b.broken,"pump shotgun breaks bottle")
 b.free();camera.global_rotation=Vector3.ZERO
 b=fresh(Vector3(0,4.865,-0.65));await physics_frame;await physics_frame
 var sawn: Node3D=player.weapons[2];sawn.active=true;sawn.state="idle";sawn.cooldown=0;sawn.shoot();check(b.broken,"sawn-off breaks bottle")
 b.free()
 check(get_nodes_in_group("zombies").size()==before,"bottles never join zombie counts")
 main.free()
 await create_timer(1.0).timeout
 print(failures," failure(s)");quit(1 if failures else 0)
