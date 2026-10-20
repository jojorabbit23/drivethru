extends SceneTree
const Hitscan=preload("res://core/hitscan.gd")
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok: failures+=1
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 var win: Node3D=main.get_node("ShopGreybox/Windows/Window_A")
 # Move a real window away from scenery, isolating enemy collision from walls.
 win.global_position=Vector3(100,2,100)
 for board in win.boards: board.collision_layer=0
 for kind in ["shambler","lancer","hollowhead","scientist","scuttler"]:
  var z: CharacterBody3D=load("res://enemies/%s/%s.tscn" % [kind,kind]).instantiate()
  z.setup(win,main.player)
  main.add_child(z)
  z.set_physics_process(false)
  z.global_position=win.breach_point()
  if kind=="scuttler":z._start_dive()
  else:z._start_climb()
  for phase in 6:
   for frame in (4 if kind=="scuttler" else 8): await physics_frame
   await process_frame
   var shape: CollisionShape3D=z.get_node("Shape")
   var centre: Vector3=shape.global_position
   var result: Dictionary=Hitscan.cast(z.get_world_3d().direct_space_state,centre+Vector3(3,0,0),centre-Vector3(3,0,0))
   var body_query:=PhysicsRayQueryParameters3D.create(centre+Vector3(3,0,0),centre-Vector3(3,0,0),8)
   var body_hit: Dictionary=z.get_world_3d().direct_space_state.intersect_ray(body_query)
   check(body_hit.get("collider")==z,"%s body ray during entry phase %d" % [kind,phase])
   var hit_enemy: bool=result.get("collider")==z or (result.get("collider") is Area3D and result["collider"].get_meta("zombie")==z)
   check(hit_enemy,"shared weapon ray hits climbing enemy")
   if hit_enemy:
    var before: float=z.health
    z.take_damage(1.0)
    check(z.health==before-1.0,"entry hit removes health")
  check(z.state==z.State.CLIMB,"still in entry animation at lethal hit")
  z.take_damage(10000.0)
  check(z.is_dead(),"%s can die during entry" % kind)
  z.queue_free()
  await physics_frame
 print("Window damage: %d failure(s)" % failures)
 quit(1 if failures else 0)


