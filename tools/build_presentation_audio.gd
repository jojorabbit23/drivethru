# Rebuild the new long sounds offline so gameplay never synthesizes their first cue.
extends SceneTree
const Sounds=preload("res://presentation/audio_library.gd")
func _initialize() -> void:
 Sounds.generate_sources=true
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://presentation/audio"))
 for entry: Array in [["shotgun",4],["mechanism",1],["distant_drone",1],["distant_moan",4],["grinder",1]]:
  for variant in int(entry[1]):
   var name: String=entry[0]
   var stream: AudioStreamWAV=Sounds.sound(name,variant)
   var error: Error=stream.save_to_wav("res://presentation/audio/"+name+str(variant)+".wav")
   assert(error==OK)
 print("Built 11 presentation WAV files")
 quit()
