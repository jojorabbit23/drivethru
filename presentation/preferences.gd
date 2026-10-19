# Presentation preferences only. No cooking/customer or save-game state lives here.
extends RefCounted
const PATH: String="user://presentation.cfg"
static var initialized: bool=false
static var values: Dictionary={"master":0.85,"effects":0.85,"ambience":0.45,"cinematics":0.85,"ui":0.80,"sensitivity":0.0025,"fullscreen":false,"camera_roll":true,"mute_unfocused":true}
static var focused: bool=true
static var ui_theme: Theme
static func interactive() -> bool:
 return DisplayServer.get_name()!="headless" and not OS.get_cmdline_args().has("--script")
static func configure() -> void:
 if not initialized:
  initialized=true
  if interactive():
   var config:=ConfigFile.new()
   if config.load(PATH)==OK:
    for key: String in values:
     var saved: Variant=config.get_value("presentation",key,values[key])
     if typeof(saved)==typeof(values[key]):values[key]=saved
  if bool(values["fullscreen"]) and DisplayServer.get_name()!="headless" and not OS.get_cmdline_args().has("--script"):
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
  for key in ["master","effects","ambience","cinematics","ui"]:values[key]=clampf(float(values[key]),0.0,1.0)
  values["sensitivity"]=clampf(float(values["sensitivity"]),0.0005,0.006)
 for name: String in ["Effects","Ambience","Cinematics","UI"]:
  if AudioServer.get_bus_index(name)<0:
   AudioServer.add_bus()
   var index: int=AudioServer.bus_count-1
   AudioServer.set_bus_name(index,name)
   AudioServer.set_bus_send(index,"Master")
 if AudioServer.get_bus_effect_count(0)==0:
  var limiter:=AudioEffectLimiter.new()
  limiter.ceiling_db=-1.0
  AudioServer.add_bus_effect(0,limiter)
 apply_audio()
static func apply_audio() -> void:
 for pair: Array in [["Master","master"],["Effects","effects"],["Ambience","ambience"],["Cinematics","cinematics"],["UI","ui"]]:
  var index: int=AudioServer.get_bus_index(pair[0])
  if index>=0:AudioServer.set_bus_volume_db(index,linear_to_db(maxf(0.0001,float(values[pair[1]]))))
 AudioServer.set_bus_mute(0,not focused and bool(values["mute_unfocused"]))
static func set_value(key: String, value: Variant, persist: bool=true) -> void:
 if not values.has(key):return
 if key in ["master","effects","ambience","cinematics","ui"]:value=clampf(float(value),0.0,1.0)
 if key=="sensitivity":value=clampf(float(value),0.0005,0.006)
 values[key]=value
 apply_audio()
 if key=="fullscreen" and DisplayServer.get_name()!="headless":
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(value) else DisplayServer.WINDOW_MODE_WINDOWED)
 if persist:save()
static func save() -> void:
 if not interactive():return
 var error: Error=save_config(PATH)
 if error!=OK:push_warning("Presentation settings could not be saved: %s" % error_string(error))
static func set_focused(on: bool) -> void:
 focused=on
 apply_audio()
static func settings_controls(container: VBoxContainer) -> void:
 configure()
 for pair: Array in [["Master volume","master"],["Sound effects","effects"],["Room ambience","ambience"],["Intro / cinematic audio","cinematics"],["Menu sounds","ui"],["Mouse sensitivity","sensitivity"]]:
  var row:=HBoxContainer.new()
  var label:=Label.new()
  label.text=pair[0]
  label.custom_minimum_size.x=205
  row.add_child(label)
  var slider:=HSlider.new()
  slider.custom_minimum_size.x=240
  slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  slider.min_value=0.0005 if pair[1]=="sensitivity" else 0.0
  slider.max_value=0.006 if pair[1]=="sensitivity" else 1.0
  slider.step=0.0001 if pair[1]=="sensitivity" else 0.01
  slider.value=float(values[pair[1]])
  slider.tooltip_text=pair[0]
  var readout:=Label.new()
  readout.custom_minimum_size.x=58
  var key: String=pair[1]
  readout.text=("%.1f" % (slider.value*1000.0)) if key=="sensitivity" else ("%d%%" % roundi(slider.value*100.0))
  slider.value_changed.connect(func(v: float):
   set_value(key,v,false)
   readout.text=("%.1f" % (v*1000.0)) if key=="sensitivity" else ("%d%%" % roundi(v*100.0)))
  slider.drag_ended.connect(func(_changed: bool):save())
  slider.focus_exited.connect(save)
  row.add_child(slider)
  row.add_child(readout)
  container.add_child(row)
 for pair: Array in [["Fullscreen","fullscreen"],["Camera damage roll","camera_roll"],["Mute audio when unfocused","mute_unfocused"]]:
  var toggle:=CheckButton.new()
  toggle.text=pair[0]
  toggle.button_pressed=bool(values[pair[1]])
  var key: String=pair[1]
  toggle.toggled.connect(func(on: bool):set_value(key,on))
  container.add_child(toggle)

static func save_config(path: String) -> Error:
 var config:=ConfigFile.new()
 for key: String in values:config.set_value("presentation",key,values[key])
 return config.save(path)
static func theme() -> Theme:
 if ui_theme:return ui_theme
 const P=preload("res://core/palette.gd")
 ui_theme=Theme.new()
 ui_theme.default_font_size=18
 for control: String in ["Label","Button","CheckButton"]:
  ui_theme.set_color("font_color",control,P.WARM_CHALK)
  ui_theme.set_color("font_hover_color",control,P.AMBER_GLOW)
  ui_theme.set_color("font_focus_color",control,P.AMBER_GLOW)
 for state: String in ["normal","hover","pressed","focus"]:
  var style:=StyleBoxFlat.new()
  style.bg_color=P.WET_CHARCOAL if state=="normal" else P.BLUE_SLATE
  if state=="focus":style.bg_color=Color(P.MIDNIGHT_TYNE,0.0)
  style.border_color=P.AMBER_GLOW if state=="focus" else P.OXIDISED_TEAL
  style.set_border_width_all(2 if state=="focus" else 1)
  style.set_corner_radius_all(3)
  style.content_margin_left=12
  style.content_margin_right=12
  style.content_margin_top=7
  style.content_margin_bottom=7
  ui_theme.set_stylebox(state,"Button",style)
 return ui_theme
