extends SceneTree
const Recipes=preload("res://game/recipes.gd")
const P=preload("res://core/palette.gd")
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run() -> void:
 check(Recipes.name_of("brown")=="Regular" and Recipes.name_of("double_brown")=="Double Regular","legacy IDs display Regular")
 for pair: Array in [["brown","R"],["blue","B"],["red","Y"],["double_brown","DBL R"],["double_blue","DBL B"],["double_red","DBL Y"],["special","SP"]]:
  check(Recipes.code(pair[0])==pair[1],"kitchen code "+pair[1])
 check(Recipes.ticket_text("double_red",2)=="DBL Y X2","recipe and burger quantity remain distinct")
 check(Recipes.colour("double_red")==P.AMBER_GLOW and Recipes.colour("double_blue")==P.ELECTRIC_TEAL,"double borders use same colour as singles")
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main);main.hatch.auto=false
 var hud: Node=main.get_node("ClarityHUD");hud.set_process(false)
 main.player.set_physics_process(false);main.grill.set_process(false)
 main.grill._place(0,"red");main.grill._kill_tween(main.grill.slots[0]);main.grill.slots[0].t=8;main.grill._enter(0,"ready")
 main.grill._place(1,"blue");main.grill._kill_tween(main.grill.slots[1]);main.grill.slots[1].t=2;main.grill._enter(1,"cooking")
 hud.refresh()
 check(hud.grill_cards[0].code.text=="Y" and hud.grill_cards[0].timer.text=="10s","ready card shows actual burn countdown")
 check(hud.grill_cards[1].code.text=="B" and hud.grill_cards[1].timer.text=="16s","cooking card includes remaining cook time")
 main.grill.slots[1].flipped=true;hud.refresh()
 check(hud.grill_cards[1].timer.text=="15s","flipped rate reflected in wall-clock countdown")
 main.economy.grill_level=2;main.grill._layout();hud.refresh()
 check(hud.grill_cards[3].root.visible and hud.grill_cards[3].state.text=="EMPTY","upgrades reveal empty extra slots")
 main.hatch.next_order="double_red"
 var car: Node=main.hatch.spawn_customer(2);car.state="waiting";car.set_process(false)
 hud.refresh()
 check(hud.order_name.text=="DBL Y X2" and car._quantity_label.text=="DBL Y X2","HUD and bubble share quantity code")
 car.received=1;car.refresh_order_quantity();hud.refresh()
 check(hud.order_name.text=="DBL Y X1" and car._quantity_label.text=="DBL Y X1","partial service updates both remaining quantities")
 var image: Image=car._bubble_texture("double_red").get_image()
 check(image.get_pixel(1,10).is_equal_approx(P.AMBER_GLOW),"double Yellow bubble has yellow stripe")
 image=car._bubble_texture("special").get_image()
 check(image.get_pixel(1,10).is_equal_approx(P.ELECTRIC_TEAL) and image.get_pixel(30,10).is_equal_approx(P.AMBER_GLOW),"special has Blue and Yellow stripes")
 main.serving_tray.items[0]={"kind":"double_blue","quality":"perfect"};main.serving_tray.refresh()
 check(main.serving_tray.lids[0].material_override.albedo_color==P.ELECTRIC_TEAL,"boxed double Blue keeps Blue lid colour")
 main.player.health=0;hud.refresh();check(not hud.grill_panel.visible,"death hides cooking cards")
 main.free()
 for i in 3:await process_frame
 print("Kitchen HUD: %d failure(s)" % failures)
 quit(1 if failures else 0)
