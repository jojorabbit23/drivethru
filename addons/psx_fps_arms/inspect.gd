extends CanvasLayer
## The inspect view: an item held up close in a lit world of its own over the dimmed game, turned by
## dragging the mouse or with the arrow keys (or WASD), zoomed with the wheel; E plays its `reveal`
## (a folder opening) and back again; Esc, Enter or a right click puts it away. Its title over it,
## its text under it. `lines` is the view's height in pixels, scaled up whole: 240 for the PS1's,
## 0 for the screen's own.
##     var inspect := preload("res://addons/psx_fps_arms/inspect.gd").new()
##     add_child(inspect)
##     inspect.open($Diary)  # a pickup: its scene, title, text and reveal; or any prop's scene
##     await inspect.closed

signal closed

@export var lines := 0
@export var dim := Color(0.0, 0.0, 0.0, 0.8)
@export var turn_speed := 2.0  ## radians a second on the keys

var item: Node3D  ## the copy shown
var showing := false
var yaw := 0.0
var pitch := 0.0
var zoom := 1.0
var revealed := false
var _view := SubViewport.new()
var _pivot := Node3D.new()
var _cam := Camera3D.new()
var _shade := ColorRect.new()
var _picture := TextureRect.new()
var _title := Label.new()
var _text := Label.new()
var _hint := Label.new()
var _reveal := ""
var _player: AnimationPlayer
var _dist := 1.0


func _init() -> void:
	layer = 50
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_view)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.62, 0.68)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_color = Color(1.0, 0.94, 0.84)
	key.light_energy = 1.1
	_view.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 140, 0)
	fill.light_color = Color(0.6, 0.66, 0.85)
	fill.light_energy = 0.35
	_view.add_child(fill)
	_cam.fov = 30.0
	_view.add_child(_cam)
	_view.add_child(_pivot)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)
	for l: Label in [_title, _text, _hint]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_shadow_color", Color.BLACK)
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		add_child(l)
	_title.add_theme_color_override("font_color", Color(0.96, 0.86, 0.6))
	_hint.modulate = Color(1, 1, 1, 0.55)
	visible = false


func _ready() -> void:
	_picture.texture = _view.get_texture()


## Holds `source` up: a pickup (its scene, `title`, `text` and `reveal`) or any prop's scene, a
## copy of it in the view. `title` and `text` stand in for its own.
func open(source: Node3D, title := "", text := "") -> void:
	close(false)
	var path := source.scene_file_path
	item = load(path).instantiate() if path else source.duplicate()
	if "glint" in item:
		item.glint = false
	item.visible = true
	item.process_mode = Node.PROCESS_MODE_INHERIT
	_pivot.add_child(item)
	_player = item.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_reveal = String(source.get("reveal")) if "reveal" in source else ""
	if not (_player and _player.has_animation(_reveal)):
		_reveal = ""
	revealed = false
	var meta: Dictionary = source.get_meta("prop", {})
	_title.text = title if title else String(source.get("title")) if "title" in source and source.title else meta.get("title", "")
	_text.text = text if text else String(source.get("text")) if "text" in source else ""
	_hint.text = "drag or arrows to turn, wheel to zoom" + (", E to open" if _reveal else "") + ", Esc to put it away"
	var box := _bounds(item)
	if _reveal:  # framed to hold it revealed too: a note unfolded, a box open
		_player.play(_reveal)
		_player.seek(_player.current_animation_length, true)
		box = box.merge(_bounds(item))
		_player.seek(0.0, true)
		_player.pause()
	item.position = -box.get_center()
	_dist = box.size.length() * 0.5 / sin(deg_to_rad(_cam.fov * 0.5)) * 1.3
	var flat := box.size.y < 0.35 * maxf(box.size.x, box.size.z)
	yaw = 0.35
	pitch = 0.95 if flat else 0.3  # what lies flat shown from above, as it was found
	zoom = 1.0
	showing = true
	visible = true
	_layout()
	_pose()


## Plays its reveal, or back again.
func toggle_reveal() -> void:
	if not _reveal:
		return
	revealed = not revealed
	if revealed:
		_player.play(_reveal)
	else:
		_player.play_backwards(_reveal)


## The reveal where it ends, at once: for a capture.
func reveal_now() -> void:
	if _reveal:
		revealed = true
		_player.play(_reveal)
		_player.seek(_player.current_animation_length, true)
		_player.pause()


func close(signal_it := true) -> void:
	if item:
		item.queue_free()
		item = null
	var was := showing
	showing = false
	visible = false
	if was and signal_it:
		closed.emit()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
	_shade.color = dim
	var h := int(lines) if lines > 0 else int(size.y)
	_view.size = Vector2i(maxi(1, int(h * size.x / size.y)), maxi(1, h))
	var px := maxf(14.0, size.y / 30.0)
	_title.add_theme_font_size_override("font_size", int(px * 1.5))
	_text.add_theme_font_size_override("font_size", int(px))
	_hint.add_theme_font_size_override("font_size", int(px * 0.75))
	_title.position = Vector2(0, size.y * 0.05)
	_title.size = Vector2(size.x, px * 2)
	_text.position = Vector2(size.x * 0.15, size.y * 0.74)
	_text.size = Vector2(size.x * 0.7, size.y * 0.18)
	_hint.position = Vector2(0, size.y - px * 1.6)
	_hint.size = Vector2(size.x, px)
	_picture.position = Vector2(0, -size.y * 0.08 if _text.text else 0.0)


func _pose() -> void:
	pitch = clampf(pitch, -1.5, 1.5)
	_pivot.basis = Basis(Vector3.RIGHT, pitch) * Basis(Vector3.UP, yaw)
	_cam.position = Vector3(0, 0, _dist / zoom)
	_cam.near = _dist * 0.02
	_cam.far = _dist * 10.0


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n and n != root:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var b := t * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _process(delta: float) -> void:
	if not showing:
		return
	var turn := Vector2(_key(KEY_RIGHT, KEY_D) - _key(KEY_LEFT, KEY_A), _key(KEY_DOWN, KEY_S) - _key(KEY_UP, KEY_W))
	if turn != Vector2.ZERO:
		yaw += turn.x * turn_speed * delta
		pitch += turn.y * turn_speed * delta
	_layout()
	_pose()


func _key(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0


func _input(event: InputEvent) -> void:
	if not showing:
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw += event.relative.x * 0.01
		pitch += event.relative.y * 0.01
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom = minf(2.5, zoom * 1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom = maxf(0.5, zoom / 1.1)
			MOUSE_BUTTON_RIGHT:
				close()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E, KEY_SPACE:
				toggle_reveal()
			KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_Q:
				close()
	get_viewport().set_input_as_handled()
