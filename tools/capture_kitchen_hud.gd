extends SceneTree
func _initialize() -> void:
 create_timer(35).timeout.connect(func()->void:quit(1))
 run.call_deferred()
func run() -> void:
 Engine.max_fps=30;root.size=Vector2i(1280,720)
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main);main.hatch.auto=false
 var player: Node=main.player;player.set_physics_process(false);player.set_process_unhandled_input(false)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var hud: Node=main.get_node("ClarityHUD");hud.clock=9
 main.economy.grill_level=2;main.grill._layout();main.grill.set_process(false)
 for i in 3:
  main.grill._place(i,["brown","blue","red"][i]);main.grill._kill_tween(main.grill.slots[i]);main.grill.slots[i].t=[2.0,8.0,17.0][i];main.grill._enter(i,"cooking" if i==0 else "ready");main.grill._show(i)
 main.hatch.next_order="double_red";main.hatch.next_vehicle="rugged_truck"
 var car: Node=main.hatch.spawn_customer(2);car._process(5.0);car.state="waiting";car.set_process(false)
 for view: Array in [["kitchen",Vector3(1.4,1.65,-1.4),Vector3(2.5,1.3,-4)],["order_bubble",Vector3(-3,1.65,-4.5),car.global_position+Vector3(0,1.7,0)]]:
  player.camera.global_position=view[1];player.camera.look_at(view[2]);hud.refresh()
  for i in 8:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://docs/previews/kitchen_hud_"+view[0]+".png")
 print("Kitchen HUD views captured")
 quit()
