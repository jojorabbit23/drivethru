# Builds the game's pixel font from fonts/pixel/glyphs.txt (the owner's lettering
# sheet, cleaned to a pixel grid by tools/slice_font_sheet.py):
#
#   godot --headless --path . --script res://tools/build_font.gd
#
# Writes res://fonts/pixel/pixel_font.tres (a bitmap FontFile) and
# res://fonts/pixel/ui_theme.tres (the project theme: that font everywhere,
# warm-chalk text by default). project.godot points gui/theme/custom at the theme.
#
# Glyph fill is white so a label's font colour tints it exactly; the outline is
# baked in Midnight Tyne, so text reads on any background without Godot's
# outline. Native size is NATIVE px (cap 14 + room for descenders); the font only
# scales by whole multiples, so use font sizes 18, 36, 54... for crisp pixels.
extends SceneTree

const Palette = preload("res://core/palette.gd")
const SRC := "res://fonts/pixel/glyphs.txt"
const FONT_OUT := "res://fonts/pixel/pixel_font.tres"
const THEME_OUT := "res://fonts/pixel/ui_theme.tres"
const NATIVE := 18
const ASCENT := 15
const DESCENT := 3
const GAP := 1        # clear pixels between letters

func _init() -> void:
	var glyphs := parse(FileAccess.get_file_as_string(SRC))
	# Pack into one atlas row-by-row.
	var atlas_w := 256
	var x := 1
	var y := 1
	var row_h := 0
	var place := {}
	for ch: String in glyphs:
		var rows: PackedStringArray = glyphs[ch]["rows"]
		var w := rows[0].length()
		var h := rows.size()
		if x + w + 1 > atlas_w:
			x = 1
			y += row_h + 1
			row_h = 0
		place[ch] = Vector2i(x, y)
		x += w + 1
		row_h = maxi(row_h, h)
	var atlas_h := 1
	while atlas_h < y + row_h + 1:
		atlas_h *= 2
	var img := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var outline := Palette.MIDNIGHT_TYNE
	for ch: String in glyphs:
		var rows: PackedStringArray = glyphs[ch]["rows"]
		var at: Vector2i = place[ch]
		for j in rows.size():
			for i in rows[j].length():
				var c := rows[j][i]
				if c == "#":
					img.set_pixel(at.x + i, at.y + j, outline)
				elif c == "o":
					img.set_pixel(at.x + i, at.y + j, Color.WHITE)

	var f := FontFile.new()
	f.fixed_size = NATIVE
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.generate_mipmaps = false
	f.multichannel_signed_distance_field = false
	f.allow_system_fallback = false
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var sz := Vector2i(NATIVE, 0)
	f.set_cache_ascent(0, NATIVE, ASCENT)
	f.set_cache_descent(0, NATIVE, DESCENT)
	f.set_texture_image(0, sz, 0, img)
	var count := 0
	for ch: String in glyphs:
		var rows: PackedStringArray = glyphs[ch]["rows"]
		var bottom: int = glyphs[ch]["bottom"]
		var w := rows[0].length()
		var h := rows.size()
		var at: Vector2i = place[ch]
		var codes := [ch.unicode_at(0)]
		if ch.to_lower() != ch:
			codes.append(ch.to_lower().unicode_at(0))   # lowercase reuses the capitals
		for code: int in codes:
			f.set_glyph_advance(0, NATIVE, code, Vector2(w + GAP, 0))
			f.set_glyph_offset(0, sz, code, Vector2(0, -(bottom + h)))
			f.set_glyph_size(0, sz, code, Vector2(w, h))
			f.set_glyph_uv_rect(0, sz, code, Rect2(at.x, at.y, w, h))
			f.set_glyph_texture_idx(0, sz, code, 0)
			count += 1
	var err := ResourceSaver.save(f, FONT_OUT)
	print("saved %s err=%d  %d glyphs (%d codepoints), atlas %dx%d" % [FONT_OUT, err, glyphs.size(), count, atlas_w, atlas_h])

	var theme := Theme.new()
	theme.default_font = load(FONT_OUT)
	theme.default_font_size = NATIVE
	theme.set_color("font_color", "Label", Palette.WARM_CHALK)
	err = ResourceSaver.save(theme, THEME_OUT)
	print("saved %s err=%d" % [THEME_OUT, err])
	quit()

# {char: {"bottom": int, "rows": PackedStringArray}} in file order
static func parse(text: String) -> Dictionary:
	var out := {}
	var cur := ""
	for line in text.split("\n"):
		if line.begins_with("glyph "):
			var p := line.split(" ")
			cur = " " if p[1] == "space" else p[1]
			out[cur] = {"bottom": int(p[2]), "rows": PackedStringArray()}
		elif cur != "" and line.strip_edges() != "":
			var rows: PackedStringArray = out[cur]["rows"]
			rows.append(line.strip_edges())
			out[cur]["rows"] = rows   # packed arrays are values: store it back
		elif line.strip_edges() == "":
			cur = ""
	return out
