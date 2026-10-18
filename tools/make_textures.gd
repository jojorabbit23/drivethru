# Paints the greybox's pixel textures from the shared palette.
#
#   godot --headless --path . --script res://tools/make_textures.gd
#   godot --headless --path . --script res://tools/make_textures.gd -- --force
#
# Existing PNGs are left alone unless --force is given, so you can repaint
# any of them by hand (Aseprite etc.) without the next build overwriting it.
# After adding or changing PNGs, run `godot --headless --path . --import`.
#
# Scale: world-mapped textures cover 2 m per 64 px (32 px per metre).
extends SceneTree

const Palette = preload("res://core/palette.gd")
const P = Palette
const OUT := "res://textures/"

var rng := RandomNumberGenerator.new()
var force := false
var written := 0

func _initialize() -> void:
	force = "--force" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var makers := {
		"wall_teal_block": tex_wall_teal,
		"plinth_concrete": tex_plinth,
		"fascia_orange": tex_fascia,
		"roof_panels": tex_roof,
		"wall_tile": tex_wall_tile,
		"floor_tile": tex_floor_tile,
		"floor_concrete": tex_floor_concrete,
		"ceiling_tiles": tex_ceiling,
		"wood_board": tex_wood_board,
		"crate": tex_crate,
		"cardboard": tex_cardboard,
		"metal_dark": tex_metal_dark,
		"steel": tex_steel,
		"cabinet_teal": tex_cabinet,
		"drawers": tex_drawers,
		"ac_unit": tex_ac,
		"door_teal": tex_door,
		"asphalt": tex_asphalt,
		"ground": tex_ground,
		"concrete": tex_concrete,
		"sandbag": tex_sandbag,
		"rubber_mat": tex_mat,
		"palisade": tex_palisade,
	}
	for name in makers:
		var path: String = OUT + name + ".png"
		if FileAccess.file_exists(path) and not force:
			continue
		rng.seed = hash(name)
		var img: Image = makers[name].call()
		img.save_png(ProjectSettings.globalize_path(path))
		written += 1
	print("textures written: ", written, " (of ", makers.size(), ")")
	quit()

# ------------------------------------------------------------ helpers ----
func blank(c: Color, w := 64, h := 64) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img

func sh(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)

func put(img: Image, x: int, y: int, c: Color) -> void:
	img.set_pixel(posmod(x, img.get_width()), posmod(y, img.get_height()), c)

func get_px(img: Image, x: int, y: int) -> Color:
	return img.get_pixel(posmod(x, img.get_width()), posmod(y, img.get_height()))

func rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			put(img, x + i, y + j, c)

func shade_rect(img: Image, x: int, y: int, w: int, h: int, f: float) -> void:
	for j in h:
		for i in w:
			put(img, x + i, y + j, sh(get_px(img, x + i, y + j), f))

func noise(img: Image, amount: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, sh(c, 1.0 + rng.randf_range(-amount, amount)))

func speckle(img: Image, count: int, c: Color, max_size := 1) -> void:
	for i in count:
		var s := rng.randi_range(1, max_size)
		rect(img, rng.randi_range(0, 63), rng.randi_range(0, 63), s, s, c)

func blotches(img: Image, count: int, f: float, rmin := 3, rmax := 7, tint := Color(0, 0, 0, 0)) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for i in count:
		var cx := rng.randi_range(0, w - 1)
		var cy := rng.randi_range(0, h - 1)
		var r := rng.randi_range(rmin, rmax)
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var d := sqrt(x * x + y * y) / r
				if d <= 1.0 and rng.randf() > d * 0.6:
					var c := get_px(img, cx + x, cy + y)
					c = sh(c, f)
					if tint.a > 0.0:
						c = c.lerp(tint, tint.a)
					put(img, cx + x, cy + y, c)

func streaks(img: Image, count: int, f: float) -> void:
	for i in count:
		var x := rng.randi_range(0, img.get_width() - 1)
		var y0 := rng.randi_range(0, img.get_height() - 1)
		var length := rng.randi_range(8, 28)
		var wdt := rng.randi_range(1, 2)
		for y in length:
			var k := lerpf(f, 1.0, float(y) / length)
			for dx in wdt:
				put(img, x + dx, y0 + y, sh(get_px(img, x + dx, y0 + y), k))

func crack(img: Image, f: float, steps := 22) -> void:
	var x := rng.randi_range(0, 63)
	var y := rng.randi_range(0, 63)
	for i in steps:
		put(img, x, y, sh(get_px(img, x, y), f))
		x += rng.randi_range(-1, 1)
		y += 1 if rng.randf() < 0.7 else 0
		if rng.randf() < 0.3:
			x += 1

func bevel(img: Image, x: int, y: int, w: int, h: int, hi := 1.18, lo := 0.7) -> void:
	for i in w:
		put(img, x + i, y, sh(get_px(img, x + i, y), hi))
		put(img, x + i, y + h - 1, sh(get_px(img, x + i, y + h - 1), lo))
	for j in h:
		put(img, x, y + j, sh(get_px(img, x, y + j), hi))
		put(img, x + w - 1, y + j, sh(get_px(img, x + w - 1, y + j), lo))

func bricks(img: Image, bw: int, bh: int, mortar: Color, vary := 0.08) -> void:
	for row in img.get_height() / bh:
		var off := (row % 2) * (bw / 2)
		for col in range(-1, img.get_width() / bw + 1):
			var f := 1.0 + rng.randf_range(-vary, vary)
			shade_rect(img, col * bw + off, row * bh, bw, bh, f)
	for y in img.get_height():
		var row := y / bh
		var off := (row % 2) * (bw / 2)
		for x in img.get_width():
			if y % bh == bh - 1 or posmod(x + off, bw) == bw - 1:
				img.set_pixel(x, y, mortar)

func wood_colour() -> Color:
	return Palette.BURNT_ORANGE.lerp(Palette.WET_CHARCOAL, 0.45)

func wood_grain(img: Image, x0: int, y0: int, w: int, h: int, base: Color) -> void:
	for y in h:
		var row_f := 1.0 + 0.06 * sin(float(y) * 1.7 + rng.randf())
		for x in w:
			put(img, x0 + x, y0 + y, sh(base, row_f + rng.randf_range(-0.04, 0.04)))
	for i in int(w * h / 40.0):
		var gx := rng.randi_range(0, w - 1)
		var gy := rng.randi_range(0, h - 1)
		var run := rng.randi_range(3, 9)
		for k in run:
			if gx + k < w:
				put(img, x0 + gx + k, y0 + gy, sh(base, 0.78))

func nail(img: Image, x: int, y: int) -> void:
	put(img, x, y, Palette.WET_CHARCOAL)
	put(img, x + 1, y, sh(Palette.CONCRETE_GREY, 0.9))
	put(img, x, y + 1, sh(Palette.WET_CHARCOAL, 0.8))
	put(img, x + 1, y + 1, Palette.WET_CHARCOAL)

# ----------------------------------------------------------- textures ----
func tex_wall_teal() -> Image:
	var img := blank(P.OXIDISED_TEAL)
	bricks(img, 16, 8, sh(P.OXIDISED_TEAL, 0.55))
	noise(img, 0.05)
	streaks(img, 9, 0.75)
	blotches(img, 3, 0.85, 3, 6)
	speckle(img, 16, P.CONCRETE_GREY.lerp(P.WARM_CHALK, 0.25), 2) # chipped paint
	return img

func tex_plinth() -> Image:
	var base := sh(P.CONCRETE_GREY, 0.9)
	var img := blank(base)
	bricks(img, 32, 16, sh(base, 0.6), 0.1)
	noise(img, 0.07)
	blotches(img, 5, 0.8, 3, 8)
	speckle(img, 12, sh(base, 1.25))
	return img

func tex_fascia() -> Image:
	var img := blank(P.BURNT_ORANGE)
	for y in 64:
		for x in 64:
			if x % 16 == 0:
				img.set_pixel(x, y, sh(P.BURNT_ORANGE, 0.55))
			elif x % 16 == 1:
				img.set_pixel(x, y, sh(P.BURNT_ORANGE, 1.15))
	noise(img, 0.05)
	blotches(img, 6, 0.75, 2, 6, Color(P.WET_CHARCOAL, 0.25)) # rust
	streaks(img, 7, 0.7)
	speckle(img, 10, P.WARM_CHALK.lerp(P.BURNT_ORANGE, 0.5))
	for x in range(4, 64, 16):
		nail(img, x, 3)
		nail(img, x, 59)
	return img

func tex_roof() -> Image:
	var base := sh(P.CONCRETE_GREY, 0.7)
	var img := blank(base)
	for y in 64:
		for x in 64:
			if x % 32 == 0 or y % 32 == 0:
				img.set_pixel(x, y, sh(base, 0.6))
	noise(img, 0.08)
	blotches(img, 5, 0.8, 4, 9, Color(P.BLUE_SLATE, 0.3)) # puddles
	speckle(img, 30, sh(base, 1.2))
	return img

func tex_wall_tile() -> Image:
	var base := P.WARM_CHALK.lerp(P.CONCRETE_GREY, 0.45)
	var img := blank(base)
	for ty in 8:
		for tx in 8:
			var f := rng.randf_range(0.93, 1.04)
			if rng.randf() < 0.07:
				f = 0.84
			shade_rect(img, tx * 8, ty * 8, 8, 8, f)
			put(img, tx * 8 + 1, ty * 8 + 1, sh(get_px(img, tx * 8 + 1, ty * 8 + 1), 1.12))
	for y in 64:
		for x in 64:
			if x % 8 == 7 or y % 8 == 7:
				img.set_pixel(x, y, sh(base, 0.68))
	noise(img, 0.03)
	streaks(img, 8, 0.82)
	crack(img, 0.6, 10)
	return img

func tex_floor_tile() -> Image:
	var a := P.WARM_CHALK.lerp(P.CONCRETE_GREY, 0.6)
	var b := P.CONCRETE_GREY.lerp(P.BLUE_SLATE, 0.25)
	var img := blank(a)
	for ty in 4:
		for tx in 4:
			rect(img, tx * 16, ty * 16, 16, 16, a if (tx + ty) % 2 == 0 else b)
	for y in 64:
		for x in 64:
			if x % 16 == 15 or y % 16 == 15:
				img.set_pixel(x, y, sh(P.WET_CHARCOAL, 1.3))
	noise(img, 0.05)
	blotches(img, 8, 0.78, 3, 8) # grime
	speckle(img, 20, sh(P.WET_CHARCOAL, 1.2))
	return img

func tex_floor_concrete() -> Image:
	var base := sh(P.CONCRETE_GREY, 0.72)
	var img := blank(base)
	noise(img, 0.1)
	for i in 3:
		crack(img, 0.55, 26)
	blotches(img, 4, 0.7, 4, 9) # oil
	speckle(img, 30, sh(base, 1.25))
	return img

func tex_ceiling() -> Image:
	var base := sh(P.WARM_CHALK.lerp(P.CONCRETE_GREY, 0.5), 0.92)
	var img := blank(base)
	noise(img, 0.04)
	for i in 120:
		put(img, rng.randi_range(0, 63), rng.randi_range(0, 63), sh(base, 0.8)) # pitted tiles
	blotches(img, 3, 0.9, 4, 8, Color(P.BURNT_ORANGE.darkened(0.4), 0.3)) # water stains
	for y in 64:
		for x in 64:
			if x % 16 == 0 or y % 16 == 0:
				img.set_pixel(x, y, sh(P.CONCRETE_GREY, 0.75))
	return img

func tex_wood_board() -> Image:
	# Used in "local" UV mode: a board face lands on rows ~29-35.
	var img := blank(wood_colour())
	wood_grain(img, 0, 0, 64, 64, wood_colour())
	for y in 64:
		for x in [0, 1, 62, 63]:
			put(img, x, y, sh(get_px(img, x, y), 0.7)) # dark board ends
	for y in [30, 33]:
		nail(img, 4, y)
		nail(img, 58, y)
	blotches(img, 3, 0.8, 2, 4)
	return img

func tex_crate() -> Image:
	var w := wood_colour().lightened(0.08)
	var img := blank(w)
	for p in 4:
		wood_grain(img, 0, p * 16, 64, 16, sh(w, rng.randf_range(0.92, 1.06)))
		for x in 64:
			put(img, x, p * 16, sh(w, 0.6))
	var frame := sh(w, 0.78)
	for i in 64:
		for k in 5:
			put(img, i, k, frame); put(img, i, 63 - k, frame)
			put(img, k, i, frame); put(img, 63 - k, i, frame)
	for i in range(5, 59):
		for k in range(-2, 3):
			put(img, i + k, i, frame) # diagonal brace
	bevel(img, 0, 0, 64, 64, 1.15, 0.6)
	for c in [Vector2i(2, 2), Vector2i(60, 2), Vector2i(2, 60), Vector2i(60, 60)]:
		nail(img, c.x, c.y)
	return img

func tex_cardboard() -> Image:
	var base := P.AMBER_GLOW.lerp(P.BURNT_ORANGE, 0.5).darkened(0.32)
	var img := blank(base)
	noise(img, 0.04)
	rect(img, 0, 27, 64, 10, sh(base.lerp(P.WARM_CHALK, 0.35), 1.0)) # tape
	blotches(img, 3, 0.85, 3, 6)
	for i in 3: # "this way up" arrows
		var ax := 8 + i * 6
		rect(img, ax, 46, 1, 8, P.WET_CHARCOAL)
		put(img, ax - 1, 47, P.WET_CHARCOAL); put(img, ax + 1, 47, P.WET_CHARCOAL)
	bevel(img, 0, 0, 64, 64, 1.1, 0.72)
	return img

func tex_metal_dark() -> Image:
	var base := P.WET_CHARCOAL.lightened(0.1)
	var img := blank(base)
	noise(img, 0.06)
	for i in 18:
		var x := rng.randi_range(0, 63)
		var y := rng.randi_range(0, 63)
		for k in rng.randi_range(2, 7):
			put(img, x + k, y, sh(P.CONCRETE_GREY, 0.9))
	blotches(img, 3, 0.85, 3, 6, Color(P.BURNT_ORANGE.darkened(0.3), 0.25))
	return img

func tex_steel() -> Image:
	var base := P.CONCRETE_GREY.lightened(0.18)
	var img := blank(base)
	for y in 64:
		var f := rng.randf_range(0.96, 1.04)
		for x in 64:
			img.set_pixel(x, y, sh(base, f + rng.randf_range(-0.02, 0.02)))
	for i in 10:
		var x := rng.randi_range(0, 63)
		var y := rng.randi_range(0, 63)
		for k in rng.randi_range(3, 10):
			put(img, x + k, y + k / 4, sh(base, 1.15))
	blotches(img, 2, 0.9, 2, 3)
	return img

func tex_cabinet() -> Image:
	var img := blank(P.OXIDISED_TEAL)
	noise(img, 0.04)
	rect(img, 0, 0, 64, 3, sh(P.OXIDISED_TEAL, 0.7))
	rect(img, 0, 56, 64, 8, P.WET_CHARCOAL)          # kick plate
	rect(img, 31, 3, 2, 53, sh(P.WET_CHARCOAL, 1.1))  # gap between doors
	bevel(img, 2, 5, 28, 49)
	bevel(img, 34, 5, 28, 49)
	bevel(img, 6, 10, 20, 39, 0.8, 1.15) # recessed panels
	bevel(img, 38, 10, 20, 39, 0.8, 1.15)
	rect(img, 27, 24, 2, 10, P.BURNT_ORANGE)
	rect(img, 35, 24, 2, 10, P.BURNT_ORANGE)
	streaks(img, 5, 0.8)
	speckle(img, 8, P.CONCRETE_GREY)
	return img

func tex_drawers() -> Image:
	var base := sh(P.CONCRETE_GREY, 1.05)
	var img := blank(base)
	noise(img, 0.04)
	for d in 3:
		var y := 2 + d * 21
		bevel(img, 2, y, 60, 19)
		rect(img, 22, y + 7, 20, 3, P.WET_CHARCOAL)
		rect(img, 26, y + 2, 12, 4, sh(P.WARM_CHALK, 0.95))
	blotches(img, 3, 0.85, 2, 5)
	return img

func tex_ac() -> Image:
	var base := sh(P.CONCRETE_GREY, 1.1)
	var img := blank(base)
	noise(img, 0.04)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 32, y - 32).length()
			if d < 25:
				img.set_pixel(x, y, sh(P.WET_CHARCOAL, 1.2) if int(d) % 3 == 0 else sh(P.WET_CHARCOAL, 0.8))
	rect(img, 30, 7, 4, 50, sh(P.CONCRETE_GREY, 0.8))
	rect(img, 7, 30, 50, 4, sh(P.CONCRETE_GREY, 0.8))
	rect(img, 28, 28, 8, 8, sh(P.CONCRETE_GREY, 0.9))
	bevel(img, 0, 0, 64, 64)
	streaks(img, 5, 0.8)
	return img

func tex_door() -> Image:
	var img := blank(P.OXIDISED_TEAL, 32, 64)
	noise(img, 0.04)
	bevel(img, 0, 0, 32, 64)
	bevel(img, 3, 3, 26, 58, 1.12, 0.75)
	rect(img, 9, 8, 14, 12, sh(P.BLUE_SLATE, 0.9)) # wired glass
	for i in 14:
		put(img, 9 + i, 8 + (i * 12) / 14, sh(P.CONCRETE_GREY, 0.8))
	rect(img, 3, 50, 26, 11, sh(P.CONCRETE_GREY, 0.9)) # kick plate
	rect(img, 24, 30, 4, 3, P.BURNT_ORANGE)            # handle
	streaks(img, 5, 0.78)
	return img

func tex_asphalt() -> Image:
	var img := blank(P.WET_CHARCOAL)
	noise(img, 0.12)
	speckle(img, 70, sh(P.CONCRETE_GREY, 0.75))
	crack(img, 0.6, 30)
	blotches(img, 3, 0.85, 4, 9)
	return img

func tex_ground() -> Image:
	var base := P.MIDNIGHT_TYNE.lerp(P.CONCRETE_GREY, 0.2)
	var img := blank(base)
	noise(img, 0.15)
	speckle(img, 90, sh(base, 1.4))
	speckle(img, 25, P.OXIDISED_TEAL.darkened(0.55), 2) # scrubby tufts
	blotches(img, 5, 0.8, 4, 9)
	return img

func tex_concrete() -> Image:
	var img := blank(P.CONCRETE_GREY)
	noise(img, 0.06)
	for y in range(0, 64, 11):
		for x in 64:
			put(img, x, y, sh(get_px(img, x, y), 0.9)) # pour lines
	speckle(img, 14, sh(P.CONCRETE_GREY, 0.7), 2)
	streaks(img, 6, 0.8)
	return img

func tex_sandbag() -> Image:
	var base := P.WARM_CHALK.lerp(P.BURNT_ORANGE, 0.3).darkened(0.4)
	var img := blank(base)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, sh(base, 0.93 if (x + y) % 2 == 0 else 1.03))
	noise(img, 0.05)
	for x in range(0, 64, 3):
		put(img, x, 6, sh(base, 0.7)); put(img, x, 57, sh(base, 0.7)) # stitching
	bevel(img, 0, 0, 64, 64, 1.08, 0.68)
	blotches(img, 4, 0.82, 3, 7)
	return img

func tex_mat() -> Image:
	var img := blank(sh(P.WET_CHARCOAL, 0.85))
	for y in 64:
		for x in 64:
			if x % 4 < 2 and y % 4 < 2:
				img.set_pixel(x, y, P.MIDNIGHT_TYNE)
	noise(img, 0.05)
	return img

func tex_palisade() -> Image:
	# Alpha-cut timber palisade: 8 pickets with pointed tops and two rails.
	var img := blank(Color(0, 0, 0, 0))
	var w := wood_colour()
	for p in 8:
		var x0 := p * 8
		var top := rng.randi_range(2, 12)
		var tone := sh(w, rng.randf_range(0.85, 1.1))
		for y in range(top, 64):
			var inset := maxi(0, 3 - (y - top)) # point
			for x in range(x0 + inset, x0 + 6 - inset):
				img.set_pixel(x, y, sh(tone, 1.0 + rng.randf_range(-0.06, 0.06)))
		for y in range(top + 3, 64):
			img.set_pixel(x0, y, sh(tone, 0.75))
	for ry in [20, 50]:
		for y in range(ry, ry + 4):
			for x in 64:
				img.set_pixel(x, y, sh(w, 0.8 if y == ry + 3 else 0.95))
		for x in range(3, 64, 8):
			nail(img, x, ry + 1)
	return img
