extends SceneTree
func _initialize() -> void:
 create_timer(35).timeout.connect(func() -> void:quit(1))
 run.call_deferred()
func picture(name: String) -> void:
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/clarity_"+name+".png"))
func run() -> void:
 Engine.max_fps=30;root.size=Vector2i(1280,720)
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main);main.hatch.auto=false
 var player: Node3D=main.player;player.set_physics_process(false);player.set_process(false);player.set_process_unhandled_input(false)
 for w: Node3D in player.weapons:w.hide();w.set_physics_process(false)
 var hud: Node=main.get_node("ClarityHUD");hud.clock=10
 main.economy.grill_level=2;main.grill._layout();main.grill.set_process(false)
 var states: Array=["raw","cooking","ready","burnt"]
 for i in 4:
  main.economy.stock.brown+=1;main.grill.add_patty("brown");main.grill._kill_tween(main.grill.slots[i]);main.grill.slots[i].patty.position.y=0.06;main.grill.slots[i].patty.scale=main.grill.SMASHED;main.grill.slots[i].t=[0.0,3.5,8.0,25.0][i];main.grill._enter(i,states[i]);main.grill._show(i)
 player.global_position=Vector3(2.1,0.1,-3.2);var camera: Camera3D=player.camera;camera.global_position=Vector3(2.0,1.6,-3.0);camera.look_at(main.grill.global_position+Vector3(0,0.05,0));camera.fov=65
 await picture("cooking_states")
 main.hatch.next_order="red";var car: Node3D=main.hatch.spawn_customer(3);car._process(5.0);car.set_process(false);car.received=1;car.waited=35
 player.global_position=Vector3(3,0.1,1.8);camera.global_position=Vector3(3,1.6,1.8);camera.look_at(Vector3(3,1.3,-2.4));player.health=20;player.weapons[0].mag=1;player.weapons[0].reserve=0;main._update_health();main._update_weapon();hud.on_hurt(8,main.grill);hud.refresh()
 await picture("critical_order")
 player.health=100;player.weapons[0].mag=12;player.weapons[0].reserve=36;main._update_health();main._update_weapon();hud.refresh()
 main._toast_t=0.0;main._hud.toast.modulate.a=0.0
 await picture("quiet_hud")
 var window: Node3D=main.get_node("ShopGreybox/Windows/Window_B");window.rip_board();player.focus=null
 player.global_position=window.repair_point()+Vector3(0,0.05,0);camera.global_position=player.global_position+Vector3(0,1.6,0);camera.look_at(window.global_position)
 await physics_frame;await physics_frame
 player._update_repair(0.1)
 await picture("repair_target")
 camera.rotate_y(PI);player._update_repair(0.1)
 await picture("repair_away")
 var key:=InputEventKey.new();key.physical_keycode=KEY_F1;key.pressed=true
 player.get_node("Presentation")._unhandled_key_input(key)
 assert(player.get_node("Presentation").help_panel.visible)
 await picture("controls")
 main.free();for i in 3:await process_frame
 print("PASS clarity cooking, critical HUD, order and quiet HUD renders");quit()
