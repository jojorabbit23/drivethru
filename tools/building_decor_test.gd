extends SceneTree
var failures: int=0
func check(ok: bool,message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main)
 main.player.set_physics_process(false)
 for i in 3:await physics_frame
 var decor: Node3D=main.get_node("BuildingDecorations")
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://art/building_decor/catalogue.json"))
 check(rows.size()==64 and decor.get_child_count()==64,"all 64 decorations installed")
 var ids: Dictionary={}
 for row: Dictionary in rows:
  ids[row.id]=true
  var packed: PackedScene=load("res://props/building_decor/generated/"+row.id+".tscn")
  var item: Node3D=packed.instantiate()
  check(item.position==Vector3.ZERO and item.get_meta("guide_id")==row.id,"independent placeable "+row.id)
  item.free()
 check(ids.size()==64,"unique guide IDs")
 var prop: Node3D=decor.get_node("EXT_barricade_table")
 check(preload("res://core/hitscan.gd").damage_prop({"collider":prop.get_node("DamageProxy")},100),"shared weapon hits damage prop")
 check(prop.broken and prop.get_node("DamageProxy").collision_layer==0,"broken cover stops blocking")
 var cone: Node3D=decor.get_node("EXT_barricade_cones")
 var centre: Vector3=cone.to_global(cone.hit_centre)
 var ray: Dictionary=preload("res://core/hitscan.gd").cast(main.player.get_world_3d().direct_space_state,centre+Vector3(0,0,1),centre-Vector3(0,0,1))
 check(ray.get("collider")==cone.get_node("DamageProxy"),"weapon world ray detects nonblocking decoration Area")
 cone.take_prop_damage(1)
 check(cone.knocked and cone.get_node("DamageProxy").collision_layer==0,"cone topples without persistent collision")
 var bell: Node3D=decor.get_node("WIN_bell");bell.interact(main.player)
 check(bell.rings==1,"service bell works")
 var door: Node3D=decor.get_node("BACK_freezer_door")
 check(door.linked()==main.shop.get_node("Garage") and not door.linked().unlocked,"freezer retains actual locked garage")
 check(door.prompt(main.player).contains("250"),"door retains purchase price")
 main.shop.get_node("Windows/Window_A").rip_board()
 check(decor.damage_events==1,"actual barricade signal advances wear")
 decor.apply_wear(.8)
 check(decor.get_node("WIN_sliding_window/Cracks").visible and decor.get_node("EXT_roof_sign/Letters").text=="DR VE  HR","damage wear affects window and roof lettering")
 decor.update_shift(2)
 check(decor.get_node("BACK_photo_eotm/EmployeeName").text.ends_with("DAVE?"),"employee gag progresses")
 check(get_nodes_in_group("windows").size()==2,"decorations never activate locked zombie window")
 decor.get_node("WIN_ticket_rail").interact(main.player)
 check(main.player.menu_options.size()==1,"ticket rail opens current order readout")
 main.player.close_menu()
 decor.get_node("DIN_jukebox").interact(main.player)
 check(main.player.menu_options.size()==3,"weapon shelf lists only three starting owned weapons")
 main.player.close_menu()
 main.economy.cash=250;door.interact(main.player)
 check(door.linked().unlocked and main.economy.cash==0 and door.get_node("Zone").collision_layer==0,"freezer purchase uses exact existing cost and removes overlay interaction")
 for i in 36:await physics_frame
 check(get_nodes_in_group("windows").size()==3,"garage breach activates only after paid door opens")
 print("Building decorations: ",failures," failure(s)")
 main.free();quit(1 if failures else 0)
