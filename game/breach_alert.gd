# Small, bounded off-screen warning. Observe attack entry, not board removal:
# players get warning before damage, including a ram or interrupted rip.
extends CanvasLayer
const P = preload("res://core/palette.gd")
var camera: Camera3D
var player: Node3D
var seen: Dictionary = {}
var cooldowns: Dictionary = {}
var active: Dictionary = {}
var clock: float = 0.0
var scan_timer: float = 0.0
var cue: AudioStreamPlayer
var pips: Control
var alerts_emitted: int = 0

func _ready() -> void:
	layer = 6
	player = get_parent().get_node("Player")
	camera = player.get_node("Head/Camera3D")
	pips = Control.new()
	pips.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pips)
	cue = AudioStreamPlayer.new()
	cue.bus = "Effects"
	cue.volume_db = -16.0
	var samples := PackedByteArray()
	var rate: int = 22050
	samples.resize(int(rate * 0.18) * 2)
	for i in samples.size() / 2:
		var t: float = float(i) / rate
		var v: float = sin(TAU * (620.0 * t - 500.0 * t * t)) * exp(-t * 24.0)
		samples.encode_s16(i * 2, int(v * 22000.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = samples
	cue.stream = sound
	add_child(cue)

func _process(delta: float) -> void:
	clock += delta
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = 0.1
		scan()
	for id: int in active.keys():
		var entry: Dictionary = active[id]
		var win: Node3D = instance_from_id(id) as Node3D
		if win == null or clock >= float(entry.until) or player.is_dead():
			entry.label.queue_free()
			active.erase(id)
			continue
		var label: Label = entry.label
		label.position = pip_position(win.global_position) - label.size * 0.5
		label.modulate.a = minf(1.0, (float(entry.until) - clock) * 2.0)

func offscreen(at: Vector3) -> bool:
	return not camera.is_position_in_frustum(at)

func pip_position(at: Vector3) -> Vector2:
	var local: Vector3 = camera.to_local(at)
	var direction := Vector2(local.x, -local.y)
	# Behind the camera: keep a stable left/right cue rather than projecting infinity.
	if local.z >= 0.0 or direction.length_squared() < 0.01:
		direction = Vector2(-1.0 if local.x < 0.0 else 1.0, 0.25)
	direction = direction.normalized()
	var size: Vector2 = get_viewport().get_visible_rect().size
	var radius: Vector2 = size * Vector2(0.40, 0.32)
	return size * 0.5 + direction * radius

func scan() -> void:
	if player.is_dead():
		return
	var current: Dictionary = {}
	for enemy: Node in get_tree().get_nodes_in_group("zombies"):
		var id: int = enemy.get_instance_id()
		var attacking: bool = int(enemy.state) == 1 # all five types share BREACH = 1
		current[id] = attacking
		if not attacking or bool(seen.get(id, false)):
			continue
		var win: Node3D = enemy.window
		if win and win.is_in_group("windows") and not win.is_breached() and offscreen(win.global_position):
			warn(win)
	seen = current # remove freed enemies: memory stays bounded by the live cap
	for id: int in cooldowns.keys():
		if clock >= float(cooldowns[id]):
			cooldowns.erase(id)

func warn(win: Node3D) -> void:
	var id: int = win.get_instance_id()
	if clock < float(cooldowns.get(id, -1.0)):
		return
	cooldowns[id] = clock + 6.0
	alerts_emitted += 1
	if active.has(id):
		active[id].until = clock + 3.0
	else:
		var label := Label.new()
		label.text = "!  WINDOW"
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", P.AMBER_GLOW)
		label.add_theme_color_override("font_outline_color", P.MIDNIGHT_TYNE)
		label.add_theme_constant_override("outline_size", 5)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(label)
		active[id] = {"label": label, "until": clock + 3.0}
	# One short cue even when several windows are attacked in the same scan.
	if not cue.playing:
		cue.play()
