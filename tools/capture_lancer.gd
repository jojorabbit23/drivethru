# Renders the Lancer's clips as a contact sheet (needs a display):
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tools/capture_lancer.gd [-- clip view]
# Writes docs/previews/lancer_animations.png (5 frames per clip, 3/4 view),
# or with a clip name, scratch frames of just that clip to user://.
extends SceneTree

const OUT := "res://docs/previews/lancer_animations.png"
const CLIPS := ["idle", "stalk", "pry", "lunge", "climb", "flinch", "death"]
const CELL := Vector2i(300, 380)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var clips: Array = CLIPS if args.is_empty() else [args[0]]
	var view := "q" if args.size() < 2 else args[1]
	root.size = CELL
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#24384B")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#E9E1D1")
	e.ambient_light_energy = 0.55
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	root.add_child(sun)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#626D73")
	floor_m.material_override = fm
	root.add_child(floor_m)
	var model: Node3D = load("res://enemies/lancer/lancer_model.tscn").instantiate()
	root.add_child(model)
	var ap: AnimationPlayer = model.get_node("AnimationPlayer")
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	var at := Vector3(0, 0.9, -0.2)
	var dirs := {"q": Vector3(2.6, 1.2, -3.4), "side": Vector3(4.2, 0.6, -0.2), "front": Vector3(0, 0.6, -4.2), "back": Vector3(0, 0.8, 4.2)}
	cam.position = at + dirs[view]
	cam.look_at(at, Vector3.UP)
	cam.current = true
	var frames := 5
	var sheet := Image.create(CELL.x * frames, CELL.y * clips.size(), false, Image.FORMAT_RGBA8)
	for ci in clips.size():
		var clip: String = clips[ci]
		var anim := ap.get_animation(clip)
		for f in frames:
			var t := anim.length * f / float(frames - (0 if anim.loop_mode != Animation.LOOP_NONE else 1))
			ap.play(clip, 0.0)
			ap.seek(minf(t, anim.length), true)
			ap.pause()
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(f * CELL.x, ci * CELL.y))
	var path := OUT if args.is_empty() else "user://lancer_%s_%s.png" % [clips[0], view]
	sheet.save_png(ProjectSettings.globalize_path(path))
	print("saved ", ProjectSettings.globalize_path(path))
	quit()
