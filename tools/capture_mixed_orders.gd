extends SceneTree
var main: Node3D
func _initialize() -> void:
 create_timer(40).timeout.connect(func()->void:quit(1));run.call_deferred()
func shot(name: String) -> void:
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 var hud: Node=main.get_node("ClarityHUD")
 for panel: Control in [hud.order_panel,hud.grill_panel,hud.tray_panel]:
  if panel.visible:assert(panel.get_global_rect().end.x<=root.size.x-10 and panel.get_global_rect().end.y<=root.size.y-100,"mixed order HUD fits")
 root.get_texture().get_image().save_png("res://docs/previews/mixed_"+name+".png")
func run() -> void:
 root.size=Vector2i(1280,720);Engine.max_fps=30
 main=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main);main.wave=9
 main.player.set_physics_process(false);main.player.set_process_unhandled_input(false);main.player.unlock_burger_slots(9)
 main.hatch.auto=false;main.hatch.set_physics_process(false);main.serving_tray.set_physics_process(false);main.grill.set_process(false)
 var hud: Node=main.get_node("ClarityHUD");hud.clock=9
 for kinds: Array in [["brown","blue"],["double_red","blue"],["double_red","blue","brown"]]:
  main.hatch.next_orders.assign(kinds);main.hatch.next_vehicle="rugged_truck"
  var car: Node=main.hatch.spawn_customer();car._process(5);car.set_process(false)
  main.player.camera.global_position=Vector3(-3,1.65,-4.2);main.player.camera.look_at(car.global_position+Vector3(0,1.7,0));car._process(0)
  var suffix: String="regular_blue" if kinds.size()==2 and kinds[0]=="brown" else "double_blue" if kinds.size()==2 else "three_burgers"
  hud.refresh();await shot(suffix)
  if kinds.size()==3:
   main.economy.grill_level=2;main.grill._layout()
   for i in 3:
    main.grill._place(i,["red","blue","red"][i]);main.grill._kill_tween(main.grill.slots[i]);main.grill.slots[i].t=7;main.grill._enter(i,"ready")
   main.serving_tray.items[0]={"kind":"double_red","quality":"standard","age_seconds":30.0}
   main.serving_tray.items[1]={"kind":"brown","quality":"standard","age_seconds":170.0};main.serving_tray.refresh()
   main.player.camera.global_position=Vector3(1.4,1.65,-1.4);main.player.camera.look_at(Vector3(2.5,1.3,-4));hud.refresh();await shot("kitchen")
   main.player.add_burger({"kind":"blue","quality":"standard"});assert(main.hatch.serve(main.player));main._hud.toast.modulate.a=0
   main.player.camera.global_position=Vector3(-3,1.65,-4.2);main.player.camera.look_at(car.global_position+Vector3(0,1.7,0));car._process(0);hud.refresh();await shot("partial")
  car.free();main.hatch.car=null
 main.free();await process_frame;quit()
