extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 var player: Node=main.player
 player.set_physics_process(false)
 var starter: Node=player.current_weapon()
 starter.set_physics_process(false)
 check(starter.display_name=="PISTOL" and starter.damage==34 and starter.mag==12,"original starter pistol retained")
 check(starter.viewmodel_scene.resource_path.ends_with("starter_pistol_viewmodel.tscn"),"starter uses original teal model")
 check(not player.has_weapon("DESERT EAGLE") and player.weapons.size()==4,"Eagle is not a free starting weapon")
 main.economy.cash=179
 check(not main.terminal.buy_desert_eagle(player) and main.economy.cash==179,"insufficient funds leave loadout and cash untouched")
 main.economy.cash=180
 check(main.terminal.buy_desert_eagle(player) and main.economy.cash==0,"purchase charges 180")
 var eagle: Node=player.weapon_named("DESERT EAGLE")
 eagle.set_physics_process(false)
 check(player.current_weapon()==eagle and eagle.mag==7 and eagle.reserve==21,"purchase equips loaded Eagle")
 check(eagle.damage==60 and eagle.damage>starter.damage and eagle.fire_interval>starter.fire_interval,"stronger slower Eagle")
 main.economy.cash=400
 check(not main.terminal.buy_desert_eagle(player) and main.economy.cash==400 and player.weapons.size()==5,"duplicate purchase rejected")
 eagle._physics_process(.4)
 check(eagle.request_fire() and eagle.mag==6,"Eagle fires and spends one round")
 check(not eagle.request_fire(),"Eagle respects cooldown")
 eagle.reload()
 eagle._physics_process(.9)
 check(eagle.mag==6 and not eagle._reload_slide_played,"no early reload transfer or rack")
 eagle._physics_process(.2)
 check(eagle._reload_slide_played and eagle.mag==6,"slide event reaches rack phase before ammo transfer")
 eagle._physics_process(.4)
 check(eagle.mag==7 and eagle.reserve==20,"reload conserves Eagle rounds")
 var reserve: int=starter.reserve
 check(main.terminal.buy_eagle_ammo(player) and eagle.reserve==34 and starter.reserve==reserve and main.economy.cash==380,"Eagle ammo has separate reserve and price")
 main.terminal.page="weapons"
 var rows: Array=main.terminal.options(player)
 check(rows.size()==6 and "Desert Eagle rounds" in rows[3].label and "SMG" in rows[4].label and rows[5].label=="Back","shop exposes Eagle ammo, the SMG and back")
 player.open_menu(main.terminal,rows)
 var key:=InputEventKey.new()
 key.physical_keycode=KEY_6
 key.pressed=true
 player._unhandled_input(key)
 check(main.terminal.page=="","key 6 reaches Back on six-row shop")
 player.switch_weapon(0)
 check(player.current_weapon()==starter and not eagle.active,"original pistol can be re-equipped")
 main.free()
 for i in 3:await process_frame
 print("Desert Eagle: %d failure(s)" % failures)
 quit(1 if failures else 0)
