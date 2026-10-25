# Films every weapon in the shared AKS arms: draw, fire, reload.
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 \
#     --write-movie /tmp/fps_arms.avi --script res://tools/film_fps_arms.gd
extends SceneTree
const Shotgun = preload("res://weapons/shotgun/shotgun_weapon.gd")
const DesertEagle = preload("res://weapons/desert_eagle/desert_eagle.gd")
func _initialize() -> void:
	run.call_deferred()
func wait(n: int) -> void:
	for i in n:
		await process_frame
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	player.set_process_unhandled_input(false)
	await wait(4)
	player.global_position = Vector3(-1.0, 0.1, 1.5)
	player.rotation.y = PI * 0.5
	player.get_node("Head").rotation.x = -0.05
	var cam: Node3D = player.get_node("Head/Camera3D")
	var eagle: Node3D = DesertEagle.new(); eagle.name = "DesertEagle"; player.add_weapon(eagle, false)
	var pump: Node3D = Shotgun.new(); pump.name = "Shotgun"; player.add_weapon(pump, false)
	for w in [cam.get_node("TestGun"), eagle, cam.get_node("Knife"), cam.get_node("Dagger"), cam.get_node("CropDuster"), pump]:
		w.set_meta("purchased", true)
		player.switch_weapon(player.weapons.find(w))
		await wait(24)
		for shot in 2:
			if w.has_method("shoot"):
				w.shoot()
			elif w.has_method("fire"):
				w.fire()
			elif w.has_method("request"):
				w.request("slash" if shot == 0 else "stab")
			await wait(26)
		if "mag" in w:
			w.mag = 0 if w != pump else 3
		if w.has_method("reload"):
			w.reload()
			await wait(70)
		await wait(10)
	quit()
