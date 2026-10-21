extends SceneTree
var failures: int=0
func _initialize() -> void:
 create_timer(25).timeout.connect(func()->void:quit(1))
 run.call_deferred()
func check(ok: bool,message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main);main.hatch.auto=false;main.hatch.set_physics_process(false)
 var hud: Node=main.get_node("ClarityHUD");hud.set_process(false);main.player.set_physics_process(false);main.grill.set_process(false)
 main.serving_tray.set_physics_process(false)
 hud.refresh()
 check(not hud.tray_panel.visible and hud.grill_panel.position.y==70,"idle HUD hides empty tray and closes unused customer space")
 check(not main.has_node("BuildingDecorations"),"decoration set stays absent")
 main.hatch.next_order="double_red";var car: Node=main.hatch.spawn_customer(2);car.state="waiting";car.set_process(false)
 var items: Array[Dictionary]=[{"kind":"double_red","quality":"perfect","age_seconds":20.0},{"kind":"double_red","quality":"good","age_seconds":160.0},{"kind":"double_red","quality":"good","age_seconds":460.0},{"kind":"blue","quality":"good","age_seconds":60.0}]
 main.serving_tray.items=items
 hud.refresh()
 check(hud.recipe_detail.text.contains("2 Y PATTIES") and hud.order_name.text=="DBL Y X2","two burgers is distinct from two patties per burger")
 check(hud.matching_tray("double_red")==[1,1],"tray match excludes wrong recipe and spoiled burger")
 check(hud.tray_panel.visible and hud.tray_cards[1].state.text=="COLD" and hud.tray_cards[2].state.text=="SPOILED","remote tray overview reports each actual freshness state")
 check(hud.tray_note.text.contains("1 COLD") and hud.tray_note.text.contains("1 SPOILED"),"pay reduction and bin reminders appear only when needed")
 check(main.serving_tray.items[0].age_seconds==20.0 and main.serving_tray.items[1].age_seconds==160.0,"HUD does not advance or reset burger age")
 check(hud.recipe_text("special").contains("Y + B"),"special ingredients are explicit")
 car.waited=car.patience-5;hud.refresh();check(hud.wait_label.text.contains("LAST CALL"),"last ten seconds have explicit urgency")
 main.grill._place(0,"blue");main.grill._kill_tween(main.grill.slots[0]);main.grill.slots[0].t=2;main.grill._enter(0,"cooking")
 for i in 3:await physics_frame
 main.player.focus=main.grill;main.player.camera.global_position=main.grill.to_global(Vector3(-.22,.8,.7));main.player.camera.look_at(main.grill.to_global(Vector3(-.22,.03,0)))
 hud.refresh();check(hud.grill_action.text.begins_with("F FLIP"),"aiming at uncooked patty shows flip and quick-discard controls")
 main.grill.flip_input(main.player);hud.refresh()
 check(hud.grill_action.text.contains("F AGAIN: DISCARD SLOT 1") and hud.grill_cards[0].state.text=="FLIPPED","armed discard identifies slot and flipped state")
 main.grill._reset_discard();main.grill.slots[0].t=17;main.grill._enter(0,"ready");hud.refresh()
 check(hud.grill_cards[0].state.text=="BAG NOW" and not hud.grill_action.text.contains("DISCARD"),"ready-to-burn patty urges bagging without offering raw discard")
 main.player.health=0;hud.refresh();check(not hud.tray_panel.visible and not hud.order_panel.visible and not hud.grill_panel.visible,"death hides kitchen readouts")
 main.free();await process_frame
 print("Gameplay clarity: ",failures," failure(s)");quit(1 if failures else 0)
