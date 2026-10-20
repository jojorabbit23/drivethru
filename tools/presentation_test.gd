extends SceneTree
const Prefs=preload("res://presentation/preferences.gd")
const Sounds=preload("res://presentation/audio_library.gd")
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1
func run() -> void:
 Prefs.configure()
 var count: int=AudioServer.bus_count
 Prefs.configure()
 check(AudioServer.bus_count==count,"audio configuration is idempotent")
 Prefs.set_value("effects",2.0,false)
 check(Prefs.values.effects==1.0,"volume is clamped")
 Prefs.set_value("sensitivity",0.0,false)
 check(Prefs.values.sensitivity==0.0005,"mouse sensitivity cannot become zero")
 Prefs.set_focused(false)
 check(AudioServer.is_bus_mute(0),"background audio mutes")
 Prefs.set_focused(true)
 check(not AudioServer.is_bus_mute(0),"foreground audio restores")
 for name: String in ["tile","grit","rubber","land","hurt","wood","groan","chitter","death","fridge","air","select","confirm","shotgun","mechanism","distant_drone","distant_moan","grinder"]:
  var sound: AudioStreamWAV=Sounds.sound(name)
  check(sound==Sounds.sound(name),name+" reuses cached stream")
  var peak: int=0
  for i in sound.data.size()/2:peak=maxi(peak,absi(sound.data.decode_s16(i*2)))
  check(peak>0 and peak<30000,name+" contains bounded audio")
 var path: String="res://.godot/presentation_test.cfg"
 check(Prefs.save_config(path)==OK,"settings serialize successfully")
 var stored:=ConfigFile.new()
 check(stored.load(path)==OK and stored.get_value("presentation","effects")==1.0 and stored.get_value("presentation","mute_unfocused")==true,"saved settings preserve numeric and boolean values")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 await physics_frame
 var player: CharacterBody3D=main.get_node("Player")
 var pause: CanvasLayer=player.get_node("PauseMenu")
 var position: Vector3=player.position
 pause.open()
 check(paused and pause.opened and pause.screen.visible,"pause opens and freezes scene tree")
 for i in 5:await process_frame
 check(player.position.is_equal_approx(position),"player stays fixed while paused")
 pause.show_settings()
 check(pause.settings and pause.content.get_child_count()==12,"audio, comfort and lighting controls are available")
 pause.home()
 pause.resume()
 check(not paused and not pause.screen.visible,"resume restores gameplay")
 await create_timer(0.1).timeout
 main.free()
 print("%d failure(s)" % failures)
 quit(failures)
