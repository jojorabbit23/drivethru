extends SceneTree
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main)
 main.hatch.auto=false
 var player: Node3D=main.player;player.set_physics_process(false);player.set_process(false)
 var hud: Node=main.get_node("ClarityHUD");hud.set_process(false)
 var window: Node3D=main.get_node("ShopGreybox/Windows/Window_A")
 player.global_position=window.repair_point()+Vector3(0,0.05,0);player.focus=null
 window.rip_board();await physics_frame;await physics_frame
 player.camera.look_at(window.global_position);player._update_repair(0.1)
 check(player.repair_window==window,"aiming at nearby damaged window selects it")
 Input.action_press("interact");player._update_repair(0.3)
 check(player.repair_progress>0.0,"aimed repair makes progress")
 player.camera.rotate_y(PI);player._update_repair(0.1)
 check(player.repair_window==null and player.repair_progress==0.0,"looking away clears repair target and progress")
 player.camera.look_at(window.global_position)
 var blocker:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(0.25,2,2);shape.shape=box;blocker.add_child(shape);root.add_child(blocker);blocker.global_position=(player.camera.global_position+window.global_position)*0.5
 await physics_frame;await physics_frame;player._update_repair(0.1)
 check(player.repair_window==null,"solid geometry blocks repair selection")
 blocker.free();Input.action_release("interact")
 main.hatch.next_order="red";var car: Node3D=main.hatch.spawn_customer(3);car._process(5.0);car.set_process(false);car.received=1;car.waited=12.0
 player.global_position=Vector3(-3,0.1,2.4);hud.refresh()
 check(hud.order_panel.visible and "YELLOW" in hud.order_name.text and "2" in hud.order_name.text,"order persists in other rooms with remaining quantity")
 check(hud.wait_label.text.contains("38s"),"order card reports actual remaining patience")
 car.free();hud.refresh();check(not hud.order_panel.visible,"departed/freed customer clears order card safely")
 player.health=20;hud.refresh();check(hud.health_warning.visible,"critical health has explicit warning")
 player.weapons[0].mag=0;player.weapons[0].reserve=10;hud.refresh();check(hud.ammo_warning.text=="R  RELOAD","empty magazine prompts reload")
 player.weapons[0].reserve=0;hud.refresh();check(hud.ammo_warning.text=="OUT OF AMMO","zero total ammo is distinct")
 hud.clock=9;hud.refresh();check(hud.help.text=="F1  CONTROLS","intro help collapses to F1 reminder")
 player.health=0;hud.refresh();check(not hud.order_panel.visible and not hud.health_warning.visible and hud.ammo_warning.text.is_empty(),"death clears action warnings")
 main.economy.stock.brown=2;main.grill.add_patty("brown");main.grill.add_patty("brown")
 player.camera.global_rotation=Vector3.ZERO
 check(main.grill.prompt(player).contains("leave patties to cook"),"full raw grill never claims patties are ready")
 main.free();for i in 3:await process_frame
 print(failures," failure(s)");quit(1 if failures else 0)
