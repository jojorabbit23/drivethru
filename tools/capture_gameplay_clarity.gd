extends SceneTree
func _initialize() -> void:
 create_timer(35).timeout.connect(func()->void:quit(1))
 run.call_deferred()
func shot(name: String) -> void:
 for i in 10:await process_frame
 await RenderingServer.frame_post_draw
 var hud: Node=root.get_node("Main/ClarityHUD") if root.has_node("Main/ClarityHUD") else null
 assert(hud!=null)
 if hud:
  for panel: Control in [hud.order_panel,hud.grill_panel,hud.tray_panel]:
   if panel.visible:assert(panel.get_global_rect().end.x<=root.size.x-10 and panel.get_global_rect().end.y<=root.size.y-100,"HUD fits within gameplay viewport")
 root.get_texture().get_image().save_png("res://docs/previews/qol_"+name+".png")
func run() -> void:
 Engine.max_fps=30;root.size=Vector2i(1280,720)
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main);main.hatch.auto=false;main.hatch.set_physics_process(false)
 var player: Node=main.player;player.set_physics_process(false);player.set_process_unhandled_input(false)
 var hud: Node=main.get_node("ClarityHUD");hud.clock=9
 main.economy.grill_level=2;main.grill._layout();main.grill.set_process(false);main.serving_tray.set_physics_process(false)
 for i in 3:
  main.grill._place(i,["brown","blue","red"][i]);main.grill._kill_tween(main.grill.slots[i]);main.grill.slots[i].t=[2.0,8.0,17.0][i];main.grill._enter(i,"cooking" if i==0 else "ready");main.grill._show(i)
 var items: Array[Dictionary]=[{"kind":"double_red","quality":"perfect","age_seconds":20.0},{"kind":"blue","quality":"good","age_seconds":70.0},{"kind":"brown","quality":"good","age_seconds":160.0},{"kind":"double_red","quality":"good","age_seconds":460.0}]
 main.serving_tray.items=items;main.serving_tray.refresh()
 main.hatch.next_order="double_red";var car: Node=main.hatch.spawn_customer(2);car._process(5.0);car.state="waiting";car.set_process(false)
 main.serving_tray.items[0]={"kind":"double_red","quality":"perfect","age_seconds":20.0};main.serving_tray.refresh();car.received=0;car.refresh_order_quantity();main._toast_t=0;main._hud.toast.modulate.a=0
 player.camera.global_position=Vector3(1.4,1.65,-1.4);player.camera.look_at(Vector3(2.5,1.3,-4));hud.refresh()
 await shot("kitchen")
 player.focus=main.grill;player.camera.global_position=main.grill.to_global(Vector3(-.43,.8,.7));player.camera.look_at(main.grill.to_global(Vector3(-.43,.03,0)))
 main.grill.flip_input(player);hud.refresh();await shot("flip")
 car.waited=car.patience-5;hud.refresh();await shot("last_call")
 for item: Dictionary in main.serving_tray.items:item.age_seconds=320.0
 hud.refresh();await shot("very_cold")
 car.queue_free();main.hatch.car=null
 for i in 4:main.serving_tray.items[i]={}
 player.focus=null;player.camera.global_position=Vector3(1.4,1.65,-1.4);player.camera.look_at(Vector3(2.5,1.3,-4));hud.refresh();await shot("idle")
 main.free();await process_frame;quit()
