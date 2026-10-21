extends SceneTree
var failures:=0
var main: Node3D
var grill: Node
var player: Node
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func prepare(i: int,kind: String,time: float=2.0) -> void:
 grill._place(i,kind)
 grill._kill_tween(grill.slots[i])
 grill.slots[i].t=time
 grill._enter(i,"ready" if time>=6 else "cooking")
func aim(i: int) -> void:
 player.close_menu()
 player.focus=grill
 var at: Vector3=grill.slots[i].root.global_position+Vector3(0,.03,0)
 player.camera.global_position=at+Vector3(0,1.3,1.0)
 player.camera.look_at(at)
func tap_f(echo: bool=false) -> void:
 var key:=InputEventKey.new();key.physical_keycode=KEY_F;key.pressed=true;key.echo=echo
 player._unhandled_input(key)
func run() -> void:
 main=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main);main.hatch.auto=false
 player=main.player;player.set_physics_process(false);player.set_process_unhandled_input(false)
 grill=main.grill;grill.set_process(false);grill._layout()
 main.economy.stock={"brown":5,"blue":5,"red":5}
 prepare(0,"brown");prepare(1,"blue")
 aim(0);player.use_focus()
 check(not grill.slots[0].flipped and player.menu_station==grill,"E opens placement menu instead of flipping")
 player.close_menu()
 aim(0);tap_f()
 check(grill.slots[0].flipped and grill.state_of(0)=="cooking","first F flips without removing")
 tap_f(true)
 check(grill.state_of(0)=="cooking","holding F does not count as a second press")
 check("F AGAIN" in grill.prompt(player),"second-tap prompt explains discard")
 grill._process(.15);tap_f()
 check(grill.state_of(0)=="" and grill.kind_of(1)=="blue" and grill.state_of(1)=="cooking","quick second F clears only aimed slot during flip animation")
 check(main.economy.stock.brown==5,"discard refunds no mushrooms")
 prepare(0,"brown");aim(0);tap_f();grill._process(.46);tap_f()
 check(grill.state_of(0)=="cooking","late second tap cannot discard")
 prepare(0,"brown");aim(0);tap_f();aim(1);tap_f()
 check(grill.state_of(0)=="cooking" and grill.state_of(1)=="cooking","tapping a different slot is not a discard")
 prepare(0,"brown",5.95);aim(0);tap_f();grill._process(.1);tap_f()
 check(grill.state_of(0)=="ready","ready transition disables discard even inside tap window")
 prepare(0,"brown");aim(0);tap_f();grill._clear(0);prepare(0,"blue");aim(0);tap_f()
 check(grill.state_of(0)=="cooking" and grill.slots[0].flipped,"reused slot does not inherit pending discard")
 player.close_menu();grill._clear(0);grill._clear(1)
 main.hatch.next_order="double_blue"
 var car: Node=main.hatch.spawn_customer();car.state="waiting"
 prepare(0,"blue",8.0);prepare(1,"brown",7.0)
 var before: int=main.economy.buns
 check(main.bench.plan().order=="brown" and "regular burger" in main.bench.prompt(player),"incomplete double selects unrelated single and shows correct prompt")
 check(main.bench.bag(player) and player.held_burger.kind=="brown" and main.economy.buns==before-1,"boxes spare with one bun")
 check(grill.state_of(0)=="ready" and grill.state_of(1)=="","matching patty stays ready and wrong patty frees slot")
 player.set_held("");prepare(1,"blue",7.0)
 check(main.bench.bag(player) and player.held_burger.kind=="double_blue" and grill.count("ready")==0,"replacement completes double normally")
 player.set_held("");prepare(0,"blue",8.0);prepare(1,"brown",2.0)
 check(not main.bench.bag(player) and grill.state_of(0)=="ready","uncooked spare cannot be boxed and matching single is preserved")
 grill._clear(1);main.tray.held.clear();main.tray.held.append({"kind":"brown","ready_for":0.0,"burnt":false})
 check(main.bench.bag(player) and player.held_burger.kind=="brown" and grill.state_of(0)=="ready","warming tray spare also boxes without stealing matching grill patty")
 main.free()
 for i in 3:await process_frame
 print("Grill recovery: %d failure(s)" % failures)
 quit(1 if failures else 0)
