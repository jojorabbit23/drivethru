# Readability only: no economy, order, cooking or damage rules.
extends CanvasLayer
const P=preload("res://core/palette.gd")
const Icons=preload("res://game/icons.gd")
const Recipes=preload("res://game/recipes.gd")
var main: Node3D
var actor: Node3D
var order_panel: PanelContainer
var order_icon: TextureRect
var grill_panel: PanelContainer
var grill_title: Label
var grill_cards: Array[Dictionary]=[]
var order_style: StyleBoxFlat
var order_name: Label
var patience: ProgressBar
var wait_label: Label
var health_warning: Label
var patience_fill:=StyleBoxFlat.new()
var ammo_warning: Label
var help: Label
var edge: Control
var clock: float=0.0
var scan: float=0.0
var direction_time: float=0.0
var damage_direction: Vector2=Vector2.UP
var critical: bool=false
func _ready() -> void:
 main=get_parent();actor=main.player
 layer=9
 var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
 edge=Control.new();edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);edge.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(edge);edge.draw.connect(draw_alerts)
 order_panel=PanelContainer.new();order_panel.name="CurrentCustomer";order_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);order_panel.position=Vector2(-360,70);order_panel.size=Vector2(340,94);order_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(order_panel)
 var style:=StyleBoxFlat.new();style.bg_color=Color(P.MIDNIGHT_TYNE,0.92);style.border_color=P.OXIDISED_TEAL;style.set_border_width_all(2);style.set_content_margin_all(10);order_panel.add_theme_stylebox_override("panel",style);order_style=style
 var rows:=VBoxContainer.new();rows.mouse_filter=Control.MOUSE_FILTER_IGNORE;order_panel.add_child(rows)
 var order_row:=HBoxContainer.new();order_row.add_theme_constant_override("separation",10);rows.add_child(order_row)
 order_icon=TextureRect.new();order_icon.custom_minimum_size=Vector2(38,38);order_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;order_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;order_icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;order_row.add_child(order_icon)
 order_name=Label.new();order_name.add_theme_font_size_override("font_size",24);order_row.add_child(order_name)
 build_grill(root)
 wait_label=Label.new();wait_label.add_theme_font_size_override("font_size",14);rows.add_child(wait_label)
 patience=ProgressBar.new();patience.mouse_filter=Control.MOUSE_FILTER_IGNORE;patience.custom_minimum_size=Vector2(240,7);patience.show_percentage=false;patience.add_theme_stylebox_override("fill",patience_fill);rows.add_child(patience)
 ammo_warning=Label.new();ammo_warning.name="AmmoWarning";ammo_warning.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);ammo_warning.position=Vector2(-400,-80);ammo_warning.size=Vector2(384,28);ammo_warning.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;ammo_warning.add_theme_font_size_override("font_size",20);ammo_warning.add_theme_color_override("font_color",P.AMBER_GLOW);ammo_warning.add_theme_color_override("font_outline_color",P.MIDNIGHT_TYNE);ammo_warning.add_theme_constant_override("outline_size",5);root.add_child(ammo_warning)
 for child: Node in main._hud.health.get_parent().get_children():
  if child is Label and child.text.begins_with("WASD move"):help=child;break
 main._hud.toast.add_theme_font_size_override("font_size",22)
 main._hud.toast.position.y=170
 main._hud.health.add_theme_font_size_override("font_size",22)
 main._hud.weapon.add_theme_font_size_override("font_size",22)
 health_warning=Label.new();health_warning.name="CriticalHealth";health_warning.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);health_warning.position=Vector2(16,-80);health_warning.text="CRITICAL HEALTH";health_warning.add_theme_font_size_override("font_size",20);health_warning.add_theme_color_override("font_color",P.AMBER_GLOW);health_warning.add_theme_color_override("font_outline_color",P.MIDNIGHT_TYNE);health_warning.add_theme_constant_override("outline_size",5);root.add_child(health_warning)
 actor.hurt.connect(on_hurt)
 refresh()
func on_hurt(_amount: float,from: Node3D) -> void:
 if not is_instance_valid(from):return
 var relative: Vector3=actor.camera.global_basis.inverse()*(from.global_position-actor.camera.global_position)
 var angle: float=atan2(relative.x,-relative.z)
 damage_direction=Vector2(sin(angle),-cos(angle));direction_time=1.0
func _process(delta: float) -> void:
 clock+=delta;scan-=delta;direction_time=maxf(0.0,direction_time-delta)
 critical=not actor.is_dead() and actor.health<=actor.max_health*0.25
 edge.queue_redraw()
 if scan<=0.0:scan=0.1;refresh()
func refresh() -> void:
 if is_instance_valid(help) and clock>8.0:help.text="F1  CONTROLS"
 var dead: bool=actor.is_dead()
 health_warning.visible=not dead and actor.health<=actor.max_health*0.25
 main._hud.health.add_theme_color_override("font_color",P.AMBER_GLOW if actor.health<=actor.max_health*0.25 and not dead else P.WARM_CHALK)
 var car: Node3D=main.hatch.car if is_instance_valid(main.hatch) and is_instance_valid(main.hatch.car) else null
 order_panel.visible=not dead and is_instance_valid(car) and car.state in ["arriving","waiting"]
 if order_panel.visible:
  var remaining: int=maxi(0,car.quantity-car.received)
  order_name.text=Recipes.ticket_text(car.order,remaining)
  order_icon.texture=Icons.texture("burger_"+String(car.order))
  order_style.border_color=Recipes.colour(car.order)
  var seconds: int=maxi(0,ceili(car.patience-car.waited))
  wait_label.text="ARRIVING" if car.state=="arriving" else "CUSTOMER WAITING  ·  %ds"%seconds
  patience.value=clampf(1.0-car.waited/car.patience,0.0,1.0)*100.0
  var colour: Color=P.AMBER_GLOW if seconds<=10 else (P.ELECTRIC_TEAL if "blue" in car.order else P.AMBER_GLOW if "red" in car.order else P.WARM_CHALK)
  order_name.add_theme_color_override("font_color",P.WARM_CHALK)
  patience_fill.bg_color=colour
 refresh_grill(dead)
 var gun: Node=actor.current_weapon()
 ammo_warning.text=""
 if not dead and is_instance_valid(gun):
  var amount: Variant=gun.get("mag")
  if amount==null:amount=gun.get("ammo")
  if amount!=null:
   var reserve: int=int(gun.get("reserve"))
   var capacity: Variant=gun.get("mag_size")
   var low: int=maxi(1,ceili(float(capacity if capacity!=null else 2)*0.25))
   if gun.has_method("is_reloading") and gun.is_reloading():ammo_warning.text="RELOADING"
   elif int(amount)==0:ammo_warning.text="R  RELOAD" if reserve>0 else "OUT OF AMMO"
   elif reserve==0:ammo_warning.text="LAST ROUNDS  ·  %d LEFT"%int(amount)
   elif int(amount)<=low:ammo_warning.text="LOW AMMO  ·  R RELOAD"
 main._hud.weapon.add_theme_color_override("font_color",P.AMBER_GLOW if not ammo_warning.text.is_empty() else P.WARM_CHALK)
func build_grill(root: Control) -> void:
 grill_panel=PanelContainer.new();grill_panel.name="GrillSlots";grill_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);grill_panel.position=Vector2(-360,184);grill_panel.size=Vector2(340,126);grill_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(grill_panel)
 var style:=StyleBoxFlat.new();style.bg_color=Color(P.MIDNIGHT_TYNE,.9);style.border_color=P.BLUE_SLATE;style.set_border_width_all(1);style.set_content_margin_all(8);grill_panel.add_theme_stylebox_override("panel",style)
 var column:=VBoxContainer.new();grill_panel.add_child(column)
 grill_title=Label.new();grill_title.add_theme_font_size_override("font_size",14);grill_title.add_theme_color_override("font_color",P.WARM_CHALK);column.add_child(grill_title)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",6);column.add_child(row)
 for i in 4:
  var panel:=PanelContainer.new();row.add_child(panel)
  var card_style:=StyleBoxFlat.new();card_style.bg_color=Color(P.BLUE_SLATE,.5);card_style.border_color=P.BLUE_SLATE;card_style.set_border_width_all(1);card_style.set_content_margin_all(3);panel.add_theme_stylebox_override("panel",card_style)
  var card:=VBoxContainer.new();card.custom_minimum_size=Vector2(60,0);panel.add_child(card)
  var top:=HBoxContainer.new();card.add_child(top)
  var icon:=TextureRect.new();icon.custom_minimum_size=Vector2(22,22);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;top.add_child(icon)
  var code_label:=Label.new();code_label.add_theme_font_size_override("font_size",16);top.add_child(code_label)
  var state_label:=Label.new();state_label.add_theme_font_size_override("font_size",11);card.add_child(state_label)
  var timer_label:=Label.new();timer_label.add_theme_font_size_override("font_size",11);card.add_child(timer_label)
  grill_cards.append({"root":panel,"icon":icon,"code":code_label,"state":state_label,"timer":timer_label})
 var legend:=Label.new();legend.text="R REGULAR · B BLUE\nY YELLOW · SP SPECIAL";legend.add_theme_font_size_override("font_size",10);legend.add_theme_color_override("font_color",P.WARM_CHALK);column.add_child(legend)
func refresh_grill(dead: bool) -> void:
 grill_panel.visible=not dead and is_instance_valid(main.grill)
 if not grill_panel.visible:return
 var grill: Node=main.grill
 var occupied: int=grill.slot_count()-grill.count("")
 grill_title.text="GRILL %d/%d · BURN IN" % [occupied,grill.slot_count()]
 for i in 4:
  var card: Dictionary=grill_cards[i]
  card.root.visible=i<grill.slot_count()
  if not card.root.visible:continue
  var slot: Dictionary=grill.slots[i]
  var state: String=slot.state
  var empty: bool=state.is_empty()
  card.icon.texture=Icons.texture("raw" if empty else "mushroom_"+String(slot.kind))
  card.icon.modulate=Color(1,1,1,.25 if empty else 1.0)
  card.code.text=str(i+1) if empty else Recipes.code(slot.kind)
  card.code.add_theme_color_override("font_color",P.CONCRETE_GREY if empty else P.WARM_CHALK)
  card.state.text="EMPTY" if empty else ("COOK" if state=="cooking" else state.to_upper())
  var colour: Color=P.CONCRETE_GREY if empty else (P.ELECTRIC_TEAL if state=="ready" else P.AMBER_GLOW if state=="burnt" else P.WARM_CHALK)
  card.state.add_theme_color_override("font_color",colour)
  card.timer.add_theme_color_override("font_color",P.AMBER_GLOW if state=="ready" or state=="burnt" else P.WARM_CHALK)
  if empty:card.timer.text="--"
  elif state=="burnt":card.timer.text="BURNT!"
  else:
   var until_ready: float=maxf(0.0,grill.COOK_TIME-float(slot.t))/(grill.FLIP_RATE if slot.flipped else 1.0)
   var until_burn: float=until_ready+grill.ready_window() if float(slot.t)<grill.COOK_TIME else maxf(0.0,grill.burn_time()-float(slot.t))
   card.timer.text="%ds" % ceili(until_burn)

func draw_alerts() -> void:
 var size: Vector2=edge.size
 if critical:
  var c:=Color(P.BURNT_ORANGE,0.06+0.05*(0.5+0.5*sin(clock*3.5)))
  edge.draw_rect(Rect2(0,0,size.x,8),c);edge.draw_rect(Rect2(0,size.y-8,size.x,8),c);edge.draw_rect(Rect2(0,0,8,size.y),c);edge.draw_rect(Rect2(size.x-8,0,8,size.y),c)
 if direction_time>0.0 and not actor.is_dead():
  var at: Vector2=size*0.5+damage_direction*95.0
  var side:=Vector2(-damage_direction.y,damage_direction.x)*7.0
  edge.draw_colored_polygon(PackedVector2Array([at+damage_direction*14.0,at-damage_direction*4.0+side,at-damage_direction*4.0-side]),Color(P.AMBER_GLOW,minf(1.0,direction_time*2.0)))
