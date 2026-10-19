# Films one portrait (720x1280) shot for the YouTube Shorts (needs a display).
# tools/make_shorts.py films and edits them:
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 \
#       --write-movie shot.avi --script res://tools/film_shorts.gd -- <shot> "<hook>" "<caption>"
# The hook sits in a band near the top for the whole short; the caption is
# lower down, both clear of the Shorts buttons (bottom and right edges).
extends SceneTree

const P = preload("res://core/palette.gd")
const Shotgun = preload("res://weapons/shotgun/shotgun_weapon.gd")

var main: Node3D
var player: CharacterBody3D
var pcam: Camera3D
var head: Node3D
var cam: Camera3D
var overlay: CanvasLayer
var hook: Label
var caption: Label
var _hud: CanvasLayer

func _initialize() -> void:
	_run.call_deferred()

func wait(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	root.size = Vector2i(720, 1280)
	var args := OS.get_cmdline_user_args()
	var shot: String = args[0] if args.size() > 0 else "kill"
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.set_process_unhandled_input(false)
	pcam = player.get_node("Head/Camera3D")
	pcam.fov = 88
	head = player.get_node("Head")
	pcam.rotation = Vector3.ZERO
	cam = Camera3D.new()
	cam.near = 0.03
	cam.fov = 72
	main.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 30, 0)
	for c in main.get_children():
		if c is CanvasLayer:
			_hud = c
			c.visible = false
	_build_overlay(args[1] if args.size() > 1 else "", args[2] if args.size() > 2 else "")
	await wait(3)
	match shot:
		"kill": await kill()
		"drop": await drop()
		"grill": await grill()
		"grill_long": await grill_long()
		"build": await build()
		"truck": await truck()
		"serve": await serve()
		"lancer_lane": await lancer_lane()
		"lancer_pry": await lancer_pry()
		"lancer_stab": await lancer_stab()
		"lancer_kill": await lancer_kill()
		"endcard": await endcard()
	quit()

# ---------------------------------------------------------------- tools ----
func _label(size: int, colour: Color, y: float) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size = Vector2(640, 10)
	l.position = Vector2(40, y)
	overlay.add_child(l)
	return l

func _build_overlay(hook_text: String, caption_text: String) -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 20
	root.add_child(overlay)
	if hook_text != "":
		var band := ColorRect.new()
		band.color = Color(P.MIDNIGHT_TYNE, 0.82)
		band.size = Vector2(720, 236)
		band.position = Vector2(0, 118)
		overlay.add_child(band)
	hook = _label(54, P.AMBER_GLOW, 150)
	hook.text = hook_text
	caption = _label(36, P.WARM_CHALK, 870)
	caption.text = caption_text
	caption.modulate.a = 0.0
	var tw := caption.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(caption, "modulate:a", 1.0, 0.2)

func glide(from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, frames: int) -> void:
	for i in frames:
		var k := float(i) / maxf(frames - 1, 1)
		k = k * k * (3.0 - 2.0 * k)
		cam.global_position = from.lerp(to, k)
		cam.look_at(look_from.lerp(look_to, k), Vector3.UP)
		await process_frame

func first_person() -> void:
	cam.current = false
	pcam.current = true

func fp_look(stand: Vector3, at: Vector3) -> void:
	player.global_position = stand + Vector3(0, 0.05, 0)
	var e := at - (stand + Vector3(0, 1.65, 0))
	player.rotation.y = atan2(-e.x, -e.z)
	head.rotation.x = atan2(e.y, Vector2(e.x, e.z).length())

func fp_track(target: Node3D, h := 1.1) -> void:
	if not is_instance_valid(target):
		return
	var e := target.global_position + Vector3(0, h, 0) - pcam.global_position
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-e.x, -e.z), 0.35)
	head.rotation.x = lerpf(head.rotation.x, atan2(e.y, Vector2(e.x, e.z).length()), 0.35)

func win(id: String) -> Node3D:
	return main.get_node("ShopGreybox/Windows/Window_" + id)

func park_player() -> void:
	player.global_position = Vector3(-3.0, 0.05, 3.0)

func shotgun() -> Node:
	var sg: Node = Shotgun.new()
	sg.name = "Shotgun"
	player.add_weapon(sg)
	return sg

# ---------------------------------------------------------------- shots ----
func kill() -> void:
	var w := win("A")
	var sg := shotgun()
	var z: Node3D = main.spawn_zombie(w)
	z.global_position = w.repair_point() + Vector3(-1.0, 0, 0)
	z.state = 3
	fp_look(w.repair_point() + Vector3(-4.0, 0, 0.2), z.global_position + Vector3(0, 1.1, 0))
	first_person()
	for i in 30:
		fp_track(z)
		await process_frame
	sg.shoot()
	for i in 34:
		fp_track(z)
		await process_frame
	if is_instance_valid(z) and not z.is_dead():
		sg.shoot()
	await wait(36)

func drop() -> void:
	park_player()
	var at := Vector3(2.4, 0.0, -2.9)
	var m: Node3D = main.drop_pickup(at, "blue")
	# follow the mushroom: it pops out and settles wherever it lands
	for i in 92:
		var k := float(i) / 91.0
		var p: Vector3 = m.global_position if is_instance_valid(m) else at
		cam.global_position = p + Vector3(0.0, 0.55, 1.4).lerp(Vector3(0.05, 0.45, 0.9), k * k * (3.0 - 2.0 * k))
		cam.look_at(p + Vector3(0, 0.05, 0), Vector3.UP)
		await process_frame

func _grill_setup() -> Node3D:
	park_player()
	var econ: Node = main.economy
	for k in ["brown", "blue", "red"]:
		econ.store_mushrooms(4, k)
	econ.add_cash(400)
	econ.upgrade_grill()
	return main.grill

func grill() -> void:
	park_player()
	for k in ["blue", "red"]:
		main.economy.store_mushrooms(2, k)
	var g: Node3D = main.grill              # the starter grill: two slots fit a tall frame
	await wait(2)
	var gp := g.global_position
	cam.global_position = gp + Vector3(0.0, 0.8, 0.62)
	cam.look_at(gp + Vector3(0, 0.03, 0), Vector3.UP)
	g.add_patty("blue")
	await wait(20)
	g.add_patty("red")
	await wait(16)
	g.slots[0]["t"] = 2.3
	await wait(10)
	g.flip(0)
	await glide(cam.global_position, gp + Vector3(-0.1, 0.62, 0.5), gp + Vector3(0, 0.03, 0), gp + Vector3(-0.15, 0.03, 0), 45)

# the ASMR one: slower, closer, all three kinds, a flip, the ready bell
func grill_long() -> void:
	var g := _grill_setup()
	await wait(2)
	var gp := g.global_position
	cam.fov = 60
	cam.global_position = gp + Vector3(-0.38, 0.45, 0.48)
	cam.look_at(gp + Vector3(-0.38, 0.03, 0), Vector3.UP)
	g.add_patty("brown")
	await wait(28)
	g.add_patty("blue")
	await glide(cam.global_position, gp + Vector3(0.0, 0.47, 0.5), gp + Vector3(-0.38, 0.03, 0), gp + Vector3(0.0, 0.03, 0), 30)
	g.add_patty("red")
	await wait(30)
	g.slots[0]["t"] = 3.0
	g.slots[1]["t"] = 2.6
	await glide(cam.global_position, gp + Vector3(-0.3, 0.42, 0.44), gp + Vector3(0.0, 0.03, 0), gp + Vector3(-0.38, 0.03, 0), 20)
	g.flip(0)
	await wait(36)
	g.slots[0]["t"] = 5.85
	g.slots[1]["t"] = 5.9
	await glide(cam.global_position, gp + Vector3(-0.1, 0.75, 0.75), gp + Vector3(-0.38, 0.03, 0), gp + Vector3(-0.1, 0.05, 0), 60)
	await wait(20)

func build() -> void:
	park_player()
	var econ: Node = main.economy
	econ.store_mushrooms(2, "blue")
	econ.served = 3
	var g: Node3D = main.grill
	main.hatch.next_order = "double_blue"
	main.hatch.spawn_customer()
	g.add_patty("blue")
	g.add_patty("blue")
	await wait(20)
	g.slots[0]["t"] = 6.3
	g.slots[1]["t"] = 6.6
	var bp: Vector3 = main.bench.global_position + Vector3(0.33, 0.05, 0.05)
	cam.fov = 60
	cam.global_position = bp + Vector3(-0.05, 0.36, 0.34)
	cam.look_at(bp, Vector3.UP)
	await wait(8)
	main.bench.bag(player)
	await wait(50)

func truck() -> void:
	park_player()
	main.hatch.next_vehicle = "armored_truck"
	main.hatch.next_order = "blue"
	main.hatch.spawn_customer()
	var stop: Vector3 = main.hatch.lane_stop
	await glide(stop + Vector3(3.0, 1.0, -5.5), stop + Vector3(2.0, 1.3, -4.6), stop + Vector3(-7.0, 1.4, 0), stop + Vector3(-1.5, 1.6, 0), 100)

func serve() -> void:
	main.hatch.next_order = "blue"
	var car: Node3D = main.hatch.spawn_customer()
	car.position = main.hatch.lane_stop - Vector3(car.CAB_FROM_CENTRE, 0, 0)
	car.state = "waiting"
	player.set_held("burger", {"kind": "blue", "quality": "perfect", "patties": ["blue"]})
	player.switch_weapon(1)
	fp_look(Vector3(-3.0, 0, -3.6), main.hatch.global_position + Vector3(0, 0.6, -1.2))
	first_person()
	_hud.visible = true
	await wait(24)
	player.use_focus()
	await wait(56)

func lancer_lane() -> void:
	park_player()
	var w := win("A")
	var out: Vector3 = w.outward()
	var z: Node3D = main.spawn_lancer(w)
	z.global_position = w.lane_spawn() - out * 3.0
	var bp: Vector3 = w.breach_point()
	var eye := bp + out * 0.8 + Vector3(0, 0.5, 0)
	cam.global_position = eye
	cam.look_at(z.global_position + Vector3(0, 1.4, 0), Vector3.UP)
	for i in 100:
		if is_instance_valid(z):
			cam.look_at(cam.global_position.lerp(z.global_position + Vector3(0, 1.5, 0), 1.0), Vector3.UP)
		await process_frame

func lancer_pry() -> void:
	park_player()
	var w := win("A")
	var out: Vector3 = w.outward()
	var side := out.cross(Vector3.UP).normalized()
	var z: Node3D = main.spawn_lancer(w)
	z.global_position = w.breach_point() + out * 0.5
	var wp: Vector3 = w.global_position
	cam.global_position = wp + out * 2.6 + side * 1.3 + Vector3(0, 0.2, 0)
	cam.look_at(wp + Vector3(0, 0.0, 0), Vector3.UP)
	await wait(110)

func lancer_stab() -> void:
	var w := win("A")
	var z: Node3D = main.spawn_lancer(w)
	z.global_position = w.breach_point() + w.outward() * 0.5
	for i in 2:
		w.rip_board()
	player.switch_weapon(1)
	player.global_position = w.repair_point() + Vector3(0, 0.05, 0)
	var e: Vector3 = w.global_position + Vector3(0, -0.1, 0) - (w.repair_point() + Vector3(0, 1.65, 0))
	player.rotation.y = atan2(-e.x, -e.z)
	head.rotation.x = atan2(e.y, Vector2(e.x, e.z).length())
	first_person()
	_hud.visible = true
	for c in _hud.get_children():
		if c is Label and (c as Label).text.begins_with("WASD"):
			(c as Label).visible = false
	await wait(120)

func lancer_kill() -> void:
	var w := win("A")
	var sg := shotgun()
	var z: Node3D = main.spawn_lancer(w)
	z.global_position = w.repair_point() + Vector3(-1.2, 0, 0.1)
	z.state = 3
	fp_look(w.repair_point() + Vector3(-4.2, 0, 0.3), z.global_position + Vector3(0, 1.6, 0))
	first_person()
	for i in 22:
		fp_track(z, 1.6)
		await process_frame
	sg.shoot()
	for i in 30:
		fp_track(z, 1.3)
		await process_frame
	sg.shoot()
	await wait(50)

func endcard() -> void:
	park_player()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.09, 0.9)   # dark enough that the roof sign doesn't double the title
	bg.size = Vector2(720, 1280)
	overlay.add_child(bg)
	overlay.move_child(bg, 0)
	var title := _label(54, P.AMBER_GLOW, 760)
	title.text = "THE DRIVE THRU"
	var sub := _label(36, P.WARM_CHALK, 840)
	sub.text = "FULL TRAILER ON THE CHANNEL"
	await glide(Vector3(-1.4, 2.4, -10.5), Vector3(-1.1, 2.5, -9.6), Vector3(-0.4, 2.9, -5.0), Vector3(-0.4, 2.9, -5.0), 75)
