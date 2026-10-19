# Films one shot of the game trailer (needs a display). tools/make_trailer.py
# films every shot, then cuts them together with title cards and music:
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 \
#       --write-movie shot.avi --script res://tools/film_trailer.gd -- <shot>
# Shots: opening horde boards shotgun harvest grill build customer serve
#        upgrade lancer finale
# The game HUD is hidden except where a shot shows it on purpose (serve,
# upgrade); captions are drawn in the pixel font between letterbox bars.
extends SceneTree

const P = preload("res://core/palette.gd")
const Shotgun = preload("res://weapons/shotgun/shotgun_weapon.gd")

var main: Node3D
var player: CharacterBody3D
var pcam: Camera3D
var head: Node3D
var cam: Camera3D
var overlay: CanvasLayer
var caption: Label
var sub: Label
var _hud: CanvasLayer

func _initialize() -> void:
	_run.call_deferred()

func wait(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	var shot: String = args[0] if args.size() > 0 else "opening"
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.set_process_unhandled_input(false)
	pcam = player.get_node("Head/Camera3D")
	head = player.get_node("Head")
	pcam.rotation = Vector3.ZERO
	cam = Camera3D.new()
	cam.near = 0.03
	cam.fov = 55
	main.add_child(cam)
	for c in main.get_children():
		if c is CanvasLayer:
			_hud = c
	_build_overlay()
	await wait(3)
	show_hud(false)
	match shot:
		"opening":
			await opening()
		"horde":
			await horde()
		"boards":
			await boards()
		"shotgun":
			await shotgun()
		"harvest":
			await harvest()
		"grill":
			await grill()
		"build":
			await build()
		"customer":
			await customer()
		"serve":
			await serve()
		"upgrade":
			await upgrade()
		"lancer":
			await lancer()
		"finale":
			await finale()
	quit()

# ---------------------------------------------------------------- tools ----
func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 20
	root.add_child(overlay)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.size = Vector2(1280, 64)
		bar.position = Vector2(0, 0 if top else 656)
		overlay.add_child(bar)
	caption = Label.new()
	caption.add_theme_font_size_override("font_size", 54)
	caption.add_theme_color_override("font_color", P.AMBER_GLOW)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.size = Vector2(1280, 60)
	caption.position = Vector2(0, 560)
	caption.modulate.a = 0.0
	overlay.add_child(caption)
	sub = Label.new()
	sub.add_theme_font_size_override("font_size", 36)
	sub.add_theme_color_override("font_color", P.WARM_CHALK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(1280, 24)
	sub.position = Vector2(0, 622)
	sub.modulate.a = 0.0
	overlay.add_child(sub)

func show_hud(on: bool) -> void:
	if _hud:
		_hud.visible = on
	cam.current = not on
	pcam.current = on

func say(text: String, small := "", at_y := 560.0, size := 54) -> void:
	caption.text = text
	caption.position.y = at_y
	caption.add_theme_font_size_override("font_size", size)
	sub.text = small
	sub.position.y = at_y + size + 8
	var tw := caption.create_tween()
	tw.tween_property(caption, "modulate:a", 1.0, 0.25)
	if small != "":
		var tw2 := sub.create_tween()
		tw2.tween_interval(0.25)
		tw2.tween_property(sub, "modulate:a", 1.0, 0.25)

# camera glides from a to b (positions and look targets) over `frames`
func glide(from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, frames: int) -> void:
	for i in frames:
		var k := float(i) / maxf(frames - 1, 1)
		k = k * k * (3.0 - 2.0 * k)
		cam.global_position = from.lerp(to, k)
		cam.look_at(look_from.lerp(look_to, k), Vector3.UP)
		await process_frame

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
	player.global_position = Vector3(-3.0, 0.05, 3.0)   # back office, out of shot

# ---------------------------------------------------------------- shots ----
# Night. A slow push in on the shop and its roof sign; the title lands.
func opening() -> void:
	park_player()
	var w := win("A")
	var z: Node3D = main.spawn_zombie(w)
	z.global_position = w.lane_spawn()
	await glide(Vector3(-6.5, 1.4, -21.0), Vector3(-3.5, 2.0, -14.5), Vector3(-1.5, 2.6, -5.0), Vector3(-0.5, 2.8, -5.0), 70)
	say("THE DRIVE THRU", "A ZOMBIE SIEGE BURGER JOINT", 84, 72)
	await glide(Vector3(-3.5, 2.0, -14.5), Vector3(-2.6, 2.2, -12.8), Vector3(-0.5, 2.8, -5.0), Vector3(-0.3, 2.9, -5.0), 75)

# Down the lane: a Shambler, a Scuttler and a Lancer come for window A.
func horde() -> void:
	park_player()
	var w := win("A")
	var out: Vector3 = w.outward()
	var crowd := [main.spawn_zombie(w), main.spawn_scuttler(w), main.spawn_lancer(w)]
	var base: Vector3 = w.lane_spawn()
	var side := out.cross(Vector3.UP).normalized()
	for i in crowd.size():
		var c: Node3D = crowd[i]
		c.global_position = base - out * (2.5 + i * 1.6) + side * (0.7 - i * 0.7)
	var bp: Vector3 = w.breach_point()
	# from the window, looking up the lane as they come
	var eye := bp + out * 0.6 + Vector3(0, 1.25, 0)
	cam.global_position = eye
	cam.look_at(base - out * 4.0 + Vector3(0, 1.0, 0), Vector3.UP)
	say("THEY'RE HUNGRY", "", 560, 54)
	await glide(eye, eye - out * 0.3 + Vector3(0, 0.15, 0), base - out * 4.0 + Vector3(0, 1.0, 0), base - out * 5.5 + Vector3(0, 0.9, 0), 105)

# Outside window A: a Shambler tears the boards off.
func boards() -> void:
	park_player()
	var w := win("A")
	var out: Vector3 = w.outward()
	var side := out.cross(Vector3.UP).normalized()
	var z: Node3D = main.spawn_zombie(w)
	z.global_position = w.breach_point() + out * 0.6
	var wp: Vector3 = w.global_position
	cam.global_position = wp + out * 3.4 + side * 1.6 + Vector3(0, -0.2, 0)
	cam.look_at(wp, Vector3.UP)
	await wait(30)
	say("HOLD THE WINDOWS", "", 560, 54)
	await glide(wp + out * 3.4 + side * 1.6 + Vector3(0, -0.2, 0), wp + out * 2.8 + side * 1.1 + Vector3(0, -0.1, 0), wp, wp + Vector3(0, -0.1, 0), 110)

# First person in the kitchen: the shotgun meets a Shambler coming through.
func shotgun() -> void:
	var w := win("A")
	var sg: Node = Shotgun.new()
	sg.name = "Shotgun"
	player.add_weapon(sg)
	var z: Node3D = main.spawn_zombie(w)
	z.global_position = w.repair_point() + Vector3(-1.2, 0, 0)
	z.state = 3
	fp_look(w.repair_point() + Vector3(-4.6, 0, 0.3), z.global_position + Vector3(0, 1.1, 0))
	show_hud(true)
	_hud.visible = false
	await wait(14)
	say("DEFEND THE SHOP", "", 560, 54)
	for i in 26:
		fp_track(z)
		await process_frame
	sg.shoot()
	for i in 34:
		fp_track(z)
		await process_frame
	if is_instance_valid(z) and not z.is_dead():
		sg.shoot()
	await wait(40)

# A body drops its glowing mushroom; it spins, and flies to you.
func harvest() -> void:
	park_player()
	var at := Vector3(2.4, 0.0, -2.9)
	var econ: Node = main.economy
	main.drop_pickup(at, "blue")
	main.drop_pickup(at + Vector3(0.7, 0, 0.5), "red")
	main.drop_pickup(at + Vector3(-0.6, 0, 0.6), "brown")
	cam.global_position = at + Vector3(-0.2, 0.75, 2.3)
	cam.look_at(at + Vector3(0, 0.4, 0.1), Vector3.UP)
	await wait(20)
	say("HARVEST WHAT THEY DROP", "COMMON  ·  BLUE  ·  RED", 530, 54)
	await glide(at + Vector3(-0.2, 0.75, 2.3), at + Vector3(0.1, 0.6, 1.6), at + Vector3(0, 0.4, 0.1), at + Vector3(0, 0.42, 0.2), 105)

# The grill: whole mushrooms drop on and get pressed; one is flipped.
func grill() -> void:
	park_player()
	var econ: Node = main.economy
	econ.store_mushrooms(4, "brown")
	econ.store_mushrooms(4, "blue")
	econ.store_mushrooms(4, "red")
	econ.add_cash(400)
	econ.upgrade_grill()
	await wait(2)
	var g: Node3D = main.grill
	var gp := g.global_position
	cam.global_position = gp + Vector3(0.1, 0.45, 0.62)
	cam.look_at(gp + Vector3(0, 0.03, 0), Vector3.UP)
	cam.fov = 50
	g.add_patty("brown")
	await wait(12)
	say("COOK THEM UP", "", 560, 54)
	g.add_patty("blue")
	await wait(14)
	g.add_patty("red")
	g.slots[0]["t"] = 2.2
	await wait(22)
	g.flip(0)
	await glide(cam.global_position, gp + Vector3(0.0, 0.38, 0.52), gp + Vector3(0, 0.03, 0), gp + Vector3(-0.05, 0.03, 0), 50)

# The prep bench builds and wraps a double.
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
	await wait(4)
	var bp: Vector3 = main.bench.global_position + Vector3(0.33, 0.05, 0.05)
	cam.global_position = bp + Vector3(-0.15, 0.32, 0.42)
	cam.look_at(bp, Vector3.UP)
	cam.fov = 45
	await wait(8)
	main.bench.bag(player)
	say("BUILD THE ORDER", "SINGLES  ·  DOUBLES  ·  THE SPECIAL", 530, 54)
	await wait(55)

# The armoured truck pulls up to the hatch and shows its order.
func customer() -> void:
	park_player()
	main.hatch.next_vehicle = "armored_truck"
	main.hatch.next_order = "special"
	var car: Node3D = main.hatch.spawn_customer()
	var stop: Vector3 = main.hatch.lane_stop
	say("FEED THE SURVIVORS", "", 560, 54)
	await glide(stop + Vector3(5.5, 1.0, -6.0), stop + Vector3(4.0, 1.4, -5.0), stop + Vector3(-6.0, 1.2, 0), stop + Vector3(-1.0, 1.4, 0), 120)

# First person at the hatch: serve it, get paid.
func serve() -> void:
	main.hatch.next_order = "blue"
	var car: Node3D = main.hatch.spawn_customer()
	car.position = main.hatch.lane_stop - Vector3(car.CAB_FROM_CENTRE, 0, 0)
	car.state = "waiting"
	player.set_held("burger", {"kind": "blue", "quality": "perfect", "patties": ["blue"]})
	fp_look(Vector3(-3.0, 0, -3.75), main.hatch.global_position + Vector3(0, 0.45, -0.6))
	player.switch_weapon(1)
	show_hud(true)
	await wait(30)
	player.use_focus()
	await wait(50)

# The shop terminal: the shotgun on the weapons page.
func upgrade() -> void:
	var econ: Node = main.economy
	econ.add_cash(260)
	player.switch_weapon(1)
	fp_look(Vector3(-2.9, 0, 3.4), main.terminal.global_position + Vector3(0, 0.18, 0))
	show_hud(true)
	await wait(10)
	player.use_focus()
	await wait(18)
	player.use_focus()
	await wait(22)
	say("GEAR UP", "", 420, 54)
	await wait(14)
	player.choose(1)
	await wait(26)

# The Lancer pries at the boards; its lances come through the gap.
func lancer() -> void:
	var w := win("A")
	var z: Node3D = main.spawn_lancer(w)
	z.global_position = w.breach_point() + w.outward() * 0.5
	player.switch_weapon(1)
	player.global_position = w.repair_point() + Vector3(0, 0.05, 0)
	var e: Vector3 = w.global_position - (w.repair_point() + Vector3(0, 1.65, 0))
	player.rotation.y = atan2(-e.x, -e.z)
	head.rotation.x = atan2(e.y, Vector2(e.x, e.z).length())
	show_hud(true)
	_hud.visible = false
	await wait(45)
	say("SURVIVE THE NIGHT", "", 560, 54)
	await wait(95)

# End card over the sign.
func finale() -> void:
	park_player()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.size = Vector2(1280, 720)
	overlay.add_child(bg)
	overlay.move_child(bg, 0)
	await glide(Vector3(-1.5, 2.6, -12.0), Vector3(-1.2, 2.7, -11.0), Vector3(-0.4, 2.9, -5.0), Vector3(-0.4, 2.9, -5.0), 25)
	var tw := bg.create_tween()
	tw.tween_property(bg, "color:a", 0.75, 0.5)
	say("THE DRIVE THRU", "OPEN ALL NIGHT.  MOSTLY.", 150, 72)
	await glide(Vector3(-1.2, 2.7, -11.0), Vector3(-1.0, 2.75, -10.4), Vector3(-0.4, 2.9, -5.0), Vector3(-0.4, 2.9, -5.0), 95)
