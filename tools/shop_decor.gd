# Starter-state decoration for the shop, based on the concept sheet
# (teal block walls, orange fascia, burger-and-crown mascot signs, timber
# palisades, crates, wall lamps; tiled interior with pipes, steel posts and
# furnished rooms). Called by build_shop.gd; every piece is a box or prism.
#
# Groups starting "Decor_" / "Props_" end up under ShopGreybox/Decor, one
# merged mesh each, so whole sets can be hidden or swapped for upgrade tiers.
extends RefCounted

const P = preload("res://core/palette.gd")

var b # the builder (tools/build_shop.gd)
var rng := RandomNumberGenerator.new()
var stored_fungus: Array=[]

func build(builder) -> void:
	b = builder
	rng.seed = 420
	shell()
	roof()
	exterior_lamps()
	frontage()
	yard()
	fences()
	interior_shell()
	shop_floor()
	kitchen()
	back_office()
	storeroom()

# ------------------------------------------------------------ helpers ----
func T(pos: Vector3, yaw_deg := 0.0, scale := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled(Vector3.ONE * scale), pos)

# Box in t's local space with an extra local rotation.
func rbox(g: String, mat: String, t: Transform3D, c: Vector3, s: Vector3, local_basis: Basis, collide := false) -> void:
	b.obox(g, mat, t * c, s, t.basis * local_basis, collide)

func rotz(deg: float) -> Basis:
	return Basis(Vector3.BACK, deg_to_rad(deg))

func rotx(deg: float) -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(deg))

func roty(deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(deg))

const ALONG_X := Basis(Vector3.BACK, -PI / 2)  # prism axis -> +X
const ALONG_Z := Basis(Vector3.RIGHT, PI / 2)  # prism axis -> +Z
const FACING_N := Basis(Vector3.RIGHT, -PI / 2) # prism axis -> -Z

func pipe_x(g: String, mat: String, x0: float, x1: float, y: float, z: float, r: float) -> void:
	b.prism(g, mat, Vector3(x0, y, z), r, x1 - x0, 6, ALONG_X)

func pipe_z(g: String, mat: String, z0: float, z1: float, y: float, x: float, r: float) -> void:
	b.prism(g, mat, Vector3(x, y, z0), r, z1 - z0, 6, ALONG_Z)

# Wall lamp; t sits on the wall face with +Z pointing away from the wall.
func wall_lamp(g: String, t: Transform3D, light_name: String, energy := 1.2, reach := 4.5) -> void:
	b.tbox(g, "metal", t, Vector3(0, 0.12, 0.01), Vector3(0.14, 0.2, 0.02))
	b.tbox(g, "metal", t, Vector3(0, 0.12, 0.16), Vector3(0.05, 0.05, 0.3))
	b.tbox(g, "metal", t, Vector3(0, 0.0, 0.32), Vector3(0.34, 0.1, 0.24))
	b.tbox(g, "lamp", t, Vector3(0, -0.06, 0.32), Vector3(0.28, 0.02, 0.18))
	for sx in [-0.1, 0.1]:
		b.tbox(g, "metal", t, Vector3(sx, -0.11, 0.32), Vector3(0.015, 0.09, 0.015))
	b.tbox(g, "metal", t, Vector3(0, -0.155, 0.32), Vector3(0.22, 0.015, 0.015))
	b.light(light_name, t * Vector3(0, -0.35, 0.45), P.AMBER_GLOW.lerp(P.WARM_CHALK, 0.45), energy, reach)

func crate(g: String, t: Transform3D, c: Vector3, size: float, yaw := 0.0, collide := true) -> void:
	rbox(g, "crate", t, c + Vector3(0, size * 0.5, 0), Vector3.ONE * size, roty(yaw), collide)

func carton(g: String, t: Transform3D, c: Vector3, s: Vector3, yaw := 0.0) -> void:
	rbox(g, "cardboard", t, c + Vector3(0, s.y * 0.5, 0), s, roty(yaw))

# Mascot: a grinning burger wearing a crown. Origin at the bottom centre,
# +Z faces the viewer. plate = square backing board (pole sign).
func burger_sign(g: String, t: Transform3D, plate: bool) -> void:
	if plate:
		b.tbox(g, "metal", t, Vector3(0, 1.15, -0.08), Vector3(2.3, 2.1, 0.12))
		b.tbox(g, "paint_orange", t, Vector3(0, 2.2, -0.03), Vector3(2.4, 0.08, 0.06))
		b.tbox(g, "paint_orange", t, Vector3(0, 0.1, -0.03), Vector3(2.4, 0.08, 0.06))
		for sx in [-1.17, 1.17]:
			b.tbox(g, "paint_orange", t, Vector3(sx, 1.15, -0.03), Vector3(0.08, 2.18, 0.06))
	# bottom bun, patty, lettuce, cheese
	b.tbox(g, "bun", t, Vector3(0, 0.5, 0.1), Vector3(1.2, 0.08, 0.2))
	b.tbox(g, "bun", t, Vector3(0, 0.62, 0.1), Vector3(1.45, 0.16, 0.2))
	b.tbox(g, "patty", t, Vector3(0, 0.78, 0.1), Vector3(1.56, 0.16, 0.22))
	b.tbox(g, "lettuce", t, Vector3(0, 0.89, 0.1), Vector3(1.62, 0.07, 0.24))
	for i in 6:
		rbox(g, "lettuce", t, Vector3(-0.68 + i * 0.27, 0.86, 0.1), Vector3(0.1, 0.1, 0.24), rotz(45))
	for x in [-0.42, 0.18, 0.55]:
		rbox(g, "cheese", t, Vector3(x, 0.84, 0.115), Vector3(0.13, 0.13, 0.22), rotz(45))
	# top bun with face
	b.tbox(g, "bun", t, Vector3(0, 1.02, 0.1), Vector3(1.52, 0.2, 0.2))
	b.tbox(g, "bun", t, Vector3(0, 1.2, 0.1), Vector3(1.3, 0.16, 0.2))
	b.tbox(g, "bun", t, Vector3(0, 1.32, 0.1), Vector3(0.95, 0.1, 0.2))
	for sx in [-0.22, 0.22]:
		b.tbox(g, "ink", t, Vector3(sx, 1.19, 0.205), Vector3(0.1, 0.14, 0.02))
		b.tbox(g, "chalk", t, Vector3(sx + 0.02, 1.23, 0.216), Vector3(0.035, 0.04, 0.01))
		b.tbox(g, "paint_orange", t, Vector3(sx * 1.85, 1.05, 0.205), Vector3(0.12, 0.05, 0.02))
		b.tbox(g, "ink", t, Vector3(sx * 0.85, 1.04, 0.205), Vector3(0.05, 0.07, 0.02))
	b.tbox(g, "ink", t, Vector3(0, 0.995, 0.205), Vector3(0.34, 0.045, 0.02))
	for s in [Vector2(-0.3, 1.33), Vector2(0.08, 1.35), Vector2(0.32, 1.31), Vector2(-0.52, 1.24), Vector2(0.52, 1.25)]:
		b.tbox(g, "chalk", t, Vector3(s.x, s.y, 0.205), Vector3(0.06, 0.025, 0.02))
	# crown
	b.tbox(g, "paint_orange", t, Vector3(0, 1.5, 0.1), Vector3(0.9, 0.14, 0.18))
	for x in [-0.33, 0.0, 0.33]:
		b.tbox(g, "paint_orange", t, Vector3(x, 1.7, 0.1), Vector3(0.16, 0.26, 0.16))
		rbox(g, "paint_amber", t, Vector3(x, 1.85, 0.1), Vector3(0.12, 0.12, 0.16), rotz(45))
	b.tbox(g, "gem", t, Vector3(0, 1.5, 0.195), Vector3(0.12, 0.08, 0.02))
	for x in [-0.3, 0.3]:
		b.tbox(g, "paint_amber", t, Vector3(x, 1.5, 0.195), Vector3(0.06, 0.06, 0.02))

# Spanish-rider style X barricade, 2.4 m long along local X.
func cheval(g: String, t: Transform3D) -> void:
	b.tprism(g, "wood", t, Vector3(-1.2, 0.55, 0), 0.07, 2.4, 6, ALONG_X)
	for x in [-0.95, 0.0, 0.95]:
		rbox(g, "wood", t, Vector3(x, 0.55, 0), Vector3(0.09, 1.45, 0.09), rotx(45))
		rbox(g, "wood", t, Vector3(x + 0.06, 0.55, 0), Vector3(0.09, 1.45, 0.09), rotx(-45))

# Steel shelving with stock. Footprint x0..x1, z0..z1, items packed along the long side.
func shelf_unit(g: String, x0: float, x1: float, z0: float, z1: float, h: float, levels: int) -> void:
	var along_x := (x1 - x0) >= (z1 - z0)
	for cx in [x0 + 0.02, x1 - 0.02]:
		for cz in [z0 + 0.02, z1 - 0.02]:
			b.box(g, "metal", Vector3(cx - 0.02, 0, cz - 0.02), Vector3(cx + 0.02, h, cz + 0.02), false)
	var gap := (h - 0.1) / levels
	for i in levels:
		var y := 0.08 + i * gap
		b.box(g, "steel", Vector3(x0, y, z0), Vector3(x1, y + 0.03, z1), false)
		var depth := (z1 - z0) if along_x else (x1 - x0)
		var length := (x1 - x0) if along_x else (z1 - z0)
		var cursor := 0.06
		while cursor < length - 0.2:
			var w := rng.randf_range(0.22, 0.42)
			if cursor + w > length - 0.04:
				break
			var hh := minf(rng.randf_range(0.14, 0.38), gap - 0.08)
			var d := depth * rng.randf_range(0.6, 0.85)
			var c := cursor + w * 0.5
			var pos := Vector3(x0 + c, y + 0.03, (z0 + z1) * 0.5) if along_x else Vector3((x0 + x1) * 0.5, y + 0.03, z0 + c)
			var sz := Vector3(w - 0.03, hh, d) if along_x else Vector3(d, hh, w - 0.03)
			if rng.randf() < 0.18:
				# tins of something
				for k in 2:
					var o := (k - 0.5) * (w * 0.45)
					var tp := pos + (Vector3(o, 0, 0) if along_x else Vector3(0, 0, o))
					b.prism(g, "paint_orange" if rng.randf() < 0.5 else "lettuce", tp, 0.06, minf(0.16, hh), 8)
			else:
				if g == "Props_Storeroom" and i % 2 == 0 and cursor < 0.4:
					stored_fungus.append([pos,stored_fungus.size()%6,0.0 if along_x else -90.0])
				else:
					b.obox(g, "cardboard", pos + Vector3(0, hh * 0.5, 0), sz, Basis.IDENTITY, false)
				if g == "Props_Storeroom" and i == levels-1 and cursor < 0.4:
					stored_fungus.append([pos+Vector3(0,hh,0),stored_fungus.size()%6,15.0])
			cursor += w + rng.randf_range(0.02, 0.08)
	b.col(g, Vector3(x0, 0, z0), Vector3(x1, h, z1))

# --------------------------------------------------------------- shell ----
func shell() -> void:
	var g := "Decor_Shell"
	var W: float = b.HALF_W
	var D: float = b.HALF_D
	# Concrete plinth band round the base (cut at the delivery door).
	b.wall(g, "plinth", "x", -(D + 0.02), 0.04, -(W + 0.04), W + 0.04, b.side_openings("north"), 0.0, 0.55, false)
	b.wall(g, "plinth", "x", D + 0.02, 0.04, -(W + 0.04), W + 0.04, b.side_openings("south"), 0.0, 0.55, false)
	b.wall(g, "plinth", "z", W + 0.02, 0.04, -D, D, b.side_openings("east"), 0.0, 0.55, false)
	b.wall(g, "plinth", "z", -(W + 0.02), 0.04, -D, D, b.side_openings("west"), 0.0, 0.55, false)
	# Orange fascia band, parapet and concrete coping round the roof edge.
	var fo := 0.3 # roof overhang
	for s in [-1.0, 1.0]:
		b.box(g, "fascia", Vector3(-W - fo - 0.06, 2.88, s * (D + fo)), Vector3(W + fo + 0.06, 3.5, s * (D + fo + 0.06)), false)
		b.box(g, "fascia", Vector3(s * (W + fo), 2.88, -D - fo), Vector3(s * (W + fo + 0.06), 3.5, D + fo), false)
		b.box(g, "roof", Vector3(-W - fo, 3.25, s * (D + fo)), Vector3(W + fo, 3.5, s * (D + 0.12)), false)
		b.box(g, "roof", Vector3(s * (W + fo), 3.25, -D - 0.12), Vector3(s * (W + 0.12), 3.5, D + 0.12), false)
		b.box(g, "concrete", Vector3(-W - fo - 0.08, 3.5, s * (D + fo + 0.08)), Vector3(W + fo + 0.08, 3.56, s * (D + 0.1)), false)
		b.box(g, "concrete", Vector3(s * (W + fo + 0.08), 3.5, -D - 0.1), Vector3(s * (W + 0.1), 3.56, D + 0.1), false)
	# Downpipes.
	for p in [Vector3(-5.5, 0, D + 0.1), Vector3(5.5, 0, D + 0.1), Vector3(W + 0.1, 0, -4.8)]:
		b.prism(g, "metal", p, 0.06, 3.0, 6)
		b.prism(g, "metal", p + Vector3(0, 2.86, 0), 0.09, 0.08, 6)

# ---------------------------------------------------------------- roof ----
func roof() -> void:
	var g := "Decor_Roof"
	var y := 3.25
	# Condenser units (fans on top), with ducts.
	b.box(g, "ac_unit", Vector3(2.0, y, 0.7), Vector3(3.2, y + 0.8, 1.6), false)
	b.box(g, "metal", Vector3(2.4, y, 1.6), Vector3(2.8, y + 0.25, 3.4), false)
	b.box(g, "ac_unit", Vector3(-2.3, y, 2.0), Vector3(-1.3, y + 0.7, 2.8), false)
	b.box(g, "metal", Vector3(-1.95, y, 0.8), Vector3(-1.65, y + 0.2, 2.0), false)
	b.box(g, "steel", Vector3(-1.4, y, -1.4), Vector3(-0.6, y + 0.45, -0.6), false)
	# Kitchen extract stack above the hood, plus a thin vent.
	b.prism(g, "metal", Vector3(2.55, y, -4.2), 0.16, 1.3, 8)
	b.prism(g, "metal", Vector3(2.55, y + 1.3, -4.2), 0.26, 0.08, 8)
	b.prism(g, "metal", Vector3(-4.6, y, -1.0), 0.07, 0.75, 6)
	b.box(g, "metal", Vector3(-4.0, y, 3.0), Vector3(-3.1, y + 0.15, 3.9), false) # roof hatch
	# Mascot on the roof, facing the road.
	var t := T(Vector3(0.6, y, -4.2), 180, 1.25)
	burger_sign(g, t, false)
	for sx in [-0.45, 0.45]:
		b.tbox(g, "metal", t, Vector3(sx, 0.25, -0.04), Vector3(0.07, 0.5, 0.07))
		rbox(g, "metal", t, Vector3(sx, 0.3, -0.3), Vector3(0.05, 0.6, 0.05), rotx(-40))
	b.light("SignLight_Roof", t * Vector3(0, 0.6, 1.1), P.AMBER_GLOW, 1.1, 3.5)

# ------------------------------------------------------------- outside ----
func exterior_lamps() -> void:
	var g := "Decor_Exterior"
	for w in b.WINDOWS:
		var wh: float = w["top"] - w["bottom"]
		wall_lamp(g, b.window_frame(w) * Transform3D(Basis.IDENTITY, Vector3(0, wh * 0.5 + 0.35, 0.0)), "WallLamp_" + w["id"])
	wall_lamp(g, Transform3D(Basis.IDENTITY, Vector3(b.DELIVERY_DOOR["at"], 2.62, b.HALF_D)), "WallLamp_Delivery")
	for x in [2.6, 5.0]:
		wall_lamp(g, Transform3D(roty(180), Vector3(x, 2.45, -b.HALF_D)), "WallLamp_Front_%d" % int(x * 10))

func frontage() -> void:
	var g := "Decor_Exterior"
	var D: float = b.HALF_D
	var hx: float = b.HATCH["at"]
	# Awning over the service hatch with a lamp strip under its lip.
	var ta := Transform3D(rotx(-12), Vector3(hx, 2.42, -D))
	b.tbox(g, "metal", ta, Vector3(0, 0.02, -0.36), Vector3(2.3, 0.08, 0.72))
	b.tbox(g, "paint_orange", ta, Vector3(0, 0.0, -0.73), Vector3(2.32, 0.14, 0.04))
	b.tbox(g, "lamp", ta, Vector3(0, -0.03, -0.6), Vector3(2.0, 0.02, 0.08))
	# Bollards guarding the hatch and the delivery door.
	for p in [Vector3(hx - 1.5, 0, -D - 0.45), Vector3(hx + 1.5, 0, -D - 0.45), Vector3(0.3, 0, D + 0.35), Vector3(5.7, 0, D + 0.35)]:
		b.prism(g, "paint_orange", p, 0.11, 0.95, 8, Basis.IDENTITY, true)
		b.prism(g, "paint_amber", p + Vector3(0, 0.74, 0), 0.115, 0.08, 8)
	# Pole sign on the road corner, angled at westbound traffic.
	var tp := T(Vector3(-8.6, 0, -5.0), 205)
	b.tbox(g, "concrete", tp, Vector3(0, 0.2, 0), Vector3(0.7, 0.4, 0.7), true)
	b.tprism(g, "metal", tp, Vector3(0, 0.4, -0.2), 0.1, 3.3, 8)
	var ts := Transform3D(tp.basis.scaled(Vector3.ONE * 0.9), tp * Vector3(0, 3.4, 0))
	burger_sign(g, ts, true)
	b.light("SignLight_Pole", tp * Vector3(0, 3.0, 1.4), P.AMBER_GLOW, 1.3, 4.5)

func yard() -> void:
	var g := "Decor_Exterior"
	# Crates stacked by the front-east corner.
	var t := T(Vector3(6.85, 0, -5.25), 8)
	crate(g, t, Vector3(0, 0, 0), 0.8)
	crate(g, t, Vector3(0.95, 0, 0.05), 0.7, 12)
	crate(g, t, Vector3(0.05, 0.8, 0), 0.6, 18)
	# ...and by the west lane.
	t = T(Vector3(-6.95, 0, 5.2), -6)
	crate(g, t, Vector3(0, 0, 0), 0.8)
	crate(g, t, Vector3(-0.9, 0, 0.1), 0.7, -10)
	carton(g, t, Vector3(0.0, 0.8, 0.0), Vector3(0.5, 0.35, 0.45), 20)
	# Pallet of stock waiting at the back.
	t = T(Vector3(6.7, 0, 6.6), 4)
	b.tbox(g, "wood", t, Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), true)
	crate(g, t, Vector3(-0.28, 0.14, -0.2), 0.55)
	crate(g, t, Vector3(0.3, 0.14, -0.2), 0.55, 5)
	carton(g, t, Vector3(-0.25, 0.14, 0.3), Vector3(0.5, 0.4, 0.4))
	carton(g, t, Vector3(0.3, 0.14, 0.3), Vector3(0.45, 0.3, 0.4), -8)
	carton(g, t, Vector3(0.0, 0.69, -0.2), Vector3(0.5, 0.3, 0.45), 15)
	b.prism(g, "metal", Vector3(7.9, 0, 5.8), 0.3, 0.9, 10, Basis.IDENTITY, true) # oil drum
	b.prism(g, "paint_orange", Vector3(7.9, 0.9, 5.8), 0.3, 0.02, 10)
	# X barricades across the far side of the road and by the lane mouths.
	cheval(g, T(Vector3(-9.0, 0, -10.9), 0))
	cheval(g, T(Vector3(7.0, 0, -11.0), 6))
	cheval(g, T(Vector3(20.0, 0, -6.6), 80))
	cheval(g, T(Vector3(-20.0, 0, 6.6), 96))

func palisade(g: String, c: Vector3, along_x: bool, h: float, width := 2.0) -> void:
	var s := Vector3(width, h, 0.03) if along_x else Vector3(0.03, h, width)
	b.obox(g, "palisade", c + Vector3(0, h * 0.5, 0), s, Basis.IDENTITY, false)

func fences() -> void:
	var g := "Decor_Fences"
	# Timber palisades behind each lane's barriers.
	for w in b.WINDOWS:
		var t: Transform3D = b.window_frame(w)
		var y0: float = -(w["bottom"] + w["top"]) * 0.5
		for side in [-1.0, 1.0]:
			for i in 5:
				var h := 1.75 + 0.15 * ((i * 7 + int(side + 1)) % 3) / 2.0
				b.tbox(g, "palisade", t, Vector3(side * (b.LANE_W * 0.5 + 0.65), y0 + h * 0.5, 1.3 + i * 2.0), Vector3(0.03, h, 2.0))
	# Site perimeter, open at the road, the lane mouths and the delivery track.
	var e := 19.0
	var k := 0
	for zc in range(-46, 116, 20):
		var z := zc / 10.0
		k += 1
		var hh := 1.7 + 0.1 * (k % 3)
		if z + 1.0 <= 0.4 or z - 1.0 >= 4.4:
			palisade(g, Vector3(-e, 0, z), false, hh)
		if z - 1.0 >= 0.4:
			palisade(g, Vector3(e, 0, z), false, hh)
	for xc in range(-18, 20, 2):
		k += 1
		if xc == 2 or xc == 4:
			continue
		palisade(g, Vector3(xc, 0, 12.0), true, 1.7 + 0.1 * (k % 3))

# ------------------------------------------------------------- interior ----
func interior_shell() -> void:
	var g := "Decor_Interior"
	var IX: float = b.IX
	var IZ: float = b.IZ
	# Exposed pipe runs round the top of the outer walls: main + thin orange gas line.
	pipe_x(g, "metal", -IX, IX, 2.8, -IZ + 0.09, 0.05)
	pipe_x(g, "metal", -IX, IX, 2.8, IZ - 0.09, 0.05)
	pipe_z(g, "metal", -IZ, IZ, 2.8, IX - 0.09, 0.05)
	pipe_z(g, "metal", -IZ, IZ, 2.8, -IX + 0.09, 0.05)
	pipe_x(g, "paint_orange", -IX, IX, 2.68, -IZ + 0.2, 0.03)
	pipe_x(g, "paint_orange", -IX, IX, 2.68, IZ - 0.2, 0.03)
	pipe_z(g, "paint_orange", -IZ, IZ, 2.68, IX - 0.2, 0.03)
	pipe_z(g, "paint_orange", -IZ, IZ, 2.68, -IX + 0.2, 0.03)
	for i in 9:
		var x := -5.25 + i * 1.3
		for z in [-IZ, IZ - 0.24]:
			b.box(g, "metal", Vector3(x - 0.03, 2.62, z), Vector3(x + 0.03, 2.86, z + 0.24), false)
	for i in 7:
		var z := -4.2 + i * 1.4
		for x in [-IX, IX - 0.24]:
			b.box(g, "metal", Vector3(x, 2.62, z - 0.03), Vector3(x + 0.24, 2.86, z + 0.03), false)
	# Steel posts, lintel and a caged lamp at each window (concept player view).
	var wall_t: float = b.EXT_OUTER + b.EXT_INNER
	for w in b.WINDOWS:
		var t: Transform3D = b.window_frame(w)
		var ww: float = w["w"]
		var cy: float = (w["bottom"] + w["top"]) * 0.5
		for sx in [-1.0, 1.0]:
			var x: float = sx * (ww * 0.5 + 0.16)
			b.tbox(g, "metal", t, Vector3(x, 1.275 - cy, -wall_t - 0.08), Vector3(0.12, 2.55, 0.16), true)
			b.tbox(g, "metal", t, Vector3(x, 1.275 - cy, -wall_t - 0.175), Vector3(0.22, 2.55, 0.03), true)
		b.tbox(g, "metal", t, Vector3(0, 0.72, -wall_t - 0.08), Vector3(ww + 0.56, 0.12, 0.16))
		wall_lamp(g, t * Transform3D(roty(180), Vector3(0, 0.95, -wall_t)), "WindowLamp_" + w["id"], 0.8, 3.5)

func mat(g: String, x0: float, z0: float, x1: float, z1: float) -> void:
	b.box(g, "rubber_mat", Vector3(x0, 0.0, z0), Vector3(x1, 0.008, z1), false)

func shop_floor() -> void:
	# Serving-room art is isolated from the gameplay station/collision layout.
	var serving = preload("res://tools/serving_room.gd").new()
	serving.build(self)

func kitchen() -> void:
	var kitchen_room = preload("res://tools/kitchen_room.gd").new()
	kitchen_room.build(self)

func shelf_rack_buns(g: String, x0: float, x1: float, z0: float, z1: float) -> void:
	for cx in [x0 + 0.02, x1 - 0.02]:
		for cz in [z0 + 0.02, z1 - 0.02]:
			b.box(g, "metal", Vector3(cx - 0.02, 0, cz - 0.02), Vector3(cx + 0.02, 1.75, cz + 0.02), false)
	for i in 4:
		var y := 0.25 + i * 0.42
		b.box(g, "metal", Vector3(x0, y, z0), Vector3(x1, y + 0.025, z1), false)
		for bx in 4:
			for bz in 2:
				b.prism(g, "bun", Vector3(x0 + 0.15 + bx * 0.23, y + 0.025, z0 + 0.14 + bz * 0.24), 0.08, 0.06, 6)
	b.col(g, Vector3(x0, 0, z0), Vector3(x1, 1.75, z1))

func back_office() -> void:
	var g := "Props_Office"
	var IX: float = b.IX
	var IZ: float = b.IZ
	# Desk with an old CRT, keyboard, papers and a mug.
	b.box(g, "wood", Vector3(-3.6, 0.72, IZ - 0.7), Vector3(-2.0, 0.77, IZ), false)
	for lx in [-3.55, -2.05]:
		for lz in [IZ - 0.65, IZ - 0.05]:
			b.box(g, "metal", Vector3(lx - 0.025, 0, lz - 0.025), Vector3(lx + 0.025, 0.72, lz + 0.025), false)
	b.col(g, Vector3(-3.6, 0, IZ - 0.7), Vector3(-2.0, 0.77, IZ))
	b.clip(g, Vector3(-IX, 0, IZ - 0.7), Vector3(-2.0, 2.4, IZ))
	b.box(g, "plastic", Vector3(-3.1, 0.77, IZ - 0.5), Vector3(-2.68, 1.13, IZ - 0.08), false)
	b.box(g, "screen", Vector3(-3.05, 0.82, IZ - 0.51), Vector3(-2.73, 1.08, IZ - 0.5), false)
	b.box(g, "plastic", Vector3(-3.12, 0.77, IZ - 0.68), Vector3(-2.7, 0.8, IZ - 0.55), false)
	rbox(g, "chalk", T(Vector3(-2.35, 0.775, IZ - 0.35)), Vector3.ZERO, Vector3(0.21, 0.01, 0.29), roty(12))
	rbox(g, "chalk", T(Vector3(-2.3, 0.785, IZ - 0.32)), Vector3.ZERO, Vector3(0.21, 0.01, 0.29), roty(-7))
	b.prism(g, "paint_orange", Vector3(-3.4, 0.77, IZ - 0.35), 0.04, 0.09, 8)
	# Chair turned to the desk.
	var tc := T(Vector3(-2.85, 0, IZ - 1.05), 8)
	b.tbox(g, "metal", tc, Vector3(0, 0.22, 0), Vector3(0.06, 0.44, 0.06))
	b.tbox(g, "cabinet", tc, Vector3(0, 0.47, 0), Vector3(0.48, 0.07, 0.46))
	b.tbox(g, "cabinet", tc, Vector3(0, 0.8, -0.23), Vector3(0.48, 0.55, 0.06))
	b.col(g, tc * Vector3(-0.26, 0, -0.27), tc * Vector3(0.26, 1.05, 0.25))
	# Pinboard above the desk with notes.
	b.box(g, "cardboard", Vector3(-3.4, 1.25, IZ - 0.03), Vector3(-2.2, 1.95, IZ), false)
	for n in [Vector2(-3.2, 1.75), Vector2(-2.9, 1.55), Vector2(-2.55, 1.8), Vector2(-2.45, 1.4), Vector2(-3.05, 1.35)]:
		b.box(g, "chalk", Vector3(n.x - 0.09, n.y - 0.11, IZ - 0.035), Vector3(n.x + 0.09, n.y + 0.11, IZ - 0.03), false)
		b.box(g, "gem", Vector3(n.x - 0.015, n.y + 0.07, IZ - 0.045), Vector3(n.x + 0.015, n.y + 0.1, IZ - 0.035), false)
	# Filing cabinet and floor safe.
	b.box(g, "steel", Vector3(-4.6, 0, IZ - 0.58), Vector3(-4.1, 1.3, IZ), true)
	b.box(g, "drawers", Vector3(-4.58, 0.03, IZ - 0.6), Vector3(-4.12, 1.27, IZ - 0.58), false)
	b.box(g, "metal", Vector3(-5.6, 0, IZ - 0.65), Vector3(-5.0, 0.85, IZ - 0.05), true)
	b.prism(g, "steel", Vector3(-5.3, 0.55, IZ - 0.65), 0.06, 0.03, 10, FACING_N)
	b.box(g, "steel", Vector3(-5.18, 0.3, IZ - 0.68), Vector3(-5.08, 0.42, IZ - 0.65), false)
	# Cleatimus's mushroom grow shelf, with an amber grow strip on each tier.
	var gx0 := -5.5
	var gx1 := -4.0
	var gz0 := 0.075
	var gz1 := 0.55
	shelf_frame(g, gx0, gx1, gz0, gz1, 1.7)
	for tier in 3:
		var ty := 0.1 + tier * 0.55
		b.box(g, "wood", Vector3(gx0, ty, gz0), Vector3(gx1, ty + 0.03, gz1), false)
		b.box(g, "soil", Vector3(gx0 + 0.05, ty + 0.03, gz0 + 0.05), Vector3(gx1 - 0.05, ty + 0.09, gz1 - 0.05), false)
		b.box(g, "lamp", Vector3(gx0 + 0.1, ty + 0.5, gz0 + 0.2), Vector3(gx1 - 0.1, ty + 0.51, gz0 + 0.26), false)
		for m in 7:
			var mx := gx0 + 0.15 + m * 0.2 + rng.randf_range(-0.03, 0.03)
			var mz := gz0 + 0.15 + (m % 2) * 0.18
			var mh := rng.randf_range(0.06, 0.13)
			b.prism(g, "chalk", Vector3(mx, ty + 0.09, mz), 0.022, mh, 6)
			b.prism(g, "mushroom_cap", Vector3(mx, ty + 0.09 + mh, mz), rng.randf_range(0.05, 0.075), 0.035, 6)
	b.col(g, Vector3(gx0, 0, gz0), Vector3(gx1, 1.7, gz1))
	# Camp cot along the east wall.
	b.box(g, "metal", Vector3(-0.95, 0, 3.25), Vector3(-0.15, 0.3, 4.7), true)
	b.box(g, "sandbag", Vector3(-0.9, 0.3, 3.3), Vector3(-0.2, 0.42, 4.65), false)
	b.box(g, "chalk", Vector3(-0.85, 0.42, 4.25), Vector3(-0.25, 0.52, 4.6), false)
	b.box(g, "lettuce", Vector3(-0.92, 0.42, 3.3), Vector3(-0.18, 0.45, 3.95), false) # folded blanket

func shelf_frame(g: String, x0: float, x1: float, z0: float, z1: float, h: float) -> void:
	for cx in [x0 + 0.02, x1 - 0.02]:
		for cz in [z0 + 0.02, z1 - 0.02]:
			b.box(g, "metal", Vector3(cx - 0.02, 0, cz - 0.02), Vector3(cx + 0.02, h, cz + 0.02), false)

func storeroom() -> void:
	var g := "Props_Storeroom"
	var IX: float = b.IX
	var IZ: float = b.IZ
	shelf_unit(g, IX - 0.52, IX, 0.45, 2.25, 2.0, 4)
	shelf_unit(g, IX - 0.52, IX, 2.55, 4.35, 2.0, 4)
	shelf_unit(g, 0.4, 2.1, 0.075, 0.6, 2.0, 4)
	shelf_unit(g, 3.9, 5.0, 0.075, 0.6, 2.0, 4)
	# Pallet of crates in the south-west corner.
	var t := T(Vector3(0.95, 0, 4.05), -3)
	b.tbox(g, "wood", t, Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.1), true)
	crate(g, t, Vector3(-0.28, 0.14, -0.25), 0.55)
	crate(g, t, Vector3(0.3, 0.14, -0.22), 0.55, 6)
	crate(g, t, Vector3(-0.25, 0.14, 0.3), 0.5, -4)
	crate(g, t, Vector3(0.0, 0.69, -0.2), 0.5, 14)
	b.clip(g, Vector3(0.075, 0, 3.4), Vector3(1.62, 2.4, IZ))
	# Sandbags stacked ready for barricading.
	for row in 3:
		var n := 3 - row
		for i in n:
			var sx := 4.3 + (row * 0.13) + i * 0.27
			var sz := 3.75 + (0.45 if (i + row) % 2 else 0.0)
			rbox(g, "sandbag", T(Vector3(sx + 0.12, 0.08 + row * 0.15, sz + 0.2)), Vector3.ZERO, Vector3(0.26, 0.15, 0.48), roty(5.0 * (i - 1)))
	b.col(g, Vector3(4.25, 0, 3.6), Vector3(5.1, 0.45, 4.65))
	b.clip(g, Vector3(4.2, 0, 3.55), Vector3(b.IX, 2.4, b.IZ)) # no climbing into the corner
	# Hand truck by the delivery door.
	var th := T(Vector3(4.95, 0, 2.4), -90)
	b.tbox(g, "metal", th, Vector3(0, 0.03, 0.12), Vector3(0.4, 0.03, 0.22))
	for sx in [-0.18, 0.18]:
		b.tbox(g, "metal", th, Vector3(sx, 0.62, 0), Vector3(0.04, 1.2, 0.04))
		b.tprism(g, "metal", th, Vector3(sx * 1.25, 0.1, -0.05), 0.1, 0.05, 8, Basis(Vector3.BACK, PI / 2))
	b.tbox(g, "metal", th, Vector3(0, 1.2, 0), Vector3(0.4, 0.04, 0.04))
	b.col(g, Vector3(4.72, 0, 2.15), Vector3(5.23, 1.25, 2.65))

# Shared static meshes; no additional lights, physics bodies or per-frame scripts.
func add_stored_fungus(parent: Node3D) -> void:
	stored_fungus.append([Vector3(0.96,1.19,3.85),4,-15.0])
	stored_fungus.append([Vector3(0.68,0.64,4.36),2,25.0])
	var stock:=Node3D.new();stock.name="Stored_Fungal_Cuts";parent.add_child(stock)
	for i in stored_fungus.size():
		var item: Array=stored_fungus[i]
		var instance:=MeshInstance3D.new();instance.name="FungalCut_%02d"%i
		instance.mesh=load("res://props/fungal_stock/cut_%d.res"%int(item[1]))
		instance.position=item[0];instance.rotation_degrees.y=item[2]
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stock.add_child(instance)

func add_empty_bottles(parent: Node3D) -> void:
	var script: Script=load("res://props/empty_bottle/empty_bottle.gd")
	for at: Vector3 in [Vector3(4.26,0.90,-0.25),Vector3(5.28,1.535,3.15),Vector3(1.38,0.69,3.80)]:
		var bottle:=StaticBody3D.new();bottle.set_script(script);bottle.name="EmptyBottle_%d"%parent.get_child_count();bottle.position=at;bottle.collision_layer=1;bottle.collision_mask=0
		var mesh:=MeshInstance3D.new();mesh.mesh=load("res://props/empty_bottle/bottle_mesh.res");bottle.add_child(mesh)
		var shape:=CollisionShape3D.new();var capsule:=CylinderShape3D.new();capsule.radius=0.045;capsule.height=0.27;shape.shape=capsule;shape.position.y=0.135;bottle.add_child(shape)
		parent.add_child(bottle)
