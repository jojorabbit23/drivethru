extends SceneTree
const Progress=preload("res://game/order_progression.gd")
var failures: int=0
func _initialize() -> void:
 create_timer(40).timeout.connect(func()->void:quit(1))
 run.call_deferred()
func check(ok: bool,message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1
func run() -> void:
 var rng:=RandomNumberGenerator.new();rng.seed=9314
 var averages: Array[float]=[];var mixed_counts: Array[int]=[]
 for wave in [1,3,6,9,20]:
  var mixed: int=0;var revenue: int=0;var valid: bool=true
  for i in 600:
   var kinds: Array[String]=Progress.generate(wave,0,rng);var unique: Dictionary={}
   for kind in kinds:unique[kind]=true;revenue+=preload("res://game/recipes.gd").price(kind)
   if unique.size()>1:mixed+=1
   valid=valid and kinds.size()<=3 and kinds.size()>0 and (wave>=6 or kinds.size()<=2)
   if wave<6:
    for kind in kinds:valid=valid and preload("res://game/recipes.gd").is_single(kind)
  check(valid,"bounded order size and early recipe limits at wave %d"%wave)
  averages.append(revenue/600.0);mixed_counts.append(mixed)
 check(mixed_counts[0]==0 and mixed_counts[1]>200 and mixed_counts[3]>450,"mixed demand appears gradually from wave 3")
 check(averages[0]<averages[1] and averages[1]<averages[2] and averages[2]<averages[3],"average earning opportunity rises with wave tiers")
 var pair: Array[String]=["double_red","blue"]
 check(Progress.patience_bonus(pair,6)>0 and Progress.patience_bonus(pair,15)<Progress.patience_bonus(pair,6),"larger orders get time allowance that tightens later")
 check(Progress.gap(1,18,32)==Vector2(18,32) and Progress.gap(20,18,32)==Vector2(12,20),"arrival gaps tighten with a bounded late-game floor")
 var grouped: Node=preload("res://game/customer_car.gd").new()
 var grouped_kinds: Array[String]=["brown","blue","brown"];grouped.configure_order(grouped_kinds)
 check(grouped.ticket_text()=="R X2\nB X1" and grouped.record_delivery("brown") and grouped.ticket_text()=="R X1\nB X1","repeated recipe lines aggregate and decrement individually")
 check(grouped.record_delivery("blue") and grouped.record_delivery("brown") and not grouped.record_delivery("brown"),"order book cannot overfill or duplicate delivery credit")
 grouped.free()
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main);main.wave=9
 main.player.set_physics_process(false);main.player.unlock_burger_slots(9);main.hatch.auto=false;main.hatch.set_physics_process(false);main.serving_tray.set_physics_process(false);main.grill.set_process(false)
 main.economy.cash=0
 main.hatch.next_orders.assign(["double_red","blue","brown"])
 var car: Node=main.hatch.spawn_customer();car.state="waiting";car.set_process(false)
 check(car.quantity==3 and car.ticket_text()=="DBL Y X1\nB X1\nR X1","three distinct recipe lines keep burger and patty counts separate")
 main.player.add_burger({"kind":"blue","quality":"standard"})
 check(main.hatch.serve(main.player) and car.received==1 and car.order=="double_red" and not car.wants("blue"),"manual delivery accepts any outstanding recipe exactly once")
 main.player.add_burger({"kind":"blue","quality":"standard"});var cash: int=main.economy.cash
 check(not main.hatch.serve(main.player) and main.economy.cash==cash and main.player.held=="burger","already-fulfilled recipe is rejected without consuming food or paying twice")
 main.player.take_selected_burger()
 main.serving_tray.items[0]={"kind":"blue","quality":"standard","age_seconds":0.0}
 main.serving_tray.items[1]={"kind":"double_red","quality":"standard","age_seconds":160.0}
 main.serving_tray.items[2]={"kind":"brown","quality":"standard","age_seconds":0.0}
 check(main.hatch.collect_from_tray()==2 and car.state=="leaving" and main.economy.cash==85,"tray completes remaining mixed recipes and applies per-item cold penalty")
 check(not main.serving_tray.items[0].is_empty() and main.hatch.collect_from_tray()==0,"unrequested tray food remains and completed customer cannot pay again")
 car.free();main.hatch.car=null
 for i in 4:main.serving_tray.items[i]={}
 main.hatch.next_orders.assign(["brown","double_blue"]);car=main.hatch.spawn_customer();car.state="waiting";car.set_process(false)
 main.grill._place(0,"blue");main.grill._kill_tween(main.grill.slots[0]);main.grill.slots[0].t=7;main.grill._enter(0,"ready")
 var plan: Dictionary=main.bench.plan()
 check(not plan.has("picks") and plan.order=="double_blue","prep reserves a lone Blue patty for requested double instead of boxing a wrong single")
 main.grill._place(1,"blue");main.grill._kill_tween(main.grill.slots[1]);main.grill.slots[1].t=7;main.grill._enter(1,"ready")
 var buns: int=main.economy.buns
 check(main.bench.bag(main.player) and main.player.held_burger.kind=="double_blue" and main.economy.buns==buns-1,"prep boxes a complete later recipe with one bun and two patties")
 check(main.hatch.serve(main.player) and car.order=="brown","serving double first leaves Regular outstanding")
 var hud: Node=main.get_node("ClarityHUD");hud.refresh()
 check(hud.order_name.text=="R X1" and not hud.extra_orders[0].visible and not car._mixed_rows[1].root.visible,"HUD and speech bubble clear fulfilled lines")
 var stored: Array[Dictionary]=[]
 for b: Dictionary in main.serving_tray.items:stored.append(b.duplicate())
 main.serving_tray.items[0]={"kind":"red","quality":"standard","age_seconds":160.0,"discount":true}
 main.serving_tray.items[1]={"kind":"blue","quality":"standard","age_seconds":20.0}
 check(main.serving_tray.take_matching("double_red",false).is_empty() and not main.serving_tray.items[0].is_empty(),"exact-match scan cannot take discounted substitute intended for fallback")
 main.serving_tray.items=stored
 var served: int=main.economy.served
 var missed: Array[int]=[0];main.hatch.customer_missed.connect(func()->void:missed[0]+=1)
 car._t=car.patience-.1;car._process(.2)
 check(car.state=="leaving" and missed[0]==1 and main.economy.served==served,"unfinished mixed order can time out without awarding completed-customer credit")
 car.free();main.hatch.car=null
 main.hatch._order_rng.seed=9314
 car=main.hatch.spawn_customer(0);car.set_process(false)
 check(car.quantity>=2 and car.quantity<=3 and car.patience>=38.0 and car.patience<=80.0,"normal auto-spawn uses wave-scaled order size and bounded patience")
 main.free();await process_frame
 print("Mixed orders: ",failures," failure(s)");quit(1 if failures else 0)
