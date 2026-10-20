extends SceneTree
var failures: int=0
func _initialize() -> void:
 create_timer(25).timeout.connect(func() -> void:quit(1))
 run.call_deferred()
func check(ok: bool,message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main)
 var player: CharacterBody3D=main.player;player.set_physics_process(false)
 var garage: Node3D=main.shop.get_node("Garage")
 for i in 3:await physics_frame
 check(not garage.unlocked and get_nodes_in_group("windows").size()==2,"garage starts locked and its breach is excluded from wave selection")
 var excluded: bool=true
 for i in 64:
  if main._pick_window()==garage.get_node("Window_C"):excluded=false
 check(excluded,"repeated wave selections never target the locked garage")
 check(garage.get_node("EmptyBottles").get_child_count()==3 and garage.get_node("FungalStock").get_child_count()==5,"three empty destructible bottles and shared fridge parts decorate the shelves and boxes")
 var bike_mesh: Mesh=garage.get_node("Motorcycle/SuppliedModel").mesh
 var bike_bounds: AABB=bike_mesh.get_aabb()
 check(bike_mesh.resource_path.ends_with("motorcycle_mesh.res") and absf(bike_bounds.position.y)<.001 and absf(bike_bounds.size.z-2.35)<.001,"owner motorcycle replaces the placeholder, scaled and grounded")
 var left_edge: float=INF;var back_edge: float=-INF
 var bike: Node3D=garage.get_node("Motorcycle")
 for surface in bike_mesh.get_surface_count():
  var vertices: PackedVector3Array=bike_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
  for vertex: Vector3 in vertices:
   var world: Vector3=bike.to_global(vertex)
   left_edge=minf(left_edge,world.x);back_edge=maxf(back_edge,world.z)
 check(absf(left_edge-.25)<.015 and absf(back_edge-11.25)<.015,"both tyres meet their respective walls without the model clipping through")
 player.global_position=Vector3(1.35,.02,8.3)
 check(player.test_move(player.global_transform,Vector3(0,0,2)),"motorcycle has solid collision in its parking corner")
 main.economy.cash=249
 garage.interact(player)
 check(not garage.unlocked and main.economy.cash==249,"insufficient funds cannot open or charge for the room")
 player.global_position=Vector3(3,.02,3.9);player.camera.global_position=Vector3(3,1.6,3.9);player.camera.look_at(Vector3(3,1.2,4.9))
 await physics_frame;player._update_focus()
 check(player.focus==garage,"the fridge rear door can be targeted with the normal E interaction")
 check(player.test_move(player.global_transform,Vector3(0,0,2)),"locked connecting door blocks the player")
 main.economy.cash=300
 player.use_focus()
 check(get_nodes_in_group("windows").size()==2,"new window stays inactive while the purchased door is still opening")
 for i in 40:await physics_frame
 check(garage.unlocked and main.economy.cash==50,"E purchases the room for exactly 250")
 check(get_nodes_in_group("windows").size()==3 and garage.get_node("Window_C").boards_left()==4,"purchase activates a third fully barricaded zombie entrance")
 check(not player.test_move(player.global_transform,Vector3(0,0,2.3)),"purchased doorway opens a clear path into the garage")
 garage.interact(player)
 check(main.economy.cash==50,"repeat interaction never charges twice")
 player.global_position=Vector3(3,.02,6.1)
 check(not player.test_move(player.global_transform,Vector3(0,0,4.5)),"diagonally parked motorcycle leaves the centre aisle clear")
 player.global_position=Vector3(3,.02,9.6)
 check(player.test_move(player.global_transform,Vector3(0,0,3)),"the additional rear door remains shut and solid")
 var nav: RID=main.shop.get_node("NavigationRegion3D").get_navigation_map()
 var path: PackedVector3Array=NavigationServer3D.map_get_path(nav,Vector3(3,0,8),Vector3(3,0,2.5),true)
 check(path.size()>1 and path[-1].distance_to(Vector3(3,0,2.5))<.3,"navigation connects purchased garage to the fridge")
 var window: Node3D=garage.get_node("Window_C")
 while not window.is_breached():window.rip_board()
 check(window.repair_board() and window.boards_left()==1,"new barricade uses standard breach and repair mechanics")
 player.global_position=Vector3(3,.02,7.7)
 var enemy: Node3D=main.spawn_zombie(window)
 enemy.global_position=window.breach_point()+Vector3(0,.02,0)
 while not window.is_breached():window.rip_board()
 for i in 720:
  await physics_frame
  if enemy.global_position.x<5.4:break
 check(enemy.global_position.x<5.4,"zombie can climb through the new garage entrance")
 main.free()
 print("%d failure(s)"%failures);quit(failures)
