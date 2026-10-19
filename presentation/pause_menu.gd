extends CanvasLayer
const Prefs=preload("res://presentation/preferences.gd")
const Sounds=preload("res://presentation/audio_library.gd")
const P=preload("res://core/palette.gd")
var screen: Control
var content: VBoxContainer
var settings: bool=false
var opened: bool=false
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 layer=90
 Prefs.configure()
 screen=Control.new()
 screen.theme=Prefs.theme()
 screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(screen)
 var shade:=ColorRect.new()
 shade.color=Color(P.MIDNIGHT_TYNE,0.94)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 screen.add_child(shade)
 var center:=CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 screen.add_child(center)
 content=VBoxContainer.new()
 content.custom_minimum_size.x=620
 content.add_theme_constant_override("separation",12)
 center.add_child(content)
 screen.hide()
func clear() -> void:
 for child in content.get_children():
  content.remove_child(child)
  child.queue_free()
func button(text: String,action: Callable) -> void:
 var item:=Button.new()
 item.text=text
 item.custom_minimum_size.y=40
 item.pressed.connect(func():Sounds.ui(self,"confirm");action.call())
 content.add_child(item)
func open() -> void:
 opened=true
 settings=false
 get_tree().paused=true
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 screen.show()
 home()
func home() -> void:
 settings=false
 clear()
 var title:=Label.new()
 title.text="TAKING A BREATHER"
 title.add_theme_font_size_override("font_size",30)
 title.add_theme_color_override("font_color",P.AMBER_GLOW)
 content.add_child(title)
 button("Resume",resume)
 button("Audio & controls",show_settings)
 button("Return to title (ends this run)",title_screen)
 button("Quit",func():get_tree().quit())
 content.get_child(1).grab_focus()
func show_settings() -> void:
 settings=true
 clear()
 Prefs.settings_controls(content)
 button("Back",home)
func resume() -> void:
 opened=false
 screen.hide()
 Prefs.save()
 get_tree().paused=false
 # Let the resume click expire before returning mouse control to the weapon.
 await get_tree().create_timer(0.08).timeout
 if is_inside_tree() and not opened and DisplayServer.get_name()!="headless":Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func title_screen() -> void:
 get_tree().paused=false
 get_tree().change_scene_to_file("res://ui/menu/menu.tscn")
func _input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel") and not event.is_echo():
  get_viewport().set_input_as_handled()
  if not opened:open()
  elif settings:home()
  else:resume()
func _notification(what: int) -> void:
 if not is_node_ready() or DisplayServer.get_name()=="headless":return
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
  Prefs.set_focused(false)
  if not OS.get_cmdline_args().has("--script") and not opened:open()
 elif what==NOTIFICATION_APPLICATION_FOCUS_IN:Prefs.set_focused(true)
