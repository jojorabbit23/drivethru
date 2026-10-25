extends "res://player/test_gun.gd"
func _init() -> void:
 viewmodel_scene=preload("res://weapons/pistol/pistol_viewmodel.tscn")
 arms_fit="desert_eagle"
 shot_sounds=[preload("res://weapons/desert_eagle/audio/shot.wav")]
 slide_sound=preload("res://weapons/desert_eagle/audio/slide.wav")
 display_name="DESERT EAGLE"
 damage=60.0
 fire_interval=0.32
 mag_size=7
 start_reserve=21
 reload_time=1.4
 shot_volume_db=-6.0
