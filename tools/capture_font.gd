# Renders the pixel font at its sizes, in 2D and on a Label3D (needs a display):
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tools/capture_font.gd
# Writes docs/previews/font.png
extends SceneTree

const Palette = preload("res://core/palette.gd")

func _init() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Palette.BLUE_SLATE
	bg.size = Vector2(1280, 330)
	vp.add_child(bg)
	var y := 10.0
	for s in [[18, Palette.WARM_CHALK], [36, Palette.AMBER_GLOW], [54, Palette.ELECTRIC_TEAL]]:
		var l := Label.new()
		l.text = "THE DRIVE THRU  $30  (2/4)  AUTO-COLLECT: ON" if s[0] != 54 else "WAVE 3 · 100%"
		l.add_theme_font_size_override("font_size", s[0])
		l.add_theme_color_override("font_color", s[1])
		l.position = Vector2(16, y)
		vp.add_child(l)
		y += s[0] * 1.5 + 8
	var plain := Label.new()   # no overrides: theme default colour and size
	plain.text = "abcdefghijklmnopqrstuvwxyz 0123456789 .,!?:;-+/()$%·[]|'\"=_"
	plain.position = Vector2(16, y)
	vp.add_child(plain)
	# 3D sign
	var w := Node3D.new()
	vp.add_child(w)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 3)
	w.add_child(cam)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Palette.MIDNIGHT_TYNE
	w.add_child(env)
	var l3 := Label3D.new()
	l3.text = "E  GRILL  ·  2 FREE SLOTS"
	l3.font_size = 36
	l3.pixel_size = 0.004
	l3.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l3.modulate = Palette.AMBER_GLOW
	l3.position = Vector3(0, -0.75, 0)
	w.add_child(l3)
	for i in 8:
		await process_frame
	var f: Font = plain.get_theme_font("font")
	print("theme font: ", f.resource_path, "  label3d font: ", (l3.get("font") as Font))
	for fs in [13, 16, 18, 22, 27, 36, 40, 54]:
		print("size %d -> height %.0f, 'HELLO' width %.0f" % [fs, f.get_height(fs), f.get_string_size("HELLO", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x])
	var img := vp.get_texture().get_image()
	img.save_png("res://docs/previews/font.png")
	print("saved")
	quit()
