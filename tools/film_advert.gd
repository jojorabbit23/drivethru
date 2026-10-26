# The advert's in-game blockout, one continuous first-person take that follows
# the owner's script (docs/video/advert/SCRIPT.md): back office, magazine and
# cigarette, the phone, the pump shotgun through window B, the kitchen (patty
# toss, flip, knife), the box, the hatch hand-over, then the horde. Clean frames
# (no HUD, no captions) for a video generator to build on; the title card last.
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 \
#       --resolution 1920x1080 --write-movie /tmp/advert.avi --script res://tools/film_advert.gd
# tools/make_advert.py runs this, then cuts keyframes per beat (beats.json).
extends SceneTree

const P = preload("res://core/palette.gd")
const Shotgun = preload("res://weapons/shotgun/shotgun_weapon.gd")
const Icons = preload("res://game/icons.gd")
const Sfx = preload("res://game/sfx.gd")
const Radio = preload("res://game/kitchen_radio.gd")
const FPS := 30.0
const SEATED := 1.12          # eye height in the chair
const STANDING := 1.6
const CHAIR := Vector3(-2.85, 0.0, 3.62)
const PHONE_AT := Vector3(-2.22, 0.77, 4.52)

var main: Node3D
var player: CharacterBody3D
var head: Node3D
var pcam: Camera3D
var frame := 0
var beats: Array = []
var yaw := 0.0
var pitch := 0.0
var music: AudioStreamPlayer
var props: Node3D
var magazine: Node3D
var page: Node3D
var smoke: CPUParticles3D
var cigarette: Node3D
var sg: Node
var knife: Node
var truck: Node3D
var overlay: CanvasLayer
var fade: ColorRect

func _initialize() -> void:
	_run.call_deferred()

func wait(n: int) -> void:
	for i in n:
		await process_frame
		frame += 1

func secs(s: float) -> int:
	return int(round(s * FPS))

func beat(name: String, note: String) -> void:
	beats.append({"name": name, "frame": frame, "note": note})
	print("BEAT %4d %s" % [frame, name])

# ------------------------------------------------------------- camera ----
func eye() -> Vector3:
	return pcam.global_position

func apply_view() -> void:
	player.rotation.y = yaw
	head.rotation.x = clampf(pitch, deg_to_rad(-80), deg_to_rad(80))

func angles_to(target: Vector3, from := Vector3.INF) -> Vector2:
	var e := target - (eye() if from == Vector3.INF else from)
	return Vector2(atan2(-e.x, -e.z), atan2(e.y, Vector2(e.x, e.z).length()))

func snap_look(target: Vector3) -> void:
	var a := angles_to(target)
	yaw = a.x
	pitch = a.y
	apply_view()

# turn to look at `target` over `frames` (eased; a fast whip if `snap`)
func turn(target: Vector3, frames: int, snap := false) -> void:
	var y0 := yaw
	var p0 := pitch
	for i in frames:
		var a := angles_to(target)
		var k := float(i + 1) / frames
		k = 1.0 - pow(1.0 - k, 3.0) if snap else k * k * (3.0 - 2.0 * k)
		yaw = lerp_angle(y0, a.x, k)
		pitch = lerpf(p0, a.y, k)
		apply_view()
		await wait(1)

# keep looking at a moving target for a while
func track(target: Callable, frames: int, rate := 0.25) -> void:
	for i in frames:
		var a := angles_to(target.call())
		yaw = lerp_angle(yaw, a.x, rate)
		pitch = lerpf(pitch, a.y, rate)
		apply_view()
		await wait(1)

# walk the feet through `path` at `speed` m/s, looking where `look` says
# (a Vector3 to face, or null to face the way of travel)
func walk(path: Array, speed: float, look = null) -> void:
	var pos := player.global_position
	for p in path:
		var to: Vector3 = p
		var d := pos.distance_to(to)
		var n := maxi(1, int(d / speed * FPS))
		var from := pos
		for i in n:
			var k := float(i + 1) / n
			var prev := pos
			pos = from.lerp(to, k)
			player.global_position = pos
			player.velocity = (pos - prev) * FPS
			var at: Vector3 = (pos + (to - from).normalized() * 3.0 + Vector3(0, STANDING - 0.15, 0)) if look == null else look
			var a := angles_to(at)
			yaw = lerp_angle(yaw, a.x, 0.18)
			pitch = lerpf(pitch, a.y, 0.18)
			apply_view()
			await wait(1)
	player.velocity = Vector3.ZERO

func eye_height(h: float, frames: int) -> void:
	var h0 := head.position.y
	for i in frames:
		var k := float(i + 1) / frames
		head.position.y = lerpf(h0, h, k * k * (3.0 - 2.0 * k))
		await wait(1)

# ------------------------------------------------------------- set up ----
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn", false)
	root.add_child(main)
	player = main.get_node("Player")
	player.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player.set("max_health", 100000.0)
	player.set("health", 100000.0)
	head = player.get_node("Head")
	pcam = head.get_node("Camera3D")
	pcam.fov = 70.0
	main.hatch.auto = false
	main.delivery.set("auto", false)
	main.set("max_zombies", 80)
	for c in main.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	for w in player.weapons:
		w.set_active(false)
	main.economy.store_mushrooms(4, "brown")
	main.economy.add_cash(500)
	_build_props()
	_build_overlay()
	music = AudioStreamPlayer.new()
	music.stream = load(Radio.TRACKS[0])
	music.volume_db = -14.0
	music.bus = "Master"
	main.add_child(music)
	await wait(4)
	await office()
	await call_scene()
	await shotgun_scene()
	await to_kitchen()
	await grill_scene()
	await stab_scene()
	await box_scene()
	await hatch_scene()
	await swamp_scene()
	await title_card()
	var f := FileAccess.open(args[0] if args.size() > 0 else "user://advert_beats.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"fps": FPS, "frames": frame, "beats": beats}, "  "))
		f.close()
	quit()

func _build_props() -> void:
	props = Node3D.new()
	props.name = "AdvertProps"
	main.add_child(props)
	# a warm desk lamp so the office reads (the room is otherwise dark)
	var lamp := OmniLight3D.new()
	lamp.light_color = P.AMBER_GLOW
	lamp.light_energy = 1.6
	lamp.omni_range = 4.5
	lamp.position = Vector3(-2.6, 2.1, 3.9)
	props.add_child(lamp)
	# the wired desk phone: base, keypad, handset on its cradle
	var phone := Node3D.new()
	phone.name = "DeskPhone"
	phone.position = PHONE_AT
	phone.rotation.y = deg_to_rad(-25)
	props.add_child(phone)
	_box(phone, Vector3(0.2, 0.06, 0.16), Vector3(0, 0.03, 0), P.BURNT_ORANGE)
	_box(phone, Vector3(0.09, 0.008, 0.07), Vector3(0, 0.063, 0.03), P.WET_CHARCOAL)
	var handset := _box(phone, Vector3(0.22, 0.045, 0.055), Vector3(0, 0.09, -0.04), P.BURNT_ORANGE)
	handset.name = "Handset"
	for x in [-0.09, 0.09]:
		_box(phone, Vector3(0.05, 0.03, 0.06), Vector3(x, 0.066, -0.04), P.WET_CHARCOAL)
	# the magazine in the lap, on the camera so it stays put while we read
	magazine = Node3D.new()
	magazine.name = "MushroomMonthly"
	pcam.add_child(magazine)
	magazine.position = Vector3(-0.02, -0.16, -0.52)
	magazine.rotation = Vector3(deg_to_rad(-22), deg_to_rad(4), deg_to_rad(-3))   # top tipped away, lying in the lap
	_quad(magazine, Vector2(0.3, 0.39), Vector3.ZERO, P.WARM_CHALK)
	_quad(magazine, Vector2(0.3, 0.07), Vector3(0, 0.16, 0.001), P.BURNT_ORANGE)
	var title := _label(magazine, "MUSHROOM MONTHLY", Vector3(0, 0.16, 0.002), P.WARM_CHALK, 22)
	title.outline_size = 0
	var big := Icons.sprite("mushroom_brown", 0.012)
	big.position = Vector3(0, -0.01, 0.003)
	big.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	big.no_depth_test = false
	magazine.add_child(big)
	_label(magazine, "GIANT OYSTERS\nGROW YOUR OWN", Vector3(0, -0.15, 0.002), P.MIDNIGHT_TYNE, 18).outline_size = 0
	# a page that turns over (hinged on the spine, the cover's left edge)
	page = Node3D.new()
	page.position = Vector3(-0.15, 0, 0.004)
	magazine.add_child(page)
	_quad(page, Vector2(0.29, 0.38), Vector3(0.145, 0, 0), P.WARM_CHALK.darkened(0.06))
	page.visible = false
	# a cigarette between the fingers, low right, with a smoke wisp
	cigarette = Node3D.new()
	pcam.add_child(cigarette)
	cigarette.position = Vector3(0.2, -0.24, -0.38)
	cigarette.rotation = Vector3(0, deg_to_rad(-30), deg_to_rad(80))
	var stick := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0045
	cm.bottom_radius = 0.0045
	cm.height = 0.075
	stick.mesh = cm
	stick.material_override = _mat(P.WARM_CHALK)
	cigarette.add_child(stick)
	var tip := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0047
	tm.bottom_radius = 0.0047
	tm.height = 0.008
	tip.mesh = tm
	var tmat := _mat(P.AMBER_GLOW)
	tmat.emission_enabled = true
	tmat.emission = P.AMBER_GLOW
	tip.material_override = tmat
	tip.position.y = 0.04
	cigarette.add_child(tip)
	smoke = CPUParticles3D.new()
	smoke.amount = 40
	smoke.lifetime = 2.2
	smoke.local_coords = false
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.05
	smoke.initial_velocity_max = 0.1
	smoke.gravity = Vector3(0.01, 0.03, 0)
	smoke.scale_amount_min = 0.01
	smoke.scale_amount_max = 0.025
	var sq := QuadMesh.new()
	sq.size = Vector2.ONE
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.albedo_color = Color(P.CONCRETE_GREY, 0.25)
	sq.material = smat
	smoke.mesh = sq
	smoke.position.y = 0.045
	cigarette.add_child(smoke)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = at
	m.material_override = _mat(c)
	parent.add_child(m)
	return m

func _quad(parent: Node3D, size: Vector2, at: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	m.mesh = q
	m.position = at
	var mat := _mat(c)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # print reads clearly in the dark office
	m.material_override = mat
	parent.add_child(m)
	return m

func _label(parent: Node3D, text: String, at: Vector3, c: Color, size: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = preload("res://fonts/pixel/pixel_font.tres")
	l.font_size = size
	l.pixel_size = 0.0011
	l.modulate = c
	l.position = at
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 50
	main.add_child(overlay)
	fade = ColorRect.new()
	fade.color = Color(P.MIDNIGHT_TYNE, 1.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(fade)

func fade_to(a: float, frames: int) -> void:
	var a0 := fade.color.a
	for i in frames:
		fade.color.a = lerpf(a0, a, float(i + 1) / frames)
		await wait(1)

func ramp_music(db: float, frames: int) -> void:
	var tw := music.create_tween()
	tw.tween_property(music, "volume_db", db, frames / FPS)

func window(id: String) -> Node3D:
	return main.get_node("ShopGreybox/Windows/Window_" + id)

func keep_body(z: Node) -> void:
	z.set("corpse_time", 600.0)

# ------------------------------------------------------------- beats ----
# FADE IN. Boots up, cigarette going, the magazine in the lap; pages turn.
func office() -> void:
	player.global_position = CHAIR + Vector3(0, 0.05, 0)
	head.position.y = SEATED
	yaw = PI                                   # facing the desk (+Z)
	pitch = deg_to_rad(-38)
	apply_view()
	music.play()
	beat("fade_in_office", "FADE IN. Back office, radio playing; first person, cigarette, MUSHROOM MONTHLY in the lap.")
	await fade_to(0.0, secs(1.5))
	await wait(secs(1.5))
	for n in 2:
		await turn_page()
		await wait(secs(1.2))
	beat("glance_up", "Screams outside (add in edit); you don't look up.")
	await turn(CHAIR + Vector3(0.1, 0.55, 1.4), secs(0.8))
	await wait(secs(0.6))
	await turn(CHAIR + Vector3(0.0, 0.2, 0.5), secs(0.8))
	await wait(secs(0.8))

func turn_page() -> void:
	page.visible = true
	page.rotation.y = 0.0
	for i in secs(0.5):
		page.rotation.y = -PI * float(i + 1) / secs(0.5)
		await wait(1)
	page.visible = false

# RIIIING. Sigh, reach back, pick up; squeaky chatter; "Yurrrp..."; slam it down.
func call_scene() -> void:
	beat("phone_rings", "RIIIIING: the old wired phone on the desk.")
	for i in 3:
		Sfx.play(main, "phone", -2.0)
		await wait(secs(0.9))
	await turn(PHONE_AT + Vector3(0, 0.1, 0), secs(0.7))
	beat("pick_up", "You reach over without looking and grab the receiver.")
	var handset: Node3D = props.get_node("DeskPhone/Handset")
	var hp0 := handset.global_position
	for i in secs(0.4):
		handset.global_position = hp0.lerp(eye() + pcam.global_basis * Vector3(0.12, -0.05, 0.05), float(i + 1) / secs(0.4))
		await wait(1)
	handset.visible = false
	cigarette.visible = true
	await turn(CHAIR + Vector3(0.6, 0.6, 2.2), secs(0.6))
	ramp_music(-22.0, secs(0.5))
	beat("caller_squeaks", "Panicked squeaky caller: SKRRT! CHK-CHK! EEEE! HRRRRK!")
	var voice := AudioStreamPlayer.new()
	voice.stream = load("res://tools/advert/phone_squirl.wav")
	voice.volume_db = -3.0
	main.add_child(voice)
	voice.play()
	for i in secs(4.4):
		head.rotation.z = sin(float(i) / FPS * 9.0) * 0.012   # small nods, as if it makes sense
		await wait(1)
	head.rotation.z = 0.0
	beat("yurrrp", "PLAYER: \"Yurrrp. No problem.\"")
	await wait(secs(1.6))
	beat("five_minutes", "PLAYER: \"Five minutes.\"")
	await wait(secs(1.2))
	beat("max", "Beat. A grin. PLAYER: \"MAX.\"")
	await wait(secs(1.0))
	beat("slam", "Slam the phone down.")
	await turn(PHONE_AT + Vector3(0, 0.1, 0), secs(0.25), true)
	handset.global_position = hp0
	handset.visible = true
	Sfx.play(main, "thunk", 2.0)
	await wait(secs(0.2))

# Launch from the chair, the pump shotgun, CHK-CHAK, spin: BOOM through window B.
func shotgun_scene() -> void:
	beat("launch", "Launch out of the chair; the music kicks in louder.")
	ramp_music(-8.0, secs(0.4))
	magazine.visible = false
	cigarette.visible = false
	var w := window("B")
	for i in 3:
		w.rip_board()
	var z: Node3D = main.spawn_scientist(w)
	keep_body(z)
	z.global_position = w.breach_point() + w.outward() * 0.45
	z.look_at(w.breach_point() - w.outward() * 2.0, Vector3.UP)
	await eye_height(STANDING, secs(0.35))
	sg = Shotgun.new()
	sg.name = "Shotgun"
	player.add_weapon(sg)
	beat("grab_shotgun", "A well-worn pump shotgun snatched up. CHK-CHAK.")
	await wait(secs(0.45))
	sg.set("_cycle", float(sg.get("cycle_time")))   # rack it
	await wait(secs(0.5))
	var head_at := func() -> Vector3:
		return (z.global_position + Vector3(0, 1.62, 0)) if is_instance_valid(z) else w.breach_point() + Vector3(0, 1.6, 0)
	beat("spin", "You spin to the office window: a mushroom zombie bursting through.")
	await turn(head_at.call(), secs(0.35), true)
	await track(head_at, secs(0.4), 0.5)
	beat("boom", "BOOM: its head comes clean off; the body drops out of sight.")
	sg.shoot()
	if is_instance_valid(z) and not z.is_dead():
		z.take_damage(10000.0, true, {"pos": head_at.call(), "dir": (head_at.call() - eye()).normalized()})
	await wait(secs(1.4))

# Without breaking stride, through the shop floor into the kitchen.
func to_kitchen() -> void:
	beat("walk_to_kitchen", "Without breaking stride, out of the office into the kitchen.")
	await walk([Vector3(-3.0, 0.05, 1.2), Vector3(-3.0, 0.05, -1.0), Vector3(-1.2, 0.05, -2.4), Vector3(0.6, 0.05, -2.6)], 2.2)
	# the customer pulls up meanwhile (served at the end)
	main.hatch.next_vehicle = "armored_truck"
	main.hatch.next_order = "brown"
	truck = main.hatch.spawn_customer()
	truck.patience = 600.0

# Grab a patty, toss it over a shoulder onto the grill; zombies gather outside.
func grill_scene() -> void:
	var grill: Node3D = main.grill
	var bench: Node3D = main.bench
	beat("grab_patty", "Pass the prep station, grab a raw patty.")
	await walk([Vector3(1.1, 0.05, -3.3)], 1.6, bench.global_position + Vector3(0, 0.0, 0))
	var slot_at: Vector3 = grill.global_position + Vector3(-0.32, 0.05, 0)
	var flier := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.065
	cyl.height = 0.03
	flier.mesh = cyl
	flier.material_override = _mat(P.BURNT_ORANGE.darkened(0.35))
	props.add_child(flier)
	var start := eye() + pcam.global_basis * Vector3(0.15, -0.2, -0.35)
	beat("toss", "Tossed casually over a shoulder; the camera follows it through the air.")
	var n := secs(0.9)
	for i in n:
		var k := float(i + 1) / n
		flier.global_position = start.lerp(slot_at, k) + Vector3(0, sin(k * PI) * 0.55, 0)
		flier.rotation.x += 0.45
		var a := angles_to(flier.global_position)
		yaw = lerp_angle(yaw, a.x, 0.3)
		pitch = lerpf(pitch, a.y, 0.3)
		apply_view()
		await wait(1)
	flier.queue_free()
	grill.add_patty("brown")
	beat("lands_sizzle", "It lands perfectly on the grill. SSSSSSSS.")
	await track(func() -> Vector3: return slot_at, secs(1.2), 0.2)
	# more zombies stagger into view outside window A
	var wa := window("A")
	for i in 3:
		wa.rip_board()
	var crowd: Array = []
	for i in 5:
		var z: Node3D = main.spawn_zombie(wa)
		keep_body(z)
		z.global_position = wa.lane_spawn() + wa.outward() * (1.5 + i * 1.3) + Vector3(0, 0, (i % 3 - 1) * 1.2)
		crowd.append(z)
	beat("crowd_outside", "Outside the side window, mushroom zombies stagger into view: one, three, five.")
	await turn(wa.global_position + wa.outward() * 3.0 + Vector3(0, -0.3, 0), secs(0.9))
	await wait(secs(2.0))
	beat("back_to_grill", "You ignore them. The burger comes first.")
	await turn(slot_at, secs(0.7))
	await walk([Vector3(1.9, 0.05, -3.55)], 1.2, slot_at)
	grill.slots[0]["t"] = 3.0
	await wait(secs(0.5))
	beat("flip", "Lean in. Turn it. Perfect.")
	grill.flip(0)
	await wait(secs(1.2))

# A zombie lunges in at the side; the knife, THUNK, into its face; back to work.
func stab_scene() -> void:
	var grill: Node3D = main.grill
	var slot_at: Vector3 = grill.global_position + Vector3(-0.32, 0.05, 0)
	var z: Node3D = main.spawn_zombie(window("A"))
	keep_body(z)
	z.global_position = Vector3(3.3, 0.0, -3.0)
	z.set("state", 3)                          # HUNT: straight for you
	knife = player.weapons[1]
	var face := func() -> Vector3:
		return (z.global_position + Vector3(0, 1.55, 0)) if is_instance_valid(z) else eye() + Vector3(1, 0, 0)
	await wait(secs(0.5))
	beat("lunge", "Movement in the corner of your eye: a zombie lunges in from the side.")
	await turn(face.call(), secs(0.3), true)
	player.switch_weapon(1)
	for i in secs(1.2):
		await track(face, 1, 0.5)
		if is_instance_valid(z) and z.global_position.distance_to(player.global_position) < 1.25:
			break
	beat("thunk", "Grab a kitchen knife. THUNK, straight into its face.")
	knife.request("stab")
	await track(face, secs(0.25), 0.5)
	if is_instance_valid(z) and not z.is_dead():
		z.take_damage(10000.0, true, {"pos": face.call(), "dir": (face.call() - eye()).normalized()})
	await track(face, secs(0.6), 0.3)
	beat("back_to_work", "It collapses. Pull the knife free, back to the grill.")
	await turn(slot_at, secs(0.6))
	await wait(secs(0.8))

# Bun, burger, wrap, box: fast and practised while they swarm the windows.
func box_scene() -> void:
	var grill: Node3D = main.grill
	var bench: Node3D = main.bench
	grill.slots[0]["t"] = 6.2                 # cooked through
	await wait(2)
	await walk([Vector3(0.95, 0.05, -3.55)], 1.4, bench.global_position + Vector3(0.3, 0.0, 0))
	await turn(bench.global_position + Vector3(0.33, 0.0, 0.05), secs(0.4))
	beat("box_burger", "Bun. Burger. Cheese. Sauce. Wrap. Box. Military precision.")
	bench.bag(player)
	# outside, they start breaking in at window A
	var wa := window("A")
	for i in 2:
		wa.rip_board()
	await wait(secs(1.6))
	beat("windows_cracking", "Hands slap the windows; boards start to give.")
	await turn(wa.global_position + Vector3(0, -0.2, 0), secs(0.6))
	await wait(secs(1.0))

# A short walk past the bodies to the hatch; the armoured truck; hand over.
func hatch_scene() -> void:
	for z in main.get_tree().get_nodes_in_group("zombies"):
		if is_instance_valid(z) and not z.is_dead():
			z.take_damage(10000.0, false, {})
	beat("walk_to_hatch", "A short walk through the kitchen, bodies scattered, radio still playing.")
	await walk([Vector3(0.6, 0.05, -2.5), Vector3(-1.2, 0.05, -2.6), Vector3(-3.0, 0.05, -3.75)], 2.0)
	if is_instance_valid(truck):
		truck.position = main.hatch.lane_stop - Vector3(truck.CAB_FROM_CENTRE, 0, 0)
	await turn(main.hatch.global_position + Vector3(0, 0.45, -1.2), secs(0.6))
	beat("truck_waiting", "A gigantic apocalypse-modified truck waits, engine growling.")
	await wait(secs(1.8))
	beat("hand_over", "The customer's hand with cash; you hand over the burger. Transaction complete.")
	main.hatch.serve(player)
	await wait(secs(0.8))
	beat("drives_away", "Customer drives away.")
	await track(func() -> Vector3: return (truck.global_position + Vector3(0, 1.4, 0)) if is_instance_valid(truck) else main.hatch.global_position + Vector3(4, 1, -3), secs(2.0), 0.08)

# Silence. A growl. Turn round: the place is packed. "Ah." CHK-CHAK. "Rush hour."
func swamp_scene() -> void:
	ramp_music(-40.0, secs(0.6))
	beat("silence", "For one glorious second: silence.")
	for id in ["A", "B"]:
		var w := window(id)
		while w.rip_board():
			pass
	var horde: Array = []
	var spots: Array = []
	for row in 4:
		for col in 5:
			spots.append(Vector3(-5.0 + col * 0.95 + (row % 2) * 0.4, 0.0, -2.3 + row * 0.85))
	for i in spots.size():
		var make: Callable = [main.spawn_zombie, main.spawn_zombie, main.spawn_scientist, main.spawn_scuttler, main.spawn_zombie][i % 5]
		var z: Node3D = make.call(window("B"))
		keep_body(z)
		z.global_position = spots[i]
		z.look_at(Vector3(-3.0, 0.0, -3.9), Vector3.UP)
		z.set_physics_process(false)            # frozen until the charge
		horde.append(z)
	await wait(secs(1.4))
	beat("growl_turn", "A low growl behind you. You slowly turn around.")
	await turn(Vector3(-3.0, 1.2, 1.0), secs(2.2))
	beat("horde_reveal", "The restaurant flooded with infected. Every window shattered.")
	player.switch_weapon(player.weapons.find(sg))
	await wait(secs(1.4))
	beat("ah", "PLAYER: \"Ah.\"")
	await wait(secs(1.0))
	beat("pump", "Pump the shotgun. CHK-CHAK.")
	sg.set("_cycle", float(sg.get("cycle_time")))
	await wait(secs(0.9))
	beat("rush_hour", "PLAYER: \"Rush hour.\"")
	ramp_music(-4.0, secs(0.3))
	await wait(secs(1.0))
	beat("charge", "The horde charges.")
	for z in horde:
		if is_instance_valid(z):
			z.set_physics_process(true)
			z.set("state", 3)
	await wait(secs(1.5))
	beat("cut_to_black", "CUT TO BLACK.")
	fade.color.a = 1.0
	await wait(secs(0.6))

func title_card() -> void:
	var big := Label.new()
	big.text = "ZOMBIE DRIVE-THRU"
	big.add_theme_font_override("font", preload("res://fonts/pixel/pixel_font.tres"))
	big.add_theme_font_size_override("font_size", 96)
	big.add_theme_color_override("font_color", P.AMBER_GLOW)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	big.position = Vector2(-700, -110)
	big.size = Vector2(1400, 120)
	overlay.add_child(big)
	var small := Label.new()
	small.text = "THE LUNCH RUSH NEVER ENDS."
	small.add_theme_font_override("font", preload("res://fonts/pixel/pixel_font.tres"))
	small.add_theme_font_size_override("font_size", 44)
	small.add_theme_color_override("font_color", P.WARM_CHALK)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	small.position = Vector2(-700, 30)
	small.size = Vector2(1400, 60)
	overlay.add_child(small)
	beat("title_card", "TITLE CARD: ZOMBIE DRIVE-THRU / The lunch rush never ends.")
	music.volume_db = -6.0
	await wait(secs(3.5))
