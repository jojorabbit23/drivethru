extends SceneTree
const Items=preload("res://game/burger_items.gd")
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func item(kind: String="brown",remaining: float=150.0) -> Dictionary:
	return {"kind":kind,"quality":"perfect","hot_remaining":remaining,"patties":[kind]}
func run() -> void:
	var main: Node3D=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	var player: Node=main.player
	player.set_physics_process(false)
	main.hatch.auto=false
	main.serving_tray.set_physics_process(false)
	check(player.burger_capacity==1,"one initial burger slot")
	for wave in [3,6,9]:
		main.wave_cleared.emit(wave)
		check(player.burger_capacity==1+wave/3,"one additional slot every three waves")
	player.unlock_burger_slots(30)
	check(player.burger_capacity==4,"inventory caps at four slots")
	for kind in ["brown","blue","red","brown"]:check(player.add_burger(item(kind)),"add individual burger")
	check(not player.add_burger(item()),"full inventory rejects another burger")
	player.selected_burger=0
	player._sync_burger()
	var event:=InputEventKey.new()
	event.physical_keycode=KEY_V
	event.pressed=true
	player._unhandled_input(event)
	check(player.selected_burger==1 and player.held_burger.kind=="blue","V selects the next item left to right")
	for i in 3:player.cycle_burger()
	check(player.selected_burger==0,"selection wraps to the start")
	var tray: Node=main.serving_tray
	check(tray.deposit(player,0) and tray.items[0].kind=="brown" and player.burgers.size()==3,"deposit removes only selected item")
	Items.tick([tray.items[0]],149.5)
	check(tray.pick_up(player,0) and is_equal_approx(float(player.held_burger.hot_remaining),0.5),"retrieval preserves the original cooling timer")
	check(tray.deposit(player,0),"retrieved burger can be placed again")
	Items.tick([tray.items[0]],0.5)
	check(Items.cold(tray.items[0]),"burger becomes cold at exactly 150 seconds")
	check(tray.pick_up(player,0) and Items.cold(player.held_burger),"cold box can be retrieved without reheating")
	check(main.burger_bin.discard(player) and main.burger_bin.discarded==1 and player.burgers.size()==3,"bin discards selected cold burger only")
	for i in 3:player.take_selected_burger()
	for i in 4:
		player.add_burger(item("red"))
		check(tray.deposit(player,i),"each of four tray positions accepts a box")
	player.add_burger(item())
	check(not tray.deposit(player),"full tray leaves carried burger intact")
	for i in 3:player.add_burger(item())
	check(not tray.pick_up(player,0) and not tray.items[0].is_empty(),"retrieval with full inventory leaves tray intact")
	player.burgers.clear();player._sync_burger()
	for i in 4:tray.items[i]={}
	tray.items[0]=item("blue",0)
	tray.items[1]=item("blue",150)
	tray.items[2]=item("red",150)
	main.hatch.next_order="blue"
	var car: Node=main.hatch.spawn_customer(2)
	car.state="waiting"
	var cash: int=main.economy.cash
	main.hatch._physics_process(0.21)
	check(car.received==2,"waiting customer automatically takes two matching boxes")
	check(main.economy.cash-cash==54,"cold item pays 18, hot item pays 36: penalty applies per item")
	check(car.state=="leaving" and main.economy.served==1,"customer leaves after complete quantity")
	check(not tray.items[2].is_empty(),"unwanted burger stays on tray")
	check(main.hatch.collect_from_tray()==0 and main.economy.cash-cash==54,"already served order cannot pay twice")
	main.economy.cash=1000
	check(not player.has_weapon("SAWN-OFF"),"sawn-off starts unpurchased")
	check(main.terminal.buy_sawn_off(player) and player.has_weapon("SAWN-OFF"),"sawn-off can be purchased")
	var paid: int=main.economy.cash
	check(not main.terminal.buy_sawn_off(player) and main.economy.cash==paid,"repeat purchase cannot charge twice")
	check(main.terminal.buy_shotgun(player) and player.has_weapon("SHOTGUN"),"pump shotgun can also be purchased")
	check(main.terminal.buy_sawn_shells(player) and main.terminal.buy_shells(player),"each shotgun has its own ammo purchase")
	# Repeated prep actions make separate boxes and spend a bun per burger.
	main.grill.add_patty("brown")
	main.grill.add_patty("brown")
	for i in 2:main.grill._enter(i,"ready")
	var buns: int=main.economy.buns
	check(main.bench.bag(player) and main.bench.bag(player) and player.burgers.size()==2 and main.economy.buns==buns-2,"two boxed burgers use two buns and occupy two slots")
	player.burgers.clear();player._sync_burger()
	check(not main.burger_bin.discard(player),"empty bin interaction consumes nothing")
	main.free()
	for i in 4:await process_frame
	print("%d failure(s)" % failures)
	quit(1 if failures else 0)
