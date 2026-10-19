# Renders the shotgun (needs a display):
#   xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tools/capture_shotgun.gd
# Writes docs/previews/shotgun_model.png (three views of the model with its hands).
extends SceneTree

var frames: Array[Image] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(800, 600)
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#24384B")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	w.add_child(sun)
	var gun: Node3D = (load("res://weapons/shotgun/shotgun_model.tscn") as PackedScene).instantiate()
	w.add_child(gun)
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.fov = 40
	for v in [[Vector3(1.1, 0.25, -0.2), Vector3(0, 0.02, -0.15)], [Vector3(-1.1, 0.25, -0.2), Vector3(0, 0.02, -0.15)], [Vector3(0.35, 0.3, 0.75), Vector3(0, 0.03, -0.25)], [Vector3(0.0, -0.9, -0.2), Vector3(0, 0.0, -0.2)]]:
		cam.position = v[0]
		cam.look_at(v[1], Vector3.UP if absf(v[0].y) < 0.8 else Vector3.FORWARD)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		frames.append(root.get_texture().get_image())
	var out := Image.create(1600, 1200, false, frames[0].get_format())
	for i in frames.size():
		out.blit_rect(frames[i], Rect2i(0, 0, 800, 600), Vector2i((i % 2) * 800, (i / 2) * 600))
	out.save_png(ProjectSettings.globalize_path("res://docs/previews/shotgun_model.png"))
	print("saved")
	quit()
