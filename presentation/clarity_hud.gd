# Readability only: no economy, order, cooking or damage rules.
extends CanvasLayer
const P=preload("res://core/palette.gd")
const Recipes=preload("res://game/recipes.gd")
var main: Node3D
var actor: Node3D
var order_panel: PanelContainer
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
 order_panel=PanelContainer.new();order_panel.name="CurrentCustomer";order_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);order_panel.position=Vector2(-305,70);order_panel.size=Vector2(285,94);order_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(order_panel)
 var style:=StyleBoxFlat.new();style.bg_color=Color(P.MIDNIGHT_TYNE,0.92);style.border_color=P.OXIDISED_TEAL;style.set_border_width_all(2);style.set_content_margin_all(10);order_panel.add_theme_stylebox_override("panel",style)
 var rows:=VBoxContainer.new();rows.mouse_filter=Control.MOUSE_FILTER_IGNORE;order_panel.add_child(rows)
 order_name=Label.new();order_name.add_theme_font_size_override("font_size",17);rows.add_child(order_name)
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
  order_name.text="%s BURGER  x%d"%[Recipes.name_of(car.order).to_upper(),remaining]
  var seconds: int=maxi(0,ceili(car.patience-car.waited))
  wait_label.text="ARRIVING" if car.state=="arriving" else "CUSTOMER WAITING  ·  %ds"%seconds
  patience.value=clampf(1.0-car.waited/car.patience,0.0,1.0)*100.0
  var colour: Color=P.AMBER_GLOW if seconds<=10 else (P.ELECTRIC_TEAL if "blue" in car.order else P.AMBER_GLOW if "red" in car.order else P.WARM_CHALK)
  order_name.add_theme_color_override("font_color",colour)
  patience_fill.bg_color=colour
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
func draw_alerts() -> void:
 var size: Vector2=edge.size
 if critical:
  var c:=Color(P.BURNT_ORANGE,0.06+0.05*(0.5+0.5*sin(clock*3.5)))
  edge.draw_rect(Rect2(0,0,size.x,8),c);edge.draw_rect(Rect2(0,size.y-8,size.x,8),c);edge.draw_rect(Rect2(0,0,8,size.y),c);edge.draw_rect(Rect2(size.x-8,0,8,size.y),c)
 if direction_time>0.0 and not actor.is_dead():
  var at: Vector2=size*0.5+damage_direction*95.0
  var side:=Vector2(-damage_direction.y,damage_direction.x)*7.0
  edge.draw_colored_polygon(PackedVector2Array([at+damage_direction*14.0,at-damage_direction*4.0+side,at-damage_direction*4.0-side]),Color(P.AMBER_GLOW,minf(1.0,direction_time*2.0)))
