# Drive-thru pressure at a glance, bottom left above the health line: the
# reputation bar with its tier and tip multiplier, the serve streak, and the
# car waiting in line during rush hour (its order, so it can be prepped early).
# Reads game/reputation.gd and main.hatch; presentation only.
extends CanvasLayer

const P = preload("res://core/palette.gd")
const Recipes = preload("res://game/recipes.gd")

var main: Node
var panel: VBoxContainer
var rep_label: Label
var bar: ProgressBar
var fill := StyleBoxFlat.new()
var queue_label: Label
var _scan := 0.0
var _flash := 0.0
var _last_value := -1.0

func _ready() -> void:
	main = get_parent()
	layer = 8
	var font: FontFile = preload("res://fonts/pixel/pixel_font.tres").duplicate()
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	panel = VBoxContainer.new()
	panel.name = "Reputation"
	panel.theme = Theme.new()
	panel.theme.default_font = font
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position += Vector2(16, -118)
	panel.add_theme_constant_override("separation", 3)
	add_child(panel)
	queue_label = _label(16, P.AMBER_GLOW)
	panel.add_child(queue_label)
	rep_label = _label(16, P.WARM_CHALK)
	panel.add_child(rep_label)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 8)
	bar.show_percentage = false
	bar.max_value = 100.0
	var back := StyleBoxFlat.new()
	back.bg_color = Color(P.MIDNIGHT_TYNE, 0.85)
	back.border_color = P.BLUE_SLATE
	back.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	panel.add_child(bar)

func _label(size: int, colour: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", P.MIDNIGHT_TYNE)
	l.add_theme_constant_override("outline_size", 5)
	return l

func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_scan -= delta
	if _scan > 0.0 and _flash <= 0.0:
		return
	_scan = 0.1
	refresh()

func refresh() -> void:
	var r: Node = get_tree().get_first_node_in_group("reputation")
	var player: Node = main.get("player")
	panel.visible = r != null and not (player and player.has_method("is_dead") and player.is_dead())
	if not panel.visible:
		return
	var v: float = r.value
	if _last_value >= 0.0 and absf(v - _last_value) >= 5.0:
		_flash = 0.8                   # a big drop or jump: blink the bar
	_last_value = v
	bar.value = v
	var tips := float(r.tip_scale())
	rep_label.text = "REP %s  ·  TIPS x%s%s" % [r.tier_name(), str(tips), ("  ·  STREAK %d" % r.streak) if r.streak >= 2 else ""]
	var colour: Color = P.ELECTRIC_TEAL if v >= 70.0 else (P.WARM_CHALK if v >= 40.0 else (P.AMBER_GLOW if v >= 20.0 else P.BURNT_ORANGE))
	fill.bg_color = colour if fmod(_flash, 0.2) < 0.12 else P.WARM_CHALK
	rep_label.add_theme_color_override("font_color", colour)
	var hatch: Node = main.get("hatch")
	var q: Node = hatch.get("queued") if hatch else null
	queue_label.visible = q != null and is_instance_valid(q)
	if queue_label.visible:
		queue_label.text = "NEXT IN LINE: %s" % String(q.ticket_text(" + "))
