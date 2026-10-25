extends SceneTree
const Hitscan = preload("res://core/hitscan.gd")
var failures: int=0
var main: Node3D
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func frames(count: int) -> void:
 for i in count:await physics_frame
func spawn() -> Node3D:
 var enemy: Node3D=main.spawn_scientist()
 enemy.set_physics_process(false)
 enemy.global_position=Vector3(-3,.02,-2)
 enemy.rotation.y=PI
 return enemy
func skin_check(enemy: Node3D) -> void:
 var mesh: ArrayMesh=enemy.get_node("Model/Skeleton3D/Body").mesh
 var arrays: Array=mesh.surface_get_arrays(0)
 var v: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var faces: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var normalized: bool=true
 for i in range(0,weights.size(),4):
  if absf(weights[i]+weights[i+1]+weights[i+2]+weights[i+3]-1)>.001:normalized=false
 check(normalized,"all scientist skin weights are normalized")
 var skeleton: Skeleton3D=enemy.get_node("Model/Skeleton3D")
 var worst: float=0
 var contact_error: float=0
 for name: String in ["idle","shamble","swing","rip","climb","flinch","death"]:
  check(enemy.anim.has_animation(name),"authored "+name+" clip available")
  if name=="death":
   arrays=load("res://enemies/scientist/scientist_body.res").surface_get_arrays(0)
   v=arrays[Mesh.ARRAY_VERTEX];bones=arrays[Mesh.ARRAY_BONES];weights=arrays[Mesh.ARRAY_WEIGHTS];faces=arrays[Mesh.ARRAY_INDEX]
  var clip: Animation=enemy.anim.get_animation(name)
  for phase: float in [.0,.25,.5,.75,.99]:
   skeleton.reset_bone_poses()
   enemy.anim.play(name,0);enemy.anim.seek(phase*clip.length,true);skeleton.force_update_all_bone_transforms()
   var palette: Array=[]
   for bone in skeleton.get_bone_count():palette.append(skeleton.get_bone_global_pose(bone)*skeleton.get_bone_global_rest(bone).affine_inverse())
   var posed:=PackedVector3Array()
   var low: float=INF
   for i in v.size():
    var point:=Vector3.ZERO
    for k in 4:point+=(palette[bones[i*4+k]]*v[i])*weights[i*4+k]
    posed.append(point);low=minf(low,point.y)
   if name!="climb":contact_error=maxf(contact_error,absf(low))
   for tri in range(0,faces.size(),3):
    for k in 3:
     var a: int=faces[tri+k];var b: int=faces[tri+(k+1)%3]
     worst=maxf(worst,posed[a].distance_to(posed[b])-v[a].distance_to(v[b]))
 check(worst<.22,"coat and hands remain joined without long stretched spikes (%.3f m)"%worst)
 check(contact_error<.065,"grounded clips keep contact with floor (%.3f m error)"%contact_error)
 enemy.anim.play("idle",0);enemy.anim.seek(0,true)
func run() -> void:
 seed(940)
 main=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main)
 var player: Node3D=main.player
 player.set_physics_process(false)
 player.global_position=Vector3(-3,.02,-1)
 player.health=player.max_health
 var enemy: Node3D=spawn()
 check(enemy.health==100 and enemy.attack_damage==12 and enemy.is_in_group("zombies"),"balanced scientist enters the regular infected roster")
 check(enemy.get_node("Model/Skeleton3D/Body").mesh.resource_path.ends_with("scientist_live.res") and not enemy.get_node("Model/Skeleton3D/NeckStump").visible,"living scientist uses intact skin with no exposed cut surface")
 skin_check(enemy)
 var skeleton_walk: Skeleton3D=enemy.get_node("Model/Skeleton3D")
 for side: String in ["r","l"]:
  var previous:=Vector3.ZERO
  var planted: bool=true
  for phase: float in [.08,.2,.35,.5]:
   var time: float=phase if side=="r" else phase+.5
   enemy.anim.play("shamble",0);enemy.anim.seek(fposmod(time,1.0),true);skeleton_walk.force_update_all_bone_transforms()
   var foot_pose: Transform3D=skeleton_walk.get_bone_global_pose(skeleton_walk.find_bone("foot_"+side))
   var point: Vector3=foot_pose.origin-Vector3.BACK*(.95*time)
   if phase>.08 and absf(point.z-previous.z)>.008:planted=false
   if foot_pose.basis.y.dot(Vector3.UP)<.999:planted=false
   previous=point
  check(planted,"support boot "+side+" remains flat and planted as the character advances")
 enemy.take_damage(10,true)
 check(enemy.health==70 and enemy.state==enemy.State.STAGGER,"fungal head is vulnerable and heavy hits stagger")
 enemy.state=enemy.State.ATTACK;enemy._swing_landed=false
 enemy.anim.play("swing",0);enemy.anim.seek(.63,true)
 var health: float=player.health
 enemy._attack(.016);enemy._attack(.016)
 check(player.health==health-12,"scientist claw strike hits only once per swing")
 enemy.free()
 enemy=spawn()
 enemy.anim.play("idle",0);enemy.anim.seek(0,true)
 var skeleton: Skeleton3D=enemy.get_node("Model/Skeleton3D")
 skeleton.force_update_all_bone_transforms()
 var head_centre: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("head"))*Vector3(0,.27,0)
 await frames(2)
 var hit: Dictionary=Hitscan.cast(main.get_world_3d().direct_space_state,head_centre+Vector3(0,0,2),head_centre-Vector3(0,0,1),[player.get_rid()])
 check(not hit.is_empty() and hit.get("kind","")=="head" and hit["collider"].get_meta("zombie")==enemy,"actual hitscan recognizes the scientist head")
 var deaths: Array[int]=[0]
 enemy.died.connect(func(_enemy: Node):deaths[0]+=1)
 main.health_drop_chance=1.0
 var cash: int=main.economy.cash
 var ooze: Node3D=enemy.Ooze.get_fx(enemy)
 var sprays_before: int=ooze.stats.sprays
 enemy.take_damage(1000,false,{"dir":Vector3(0,0,-1)})
 enemy.take_damage(1000)
 check(ooze.stats.sprays==sprays_before+1 and ooze.droplets.size()>0 and ooze.droplets.size()<=ooze.MAX_DROPLETS,"one bounded neck splatter burst, never duplicated by corpse damage")
 check(deaths[0]==1 and enemy.is_dead() and not enemy.is_in_group("zombies") and enemy.collision_layer==0,"death and rewards occur only once, corpse stops blocking combat")
 check(not enemy.get_node("Model/Skeleton3D/DetachableHead/Head").visible and enemy.get_node("Model/Skeleton3D/Body").mesh.resource_path.ends_with("scientist_body.res") and enemy.get_node("Model/Skeleton3D/NeckStump").visible,"cut body and closed stump only appear on death")
 var heads: Array=get_nodes_in_group("scientist_heads")
 check(heads.size()==1,"one complete mushroom head detaches")
 var head: RigidBody3D=heads[0]
 check(head.collision_layer==0 and head.collision_mask==1 and not head.is_in_group("zombies"),"cosmetic head collides with scenery, never players or enemies")
 var height: float=head.global_position.y
 player.global_position=Vector3(10,0,10)
 await frames(90)
 check(head.global_position.y<height-.25,"detached head falls under gravity")
 check(head.impacted and head.global_position.y>0.03,"detached head lands against the world instead of falling through it")
 check(main.economy.cash==cash+main.Economy.KILL_CASH and get_nodes_in_group("pickups").size()==1 and get_nodes_in_group("health_pickups").size()==1,"one normal kill reward, mushroom and forced health roll; no bonus loot from head")
 for i in 7:
  var other: Node3D=spawn();other.take_damage(1000)
 await frames(2)
 check(get_nodes_in_group("scientist_heads").size()<=6,"simultaneous cosmetic physics heads are capped at six")
 await frames(330)
 check(get_nodes_in_group("scientist_heads").is_empty(),"detached heads clean themselves up")
 for old: Node in main.get_children():
  if old is CharacterBody3D and old!=player:old.free()
 for window: Node3D in get_nodes_in_group("windows"):
  while not window.is_breached():window.rip_board()
  enemy=main.spawn_scientist(window)
  enemy.global_position=window.breach_point()
  enemy.state=enemy.State.BREACH
  await frames(180)
  check(enemy.state==enemy.State.HUNT or enemy.state==enemy.State.ATTACK,"scientist climbs through "+window.name+" and hunts")
  enemy.free()
 # scientists join at main.scientist_from_wave (one new enemy type per wave)
 var w: int=main.scientist_from_wave
 main._spawned=3;main._start_wave(w);main._spawn_t=0;main.auto_spawn=true
 main._physics_process(.016);main.auto_spawn=false
 var roster: Array=get_nodes_in_group("zombies")
 check(roster.size()==1 and roster[0].get_script().resource_path.ends_with("scientist.gd") and main._wave_left==main.wave_size(w)-1,"scientist uses one scheduled wave slot, never an extra swarm")
 main.free()
 await frames(3)
 print("%d failure(s)"%failures)
 quit(1 if failures else 0)
