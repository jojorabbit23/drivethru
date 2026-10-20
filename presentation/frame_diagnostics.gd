extends CanvasLayer
const Palette = preload("res://core/palette.gd")
# Opt-in diagnostics for the actual interactive launcher, including paused scenes.
# Uses wall-clock frame intervals, never an average-FPS counter alone.
var samples: Array[float] = []
var previous: int = 0
var elapsed: float = 0.0
var focused: bool = true
var overlay: Label
var output: FileAccess

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_cmdline_user_args().has("--frame-diagnostics"):
		set_process(false)
		set_process_input(false)
		return
	layer = 100
	output = FileAccess.open("user://frame_diagnostics.jsonl", FileAccess.WRITE)
	if output:
		output.store_line(JSON.stringify({"event":"start", "date":Time.get_datetime_string_from_system(), "refresh_hz":DisplayServer.screen_get_refresh_rate(), "renderer":RenderingServer.get_video_adapter_name()}))
		output.flush()
	else:
		push_warning("Frame diagnostics log could not be opened: %s" % error_string(FileAccess.get_open_error()))
	print("Frame diagnostics: ", ProjectSettings.globalize_path("user://frame_diagnostics.jsonl"), " (F3 overlay)")
	overlay = Label.new()
	overlay.position = Vector2(12, 80)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_font_size_override("font_size", 18)
	overlay.add_theme_color_override("font_color", Palette.WARM_CHALK)
	overlay.add_theme_color_override("font_shadow_color", Palette.MIDNIGHT_TYNE)
	overlay.add_theme_constant_override("shadow_offset_x", 2)
	overlay.add_theme_constant_override("shadow_offset_y", 2)
	overlay.text = "Measuring frame timing... (F3 hides)"
	add_child(overlay)
	previous = Time.get_ticks_usec()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		overlay.visible = not overlay.visible
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN: focused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT: focused = false

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - previous) / 1000.0
	previous = now
	samples.append(ms)
	elapsed += ms
	if elapsed < 5000.0: return
	samples.sort()
	var scene: Node = get_tree().current_scene
	var report: Dictionary = {
		"event":"frames", "seconds":Time.get_ticks_msec()/1000.0,
		"scene":scene.scene_file_path if scene else "loading",
		"fps":samples.size()*1000.0/elapsed,
		"p95_ms":samples[mini(samples.size()-1,int(samples.size()*0.95))],
		"worst_ms":samples[-1], "cap":Engine.max_fps, "focused":focused,
		"paused":get_tree().paused, "vsync":DisplayServer.window_get_vsync_mode(),
		"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
		"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	}
	if output:
		output.store_line(JSON.stringify(report))
		output.flush()
	overlay.text = "%.0f FPS | p95 %.1f ms | worst %.1f ms\nCap %s | Focus %s | VSync %s | F3 hide" % [report.fps, report.p95_ms, report.worst_ms, str(Engine.max_fps), str(focused), str(report.vsync)]
	samples.clear()
	elapsed = 0.0
