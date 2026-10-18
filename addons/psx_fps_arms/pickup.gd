extends Node3D
## A pickup: on an item prop's scene root, what a use of it gives, takes or opens. `kind`:
##   item     picked up: `amount` of `item` into the user's items (one entry each), and gone
##   save     a save point: each use takes one of what it `takes` (an ink ribbon), plays `clip` and
##            emits `saved`; with nothing to take, it emits `refused`
##   storage  an item box: a use opens it (`clip` forward), the next shuts it (back)
## Its `title` and `text` are what an inspect shows (see inspect.gd), `reveal` a clip it plays
## there (a folder opening). An item glints until it is picked up, unless `glint` is off.
##     $Key.picked.connect(func(item): print("got ", item))
##     $Key.use(items)  # items: the player's, an Array of item names

signal used(part: String)
signal picked(item: String)
signal saved
signal opened(open: bool)
signal refused(why: String)  ## the item it wants
signal changed
signal live_changed(live: bool)

@export_enum("item", "save", "storage") var kind := "item"
@export var item := ""
@export var amount := 1
@export var title := ""
@export_multiline var text := ""
@export var reveal := ""
@export var clip := ""
@export var takes := ""
@export var glint := true

var live := false  ## picked up, saved at, or open
var saves := 0
var _player: AnimationPlayer
var _spark: Sprite3D
var _time := 0.0
var _moving := ""
var _to := 0.0
var _at := {}


func _ready() -> void:
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if glint and kind == "item":
		_spark = _star()
		add_child(_spark)
		var box := AABB()
		var first := true
		for m: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			var b := _local(m) * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
		_spark.position = Vector3(box.get_center().x, box.end.y + 0.03, box.get_center().z)


## Uses it, carrying `items`: an item goes into them, a save takes from them. Whether it did anything.
func use(items: Array = [], part := "") -> bool:
	match kind:
		"item":
			for i in amount:
				items.append(item)
			live = true
			picked.emit(item)
			hide()
			process_mode = Node.PROCESS_MODE_DISABLED  # out of the physics as well
		"save":
			if takes and takes not in items:
				refused.emit(takes)
				return false
			if takes:
				items.erase(takes)
			saves += 1
			_play(clip, _len(clip), _pose.bind(clip, 0.0))
			live = true
			saved.emit()
		"storage":
			if _moving == clip and _has(clip):
				return false
			live = not live
			_play(clip, _len(clip) if live else 0.0)
			opened.emit(live)
	used.emit(part)
	live_changed.emit(live)
	changed.emit()
	return true


## Its clip where it is going, at once: for a capture.
func settle() -> void:
	if _moving:
		var c := _moving
		_moving = ""
		_pose(c, _to)
		if c == clip and kind == "save":
			_pose(c, 0.0)


## A pickup needs nothing: here so a level wires it as it does its machines.
func wire(_machines: Array) -> void:
	pass


func _process(delta: float) -> void:
	_time += delta
	if _spark:  # a glint every two seconds, a star that swells and fades
		var t := fmod(_time + position.x * 0.7, 2.0)
		var s := sin(clampf(t / 0.5, 0.0, 1.0) * PI)
		_spark.visible = glint and s > 0.02 and visible
		_spark.scale = Vector3.ONE * maxf(0.01, s)
		_spark.rotation.z = t * 1.5
	if _moving:
		var t: float = move_toward(_at.get(_moving, 0.0), _to, delta)
		_pose(_moving, t)
		if t == _to:
			var c := _moving
			_moving = ""
			if c == clip and kind == "save":
				_pose(c, 0.0)


func _play(c: String, to: float, _then = null) -> void:
	if _has(c):
		_moving = c
		_to = to


func _pose(c: String, t: float) -> void:
	if not _has(c):
		return
	_at[c] = t
	_player.play(c)
	_player.seek(t, true)
	_player.pause()


func _has(c: String) -> bool:
	return not c.is_empty() and _player != null and _player.has_animation(c)


func _len(c: String) -> float:
	return _player.get_animation(c).length if _has(c) else 0.0


## A part's transform in the root's space.
func _local(n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n and n != self:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t


## A four-pointed star, drawn here, that faces the camera: a sprite, so a PSX Look conversion of
## the meshes leaves it be.
func _star() -> Sprite3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(absf(x - 7.5), absf(y - 7.5))
			var v := clampf(1.0 - (d.x * d.y) / 6.0 - d.length() / 9.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 0.9, v))
	var star := Sprite3D.new()
	star.name = "Glint"
	star.texture = ImageTexture.create_from_image(img)
	star.pixel_size = 0.0075
	star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	star.shaded = false
	star.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return star
