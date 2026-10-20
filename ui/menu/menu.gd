extends Control
const Prefs=preload("res://presentation/preferences.gd")
const Sounds=preload("res://presentation/audio_library.gd")
const P=preload("res://core/palette.gd")
const SHEET=preload("res://ui/menu/menu_reference.png")
const INTRO=preload("res://ui/menu/intro.ogv")
const BUS=preload("res://ui/menu/start_bus.ogv")
const LOOP=preload("res://ui/menu/bread_loop.ogv")
const TITLES=["Start Cooking","Continue","How to Play","Settings","Credits","Quit"]
const RECTS=[Rect2(225,105,970,130),Rect2(225,250,610,130),Rect2(225,393,805,130),Rect2(225,535,600,130),Rect2(225,678,520,130),Rect2(225,820,300,140)]
var starting: bool=false
var selected: int=0
var buttons: Array[Button]=[]
var images: Array[TextureRect]=[]
var arrow: TextureRect
var video: VideoStreamPlayer
var panel: PanelContainer
var content: VBoxContainer
var canvas: Control
func atlas(rect: Rect2) -> AtlasTexture:
 var a:=AtlasTexture.new()
 a.atlas=SHEET
 a.region=rect
 return a
func _ready() -> void:
 Prefs.configure()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 Engine.max_fps=int(ProjectSettings.get_setting("application/run/max_fps",0))
 var background:=ColorRect.new()
 background.color=P.MIDNIGHT_TYNE
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(background)
 video=VideoStreamPlayer.new()
 video.expand=true
 video.bus="Cinematics"
 video.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(video)
 video.stream=INTRO
 video.finished.connect(_video_finished)
 if DisplayServer.get_name()!="headless": video.play()
 canvas=Control.new()
 canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(canvas)
 var shader:=Shader.new()
 shader.code="shader_type canvas_item; uniform vec4 ink:source_color; void fragment(){vec4 c=texture(TEXTURE,UV); float light=max(c.r,max(c.g,c.b)); if(light>0.22){c.rgb=ink.rgb*clamp(light/0.9,0.0,1.15);} COLOR=c;}"
 for i in TITLES.size():
  var button:=Button.new()
  button.text=""
  button.tooltip_text=TITLES[i]
  button.flat=true
  button.focus_mode=Control.FOCUS_NONE
  button.disabled=i==1
  button.mouse_entered.connect(func(): select(i))
  button.pressed.connect(func(): activate(i))
  canvas.add_child(button)
  buttons.append(button)
  var picture:=TextureRect.new()
  picture.texture=atlas(RECTS[i])
  picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
  picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  var mat:=ShaderMaterial.new()
  mat.shader=shader
  picture.material=mat
  button.add_child(picture)
  images.append(picture)
 arrow=TextureRect.new()
 arrow.texture=atlas(Rect2(108,118,74,112))
 arrow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE
 canvas.add_child(arrow)
 for y in [110.0,560.0]:
  var line:=ColorRect.new()
  line.color=P.ELECTRIC_TEAL
  line.position=Vector2(72,y)
  line.size=Vector2(58,3)
  canvas.add_child(line)
 panel=PanelContainer.new()
 panel.theme=Prefs.theme()
 panel.position=Vector2(450,130)
 panel.size=Vector2(690,450)
 canvas.add_child(panel)
 content=VBoxContainer.new()
 content.add_theme_constant_override("separation",8)
 panel.add_child(content)
 panel.hide()
 resized.connect(layout)
 layout()
 select(0)
func layout() -> void:
 if canvas==null:return
 var fit: float=minf(size.x/1280.0,size.y/720.0)
 canvas.scale=Vector2.ONE*fit
 canvas.position=(size-Vector2(1280,720)*fit)*0.5
 video.position=canvas.position
 video.size=Vector2(1280,720)*fit
 for i in buttons.size():
  buttons[i].position=Vector2(85,140+i*65)
  buttons[i].size=Vector2(365,58)
  images[i].position=Vector2.ZERO
  images[i].size=Vector2(RECTS[i].size.x*0.37,RECTS[i].size.y*0.37)
func _video_finished() -> void:
 if starting:
  Engine.max_fps=int(ProjectSettings.get_setting("application/run/max_fps",0))
  get_tree().change_scene_to_file("res://main.tscn")
 else:
  _loop_bread()
func _start_game() -> void:
 if starting:return
 starting=true
 canvas.hide()
 video.stop()
 video.loop=false
 video.stream=BUS
 if DisplayServer.get_name()!="headless":video.play()
func _loop_bread() -> void:
 video.stream=LOOP
 video.loop=true
 video.play()
func select(index: int) -> void:
 if starting or index==1:return
 if selected!=index:Sounds.ui(self,"select")
 selected=index
 for i in images.size():
  var ink: Color=P.AMBER_GLOW if i==selected else (P.CONCRETE_GREY if i==1 else P.WARM_CHALK)
  (images[i].material as ShaderMaterial).set_shader_parameter("ink",ink)
 arrow.position=Vector2(57,146+selected*65)
 arrow.size=Vector2(22,34)
func _unhandled_key_input(event: InputEvent) -> void:
 if starting or not event.is_pressed():return
 if event.is_action_pressed("ui_cancel"):
  panel.hide()
 elif not panel.visible:
  if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
   var step: int=1 if event.is_action_pressed("ui_down") else -1
   var next: int=posmod(selected+step,6)
   if next==1:next=posmod(next+step,6)
   select(next)
  elif event.is_action_pressed("ui_accept"):activate(selected)
func clear_panel(title: String) -> void:
 for child in content.get_children():
  content.remove_child(child)
  child.queue_free()
 var heading:=Label.new()
 heading.text=title
 heading.add_theme_color_override("font_color",P.AMBER_GLOW)
 heading.add_theme_font_size_override("font_size",28)
 content.add_child(heading)
 panel.show()
func paragraph(value: String) -> void:
 var label:=Label.new()
 label.text=value
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.custom_minimum_size.x=650
 label.add_theme_color_override("font_color",P.WARM_CHALK)
 content.add_child(label)
func activate(index: int) -> void:
 if starting:return
 if index!=1:Sounds.ui(self,"confirm")
 match index:
  0:_start_game()
  1:return
  2:
   clear_panel("HOW TO PLAY")
   paragraph("WASD move · Shift sprint · Space jump\n1 pistol · 2 knife · 3 Crop Duster · 4 dagger · Wheel switches\nLMB fire / slash · RMB aim / stab\nR reload firearm · F inspect · Hold E repair\nV cycle carried burgers · E tray / bin / station\n1–4 choose station option · Shotguns bought at shop\nZ Shambler · X Scuttler · F2 auto-collect · L labels · Esc pause / settings\nR restarts after death, or while using the knife.")
  3:
   clear_panel("SETTINGS")
   var scroll:=ScrollContainer.new()
   scroll.custom_minimum_size=Vector2(650,340)
   content.add_child(scroll)
   var controls:=VBoxContainer.new()
   controls.add_theme_constant_override("separation",8)
   scroll.add_child(controls)
   Prefs.settings_controls(controls)
  4:
   clear_panel("CREDITS")
   var scroll:=ScrollContainer.new()
   scroll.custom_minimum_size=Vector2(650,280)
   content.add_child(scroll)
   var text:=Label.new()
   text.text=FileAccess.get_file_as_string("res://CREDITS.md")
   text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
   text.custom_minimum_size.x=620
   scroll.add_child(text)
  5:get_tree().quit()
 if index in [2,3,4]:
  var back:=Button.new()
  back.text="Back"
  back.pressed.connect(func():panel.hide())
  content.add_child(back)
func _notification(what: int) -> void:
 if DisplayServer.get_name()=="headless":return
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
  Engine.max_fps=15
  if video:video.paused=true
  Prefs.set_focused(false)
 elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
  Engine.max_fps=int(ProjectSettings.get_setting("application/run/max_fps",0))
  if video:video.paused=false
  Prefs.set_focused(true)
