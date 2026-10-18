# Renders preview screenshots of the shop into res://docs/previews/.
# Needs a display (not --headless):
#   godot --path . --script res://tools/capture_previews.gd
extends SceneTree

const OUT := "res://docs/previews/"

# name: [camera position, look-at target, hide roof?, orthographic size (0 = perspective)]
const SHOTS := {
	"01_plan_top": [Vector3(0, 40, 0.01), Vector3(0, 0, 0), true, 30.0],
	"02_starter_exterior": [Vector3(-13, 9.5, -13), Vector3(0, 1.0, 0), false, 0.0],
	"03_roof_off_layout": [Vector3(-11, 14, -12), Vector3(0, 0, 0.5), true, 0.0],
	"04_shop_counter": [Vector3(-1.1, 1.6, -1.2), Vector3(-3.4, 1.05, -4.6), false, 0.0],
	"05_kitchen_line": [Vector3(4.2, 1.6, -0.9), Vector3(2.2, 1.0, -4.6), false, 0.0],
	"06_kitchen_window_a": [Vector3(1.0, 1.6, -1.4), Vector3(6.0, 1.5, -2.4), false, 0.0],
	"07_lane_a_zombie_pov": [Vector3(16.0, 1.6, -2.4), Vector3(6.0, 1.6, -2.4), false, 0.0],
	"08_back_office": [Vector3(-0.9, 1.6, 0.9), Vector3(-4.2, 0.9, 3.9), false, 0.0],
	"09_storeroom": [Vector3(0.9, 1.6, 0.9), Vector3(4.6, 0.8, 4.0), false, 0.0],
	"10_rear_delivery": [Vector3(10, 3.0, 13), Vector3(2.5, 1.2, 5), false, 0.0],
	"11_from_the_road": [Vector3(5, 1.8, -13), Vector3(-2, 2.2, -5), false, 0.0],
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	main.set_script(null) # skip HUD / mouse capture
	root.add_child(main)
	var player: Node3D = main.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector3(0, -50, 0)
	var shop: Node3D = main.get_node("ShopGreybox")
	var cam := Camera3D.new()
	cam.near = 0.05
	cam.far = 200.0
	cam.fov = 70.0
	main.add_child(cam)
	cam.current = true
	for name in SHOTS:
		var s: Array = SHOTS[name]
		var hide_roof: bool = s[2]
		shop.get_node("Structure/Roof").visible = not hide_roof
		shop.get_node("Structure/Ceiling").visible = not hide_roof
		shop.get_node("ShopSign").visible = not hide_roof
		for path in ["Decor/Decor_Roof", "Decor/Decor_Shell"]:
			shop.get_node(path).visible = not hide_roof
		if s[3] > 0.0:
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = s[3]
		else:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.global_position = s[0]
		var up := Vector3.FORWARD if (s[0] as Vector3).x == 0.0 and (s[0] as Vector3).z < 0.1 and s[3] > 0.0 else Vector3.UP
		cam.look_at(s[1], up)
		for i in 12:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		print("saved ", name)
	quit()
