extends SceneTree
func _initialize() -> void:
 create_timer(25).timeout.connect(func()->void:quit(1))
 run.call_deferred()
func snap(label: String) -> void:
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://docs/previews/grill_recovery_"+label+".png")
func run() -> void:
 Engine.max_fps=30;root.size=Vector2i(1280,720)
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main);main.hatch.auto=false
 var player: Node=main.player;player.set_physics_process(false);player.set_process_unhandled_input(false)
 for w: Node3D in player.weapons:w.hide();w.set_physics_process(false)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var grill: Node=main.grill;grill.set_process(false);grill._layout()
 for i in 2:
  grill._place(i,"brown" if i==0 else "blue")
  grill._kill_tween(grill.slots[i]);grill.slots[i].t=2.0;grill._enter(i,"cooking")
 var at: Vector3=grill.slots[0].root.global_position+Vector3(0,.03,0)
 player.camera.global_position=at+Vector3(0,1.2,1.0);player.camera.look_at(at)
 player.focus=grill
 player.use_focus()
 assert(grill.slots[0].flipped)
 await snap("flip")
 player.use_focus()
 assert(grill.state_of(0)=="" and get_nodes_in_group("discarded_grill_patties").size()==1,"second tap produces one waste visual")
 var waste: Node3D=get_nodes_in_group("discarded_grill_patties")[0]
 player.camera.look_at(grill.global_position+Vector3(0,-.35,.55))
 await create_timer(.55).timeout
 await snap("floor")
 assert(waste.global_position.y<.06,"waste reaches floor")
 assert(grill.state_of(1)=="cooking","other patty stays on grill")
 assert(waste.find_children("*","CollisionObject3D",true,false).is_empty(),"floor waste has no colliders")
 await create_timer(7.5).timeout
 assert(not is_instance_valid(waste),"floor waste cleans up")
 print("Grill recovery visual: 0 failure(s)")
 quit()
