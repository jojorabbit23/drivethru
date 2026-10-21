extends SceneTree
const Items=preload("res://game/burger_items.gd")
var failures: int=0
func _initialize() -> void:
 create_timer(45).timeout.connect(func()->void:quit(1))
 run.call_deferred()
func check(ok: bool,message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main)
 var d: Node3D=main.delivery;var p: Node3D=main.player;var garage: Node3D=main.shop.get_node("Garage")
 p.set_physics_process(false);p.unlock_burger_slots(9);main.grill.set_process(false)
 main.economy.cash=1000
 d.interact(p)
 check(not d.unlocked and d.spawn_customer()==null and main.economy.cash==1000,"garage must be purchased before delivery can be bought or receive orders")
 garage.interact(p)
 for i in 40:await physics_frame
 main.economy.cash=199;d.interact(p)
 check(not d.unlocked and main.economy.cash==199,"delivery purchase rejects insufficient funds without charging")
 p.global_position=Vector3(4.7,.02,6.25);p.camera.global_position=Vector3(4.7,1.6,6.25);p.camera.look_at(Vector3(5.7,1.6,6.25))
 await physics_frame;p._update_focus();check(p.focus==d,"locked hatch is reachable with the normal look-and-E interaction")
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(4.7,1.6,6.25),Vector3(6.5,1.6,6.25),1)
 var hit: Dictionary=p.get_world_3d().direct_space_state.intersect_ray(ray)
 check(not hit.is_empty() and hit.collider==d.shutter_block,"closed shutter physically stops bullets at the new opening")
 main.economy.cash=500;p.use_focus()
 check(d.unlocked and main.economy.cash==300 and d.serving_tray.items.size()==4,"E purchases separate four-slot delivery tray for $200")
 var all_slots: bool=true
 p.camera.global_position=Vector3(4.4,1.65,6.25)
 for i in 4:
  var slot: Node3D=d.serving_tray.get_node("BoxSlot%d"%(i+1))
  p.camera.look_at(slot.global_position+Vector3(0,.06,0))
  await physics_frame;p._update_focus()
  all_slots=all_slots and p.focus==slot
  p.add_burger({"kind":"brown","quality":"perfect","age_seconds":160.0});p.use_focus()
  all_slots=all_slots and not d.serving_tray.items[i].is_empty()
  p.use_focus();all_slots=all_slots and p.held=="burger" and p.held_burger.age_seconds>=160
  p.take_selected_burger()
 check(all_slots,"all four tray slots can be targeted, stocked and retrieved with E without hatch intercepting")
 for i in 40:await physics_frame
 check(not d.shutter.visible and d.shutter_block.collision_layer==0,"opening animation removes shutter collision with the visible shutter")
 d.interact(p);check(main.economy.cash==300 and main.bench.delivery_selected,"phone tracks delivery prep without repeat charge")
 check(get_nodes_in_group("windows").size()==3 and garage.get_node("RearDoorClosed").collision_layer==1,"delivery adds no zombie breach and leaves far door closed")
 d.next_orders.assign(["double_red","blue"]);var ticket: Node=d.spawn_customer();ticket.set_process(false)
 main.hatch.next_order="brown";var car: Node=main.hatch.spawn_customer();car.state="waiting";car.set_process(false)
 check(ticket.patience>=120 and ticket.patience>car.patience*2 and car.wants("brown") and ticket.wants("blue"),"independent car and phone orders coexist with a longer delivery deadline")
 d._physics_process(.1);check(d.ring.playing and d.ring.stream.get_length()>1.0,"new phone ticket produces positional double ring")
 d.interact(p);check(not d.ring.playing,"answering phone acknowledges and silences repeat ringing")
 main.grill._place(0,"red");main.grill._kill_tween(main.grill.slots[0]);main.grill.slots[0].t=7;main.grill._enter(0,"ready")
 var plan: Dictionary=main.bench.plan()
 check(not plan.has("picks") and plan.order=="double_red","delivery prep preserves a lone Yellow for its double")
 var key:=InputEventKey.new();key.physical_keycode=KEY_G;key.pressed=true;p._unhandled_input(key)
 check(not main.bench.delivery_selected and main.rail.hatch==main.hatch and main.bench.plan().has("picks"),"G switches prep and paper ticket back to car without changing either order")
 p._unhandled_input(key)
 main.grill._place(1,"red");main.grill._kill_tween(main.grill.slots[1]);main.grill.slots[1].t=7;main.grill._enter(1,"ready")
 check(main.bench.bag(p) and p.held_burger.kind=="double_red","same prep bench assembles requested delivery double")
 d.serving_tray.set_physics_process(false)
 var cash: int=main.economy.cash
 d.serving_tray.items[0]={"kind":"blue","quality":"standard","age_seconds":160.0}
 d.serving_tray.items[1]={"kind":"blue","quality":"perfect","age_seconds":10.0}
 check(d.collect_from_tray()==1 and d.serving_tray.items[0].age_seconds==160.0 and d.serving_tray.items[1].is_empty(),"phone tray chooses fresh exact recipe before cold duplicate")
 check(ticket.received==1 and car.received==0 and main.serving_tray.items[0].is_empty(),"delivery takes only its own tray and leaves car ticket untouched")
 check(d.serve(p) and ticket.state=="leaving" and d.collect_from_tray()==0,"manual final item completes phone order once")
 ticket.free();d.car=null
 var b: Dictionary=d.serving_tray.items[0];var id_before: float=Items.age(b)
 check(d.serving_tray.pick_up(p,0) and p.held_burger.age_seconds==id_before,"cold tray retrieval retains original timer")
 var bin: Node=d.get_node("DeliveryBin");check(bin.discard(p) and bin.discarded==1,"delivery bin discards chosen carried burger")
 d.next_order="blue";ticket=d.spawn_customer();ticket.set_process(false);p.add_burger({"kind":"blue","quality":"standard","age_seconds":160.0})
 cash=main.economy.cash;d.serve(p)
 check(main.economy.cash-cash==15,"cold phone order has same 50 percent per-item penalty")
 ticket.free();d.car=null;d.next_order="brown";ticket=d.spawn_customer();ticket.set_process(false)
 p.add_burger({"kind":"blue","quality":"perfect"});cash=main.economy.cash
 check(not d.serve(p) and main.economy.cash==cash and p.held=="burger","wrong phone recipe is not consumed or paid")
 p.take_selected_burger();ticket.waited=ticket.patience-.01;ticket._process(.02)
 check(ticket.state=="leaving" and main.economy.cash==cash and d._next>=35,"expired phone order pays nothing and schedules separate next call")
 ticket.free();d.car=null
 # Flip timing is attached to the patty, survives warmer and assembly, then pays identically on both channels.
 main.grill._clear(0);main.grill._place(0,"brown");main.grill._kill_tween(main.grill.slots[0]);main.grill.slots[0].t=3
 check(main.grill.flip(0),"halfway flip accepted")
 main.grill._kill_tween(main.grill.slots[0]);main.grill.slots[0].t=7;main.grill._enter(0,"ready")
 main.economy.has_tray=true;main.tray.store_from_grill()
 check(main.tray.held[0].flip_fraction==.5,"warmer preserves actual flip fraction")
 main.bench.select_delivery(false);main.bench.bag(p)
 check(p.held_burger.good_flip and Items.payment(p.held_burger)[1]==8,"prompt boxing with every patty flipped at 40–60 percent adds $2 tip")
 var hud: Node=main.get_node("ClarityHUD");hud.refresh();check(hud.delivery_panel.visible and hud.delivery_text.text.contains("PREP: CAR"),"independent delivery HUD reports active prep ticket")
 p.take_selected_burger()
 d.serving_tray.items[0]={"kind":"blue","quality":"perfect","good_flip":true,"age_seconds":0.0}
 d.next_order="blue";d._next=.001;d.auto=true;cash=main.economy.cash
 d._physics_process(.02)
 check(is_instance_valid(d.car) and d.car.state=="leaving" and main.economy.cash-cash==40 and car.received==0,"automatic phone arrival buys pre-stocked food with accurate-flip and advance-preparation tips, without car interaction")
 main.free();for i in 3:await process_frame
 print("%d failure(s)"%failures);quit(failures)
