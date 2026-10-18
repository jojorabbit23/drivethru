# First-person knife clip (needs a display):
#   godot --path . --fixed-fps 30 --write-movie docs/knife.avi --script res://tools/film_knife.gd
# Draw the knife, two slashes and a stab finish a Shambler in the kitchen.
extends SceneTree

var main: Node3D
var player: CharacterBody3D
var knife: Node
var z: Node3D
var t := 0.0
var done := {}

func _initialize() -> void:
	_setup.call_deferred()

func _setup() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	knife = player.get_node("Head/Camera3D/Knife")
	player.global_position = Vector3(0.9, 0.05, -1.4)
	player.rotation.y = -PI / 2.0
	z = main.spawn_zombie(main.get_node("ShopGreybox/Windows/Window_A"))
	z.state = 3   # hunt the player
	z.global_position = Vector3(4.6, 0.05, -1.6)
	process_frame.connect(_tick)

func once(key: String, at: float) -> bool:
	if t >= at and not done.has(key):
		done[key] = true
		return true
	return false

func _tick() -> void:
	t += 1.0 / 30.0
	if not is_instance_valid(z):
		quit()
		return
	var cam: Camera3D = player.get_node("Head/Camera3D")
	if not z.is_dead():
		var aim := z.global_position + Vector3(0, 1.2, 0)
		var dir := aim - cam.global_position
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-dir.x, -dir.z), 0.2)
		var head: Node3D = player.get_node("Head")
		head.rotation.x = lerpf(head.rotation.x, atan2(dir.y, Vector2(dir.x, dir.z).length()), 0.2)
	if once("draw", 0.6):
		player.switch_weapon(1)
	var close := z.global_position.distance_to(player.global_position) < 1.75
	if close and not done.has("s1"):
		done["s1"] = t
		knife.request("slash")
	if done.has("s1") and once("s2", done["s1"] + 0.55):
		knife.request("slash")
	if done.has("s1") and once("st", done["s1"] + 1.15):
		knife.request("stab")
	if done.has("s1") and once("st2", done["s1"] + 2.0):
		knife.request("stab")
	if z.is_dead() and not done.has("dead"):
		done["dead"] = t
	if done.has("dead") and t - done["dead"] > 2.5:
		quit()
	if t > 25.0:
		quit()
