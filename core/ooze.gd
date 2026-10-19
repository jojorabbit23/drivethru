# Orange fungal ooze: sprays from bullet hits and lands where it actually
# flies. Each droplet is simulated (gravity + raycast) and leaves a splat on
# the surface it hits, shaped by how it hit:
#   flat on the floor        round splat
#   glancing / skimming      stretched streak along its direction of travel
#   walls, boards, frames    splat plus a drip that runs down the surface
# Splats are small alpha-cut quads (they work in every renderer, unlike
# Decal nodes), share a handful of pixel-art textures painted from the
# palette at startup, and fade out after SPLAT_LIFETIME.
#
#   var fx = Ooze.get_fx(self)   # finds or creates the scene's OozeFX node
#   fx.spray(hit_pos, bullet_dir, surface_normal, strength, is_head)
#   fx.pool(corpse_floor_pos)
extends Node3D

const P = preload("res://core/palette.gd")

const MAX_SPLATS := 180
const MAX_DROPLETS := 140
const SPLAT_LIFETIME := 60.0
const FADE_TIME := 4.0
const LAND_MASK := 1 | 2          # world + barricade boards (not bodies)
const GRAVITY := 9.8
const DROPLET_LIFETIME := 2.5

var droplets: Array = []          # {node, vel, life, size}
var splats: Array = []            # {node, born}
var splat_mats: Array[StandardMaterial3D] = []
var drip_mat: StandardMaterial3D
var mist_mat: StandardMaterial3D
var drop_mesh: SphereMesh
var quad: QuadMesh
var rng := RandomNumberGenerator.new()
var stats := {"sprays": 0, "droplets": 0, "splats": 0, "drips": 0}

static func get_fx(from: Node) -> Node3D:
	var scene: Node = from.get_tree().current_scene if from.get_tree().current_scene else from.get_tree().root
	var fx := scene.get_node_or_null("OozeFX") as Node3D
	if fx == null:
		fx = (load("res://core/ooze.gd") as GDScript).new()
		fx.name = "OozeFX"
		scene.add_child(fx)
	return fx

func _ready() -> void:
	rng.randomize()
	for i in 4:
		splat_mats.append(_mat(_paint_splat(i)))
	drip_mat = _mat(_paint_drip())
	mist_mat = _mat(_paint_burst())
	mist_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mesh = SphereMesh.new()
	drop_mesh.radius = 0.5
	drop_mesh.height = 1.0
	drop_mesh.radial_segments = 5
	drop_mesh.rings = 3
	var dm := StandardMaterial3D.new()
	dm.albedo_color = P.BURNT_ORANGE.lerp(P.AMBER_GLOW, 0.35)
	dm.roughness = 0.25
	dm.emission_enabled = true          # a faint wet glow so it reads at night
	dm.emission = P.BURNT_ORANGE
	dm.emission_energy_multiplier = 0.35
	drop_mesh.material = dm
	quad = QuadMesh.new()
	quad.size = Vector2.ONE

# ---------------------------------------------------------------- API ----
# hit_pos: where the bullet struck; dir: bullet direction (normalised);
# normal: surface normal at the hit (toward the shooter); strength ~1 body,
# ~2 headshot.
func spray(hit_pos: Vector3, dir: Vector3, normal: Vector3, strength := 1.0, is_head := false) -> void:
	stats["sprays"] += 1
	dir = dir.normalized()
	if normal.length_squared() < 0.01:
		normal = -dir
	_mist(hit_pos, 0.35 * strength)
	# blow-through: the big spray carries on along the bullet's path
	var n_exit := int(rng.randi_range(9, 13) * strength)
	for i in n_exit:
		var v := _cone(dir, 0.42) * rng.randf_range(3.0, 6.0) + Vector3.UP * rng.randf_range(0.3, 1.6)
		_droplet(hit_pos + dir * 0.18, v, rng.randf_range(0.025, 0.055) * (1.2 if is_head else 1.0))
	# splash-back toward the shooter, smaller and slower
	var n_back := int(rng.randi_range(4, 6) * strength)
	for i in n_back:
		var v := _cone((normal * 0.8 + Vector3.UP * 0.4).normalized(), 0.7) * rng.randf_range(1.2, 2.8)
		_droplet(hit_pos, v, rng.randf_range(0.02, 0.04))
	# dribble straight down from the wound
	for i in rng.randi_range(2, 4):
		_droplet(hit_pos + Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05)),
			Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.4), rng.randf_range(-0.3, 0.3)), rng.randf_range(0.03, 0.05))
	if is_head:
		# headshot: a fountain out of the top of the cap
		for i in 10:
			var v := _cone(Vector3.UP, 0.6) * rng.randf_range(2.5, 4.5) + dir * 1.5
			_droplet(hit_pos + Vector3.UP * 0.1, v, rng.randf_range(0.03, 0.06))

# A spreading puddle under a corpse.
func pool(at: Vector3, size := 1.0) -> void:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 2.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var s := _splat(hit["position"], hit["normal"], Vector3.ZERO, 0.05, splat_mats[rng.randi() % splat_mats.size()])
	if s == null:
		return
	# spread as far as the floor allows (not under a counter or off a ledge)
	var target: float = size * rng.randf_range(0.8, 1.05)
	var probe_n: Vector3 = hit["normal"]
	var fit := _fit(hit["position"], probe_n, s.global_basis.x.normalized(), s.global_basis.y.normalized(), target * 0.5, target * 0.5)
	if fit <= 0.0:
		target = 0.25
	else:
		target *= fit
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3(target, target, 1.0), 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func splat_count() -> int:
	return splats.size()

func clear() -> void:
	for d in droplets:
		d["node"].queue_free()
	for s in splats:
		if is_instance_valid(s["node"]):
			s["node"].queue_free()
	droplets.clear()
	splats.clear()

# ----------------------------------------------------------- simulate ----
func _physics_process(delta: float) -> void:
	if droplets.is_empty() and splats.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var keep := []
	for d in droplets:
		var node: MeshInstance3D = d["node"]
		var from: Vector3 = node.global_position
		d["vel"] = (d["vel"] as Vector3) + Vector3.DOWN * GRAVITY * delta
		var to: Vector3 = from + d["vel"] * delta
		d["life"] -= delta
		var q := PhysicsRayQueryParameters3D.create(from, to, LAND_MASK)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			_land(hit["position"], hit["normal"], d["vel"], d["size"])
			node.queue_free()
			continue
		if d["life"] <= 0.0 or to.y < -2.0:
			node.queue_free()
			continue
		node.global_position = to
		# stretch along travel for a liquid look
		var v: Vector3 = d["vel"]
		if v.length() > 0.5:
			node.look_at(to + v, Vector3.UP if absf(v.normalized().y) < 0.95 else Vector3.RIGHT)
			node.scale = Vector3(d["size"], d["size"], d["size"] * clampf(1.0 + v.length() * 0.35, 1.0, 3.0))
		keep.append(d)
	droplets = keep
	# fade old splats
	var now := Time.get_ticks_msec() / 1000.0
	var alive := []
	for s in splats:
		var node: Node3D = s["node"]
		if not is_instance_valid(node):
			continue
		var age: float = now - s["born"]
		if age > SPLAT_LIFETIME + FADE_TIME:
			node.queue_free()
			continue
		if age > SPLAT_LIFETIME:
			if not s.has("fade_from"):
				s["fade_from"] = node.scale
			var k := 1.0 - (age - SPLAT_LIFETIME) / FADE_TIME
			var f: Vector3 = s["fade_from"]
			node.scale = Vector3(f.x * k, f.y * k, f.z)
		alive.append(s)
	splats = alive

func _droplet(pos: Vector3, vel: Vector3, size: float) -> void:
	if droplets.size() >= MAX_DROPLETS:
		return
	var m := MeshInstance3D.new()
	m.mesh = drop_mesh
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos
	m.scale = Vector3.ONE * size
	droplets.append({"node": m, "vel": vel, "life": DROPLET_LIFETIME, "size": size})
	stats["droplets"] += 1

func _land(pos: Vector3, normal: Vector3, vel: Vector3, size: float) -> void:
	var speed := vel.length()
	# splat size grows with droplet size and impact speed
	var s := clampf(size * rng.randf_range(6.5, 9.5) * (0.8 + speed * 0.08), 0.12, 0.6)
	_splat(pos, normal, vel, s, splat_mats[rng.randi() % splat_mats.size()])
	# walls and other steep surfaces: the ooze runs
	if absf(normal.y) < 0.6 and rng.randf() < 0.75:
		_drip(pos, normal, s)

# Places a quad on a surface. Its local Z = surface normal; it's stretched
# along the droplet's travel across the surface (glancing hits streak).
func _splat(pos: Vector3, normal: Vector3, vel: Vector3, size: float, mat: Material) -> MeshInstance3D:
	normal = normal.normalized()
	var along := vel - normal * vel.dot(normal)        # travel projected onto the surface
	var into := -vel.dot(normal)                       # how square-on it hit
	var x_axis: Vector3
	var stretch := 1.0
	if along.length() > 0.3:
		x_axis = along.normalized()
		stretch = clampf(1.0 + along.length() / maxf(into, 0.5) * 0.35, 1.0, 2.6)
	else:
		x_axis = normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
		x_axis = x_axis.rotated(normal, rng.randf() * TAU)
	var y_axis := normal.cross(x_axis).normalized()
	# Fit the splat to the surface it hit: probe its corners against the real
	# geometry and shrink it until it no longer overhangs an edge (a 20 cm
	# board, a door frame, the lip of a counter).
	var fit := _fit(pos, normal, x_axis, y_axis, size * stretch * 0.5, size / sqrt(stretch) * 0.5)
	if fit <= 0.0:
		return null
	size *= fit
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	# stack later splats a hair above earlier ones to avoid z-fighting
	var lift := 0.004 + 0.0006 * float(splats.size() % 8)
	m.global_transform = Transform3D(Basis(x_axis, y_axis, normal), pos + normal * lift)
	m.scale = Vector3(size * stretch, size / sqrt(stretch), 1.0)
	if splats.size() >= MAX_SPLATS:
		var oldest: Dictionary = splats.pop_front()
		if is_instance_valid(oldest["node"]):
			oldest["node"].queue_free()
	splats.append({"node": m, "born": Time.get_ticks_msec() / 1000.0})
	stats["splats"] += 1
	return m

# A drip that slowly runs down the surface from a splat.
func _drip(pos: Vector3, normal: Vector3, size: float) -> void:
	var down := Vector3.DOWN - normal * normal.dot(Vector3.DOWN)
	if down.length() < 0.2:
		return
	down = down.normalized()
	var y_axis := -down
	var x_axis := y_axis.cross(normal).normalized()
	# run only as far as the surface goes (boards are 20 cm tall)
	var room := _surface_below(pos, normal, down, 1.0)
	if room < 0.06:
		return
	var pivot := MeshInstance3D.new()
	pivot.mesh = _drip_quad()
	pivot.material_override = drip_mat
	pivot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pivot)
	pivot.global_transform = Transform3D(Basis(x_axis, y_axis, normal), pos + normal * 0.006)
	var length := minf(size * rng.randf_range(1.2, 3.0), room * 0.9)
	var width := size * rng.randf_range(0.18, 0.3)
	pivot.scale = Vector3(width, 0.01, 1.0)
	var tw := pivot.create_tween()
	tw.tween_property(pivot, "scale", Vector3(width, length, 1.0), rng.randf_range(1.8, 4.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if splats.size() >= MAX_SPLATS:
		var oldest: Dictionary = splats.pop_front()
		if is_instance_valid(oldest["node"]):
			oldest["node"].queue_free()
	splats.append({"node": pivot, "born": Time.get_ticks_msec() / 1000.0})
	stats["drips"] += 1

var _drip_quad_mesh: QuadMesh
func _drip_quad() -> QuadMesh:
	if _drip_quad_mesh == null:
		_drip_quad_mesh = QuadMesh.new()
		_drip_quad_mesh.size = Vector2.ONE
		_drip_quad_mesh.center_offset = Vector3(0, -0.5, 0)  # grows downward from the pivot
	return _drip_quad_mesh

func _mist(pos: Vector3, size: float) -> void:
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.material_override = mist_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos
	m.rotation.z = rng.randf() * TAU
	m.scale = Vector3.ONE * size * 0.5
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * size, 0.05)
	tw.tween_property(m, "scale", Vector3.ZERO, 0.09)
	tw.tween_callback(m.queue_free)

# Returns a scale factor (1.0 .. 0.3, or 0 = doesn't fit) so the quad's visible area stays on
# the surface. The splat art fills about 70% of its quad, so corners are
# probed at that extent.
const GRID := [
	Vector2(-1, -1), Vector2(-0.5, -1), Vector2(0, -1), Vector2(0.5, -1), Vector2(1, -1),
	Vector2(-1, -0.5), Vector2(-0.5, -0.5), Vector2(0, -0.5), Vector2(0.5, -0.5), Vector2(1, -0.5),
	Vector2(-1, 0), Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(1, 0),
	Vector2(-1, 0.5), Vector2(-0.5, 0.5), Vector2(0, 0.5), Vector2(0.5, 0.5), Vector2(1, 0.5),
	Vector2(-1, 1), Vector2(-0.5, 1), Vector2(0, 1), Vector2(0.5, 1), Vector2(1, 1),
	# Probe the visible 60% corners explicitly too: a narrow gap can fall
	# between the regular grid's 35% and 70% samples on a window frame.
	Vector2(-6.0 / 7.0, -6.0 / 7.0), Vector2(6.0 / 7.0, -6.0 / 7.0),
	Vector2(-6.0 / 7.0, 6.0 / 7.0), Vector2(6.0 / 7.0, 6.0 / 7.0), Vector2.ZERO,
]  # regular grid plus the exact visible corners and impact centre

func _fit(pos: Vector3, normal: Vector3, x_axis: Vector3, y_axis: Vector3, hx: float, hy: float) -> float:
	var space := get_world_3d().direct_space_state
	for k in [1.0, 0.75, 0.55, 0.4, 0.3]:
		var ok := true
		for c in GRID:
			var p: Vector3 = pos + (x_axis * hx * c.x + y_axis * hy * c.y) * 0.7 * k
			var q := PhysicsRayQueryParameters3D.create(p + normal * 0.03, p - normal * 0.03, LAND_MASK)
			var hit := space.intersect_ray(q)
			if hit.is_empty() or (hit["normal"] as Vector3).dot(normal) < 0.9:
				ok = false
				break
		if ok:
			return k
	return 0.0  # too narrow to hold a splat (board edge, door frame end)

# How far the surface continues from `pos` in direction `down` (2 cm steps).
func _surface_below(pos: Vector3, normal: Vector3, down: Vector3, limit: float) -> float:
	var space := get_world_3d().direct_space_state
	var d := 0.0
	while d < limit:
		var p := pos + down * (d + 0.02)
		var q := PhysicsRayQueryParameters3D.create(p + normal * 0.03, p - normal * 0.03, LAND_MASK)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or (hit["normal"] as Vector3).dot(normal) < 0.9:
			break
		d += 0.02
	return d

func _cone(axis: Vector3, spread: float) -> Vector3:
	var v := axis.normalized() + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * spread * rng.randf()
	return v.normalized()

# ----------------------------------------------------------- textures ----
func _mat(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.2              # wet
	m.metallic_specular = 0.7
	m.emission_enabled = true      # faint glow so it reads in the dark lanes
	m.emission = P.BURNT_ORANGE
	m.emission_energy_multiplier = 0.25
	return m

func _paint_splat(seed_i: int, soft := false) -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = 9001 + seed_i * 77
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blobs := [[Vector2(n / 2.0, n / 2.0), r.randf_range(9.0, 12.0)]]
	for i in r.randi_range(4, 7):     # lobes
		var a := r.randf() * TAU
		var d := r.randf_range(6.0, 12.0)
		blobs.append([Vector2(n / 2.0, n / 2.0) + Vector2(cos(a), sin(a)) * d, r.randf_range(3.5, 6.5)])
	for i in r.randi_range(5, 9):     # flung droplets
		var a := r.randf() * TAU
		var d := r.randf_range(15.0, 22.0)
		blobs.append([Vector2(n / 2.0, n / 2.0) + Vector2(cos(a), sin(a)) * d, r.randf_range(1.0, 2.4)])
	var core := P.BURNT_ORANGE.lerp(P.AMBER_GLOW, 0.3)
	var rim := P.BURNT_ORANGE.darkened(0.35)
	var shine := P.AMBER_GLOW.lerp(P.WARM_CHALK, 0.4)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var inside := 99.0
			for b in blobs:
				inside = minf(inside, p.distance_to(b[0]) - b[1])
			if inside < 0.0:
				var c := core if inside < -1.6 else rim
				if inside < -3.0 and r.randf() < 0.06:
					c = shine
				if soft:
					c.a = 0.85
				img.set_pixel(x, y, c)
	# a wet highlight
	var hl := Vector2(n / 2.0 - 3, n / 2.0 - 4)
	for y in range(-2, 2):
		for x in range(-3, 2):
			var px := int(hl.x) + x
			var py := int(hl.y) + y
			if img.get_pixel(px, py).a > 0.0 and absi(x) + absi(y) < 4:
				img.set_pixel(px, py, shine)
	return ImageTexture.create_from_image(img)

# Impact burst: a spiky star of ooze, shown for a few frames at the wound.
func _paint_burst() -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(n / 2.0, n / 2.0)
	var spikes := []
	for i in 9:
		spikes.append([r.randf() * TAU, r.randf_range(8.0, 15.0)])
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5) - c
			var a := d.angle()
			var reach := 4.5
			for sp in spikes:
				var da := absf(wrapf(a - sp[0], -PI, PI))
				reach = maxf(reach, sp[1] * (1.0 - da / 0.28))
			if d.length() < reach:
				img.set_pixel(x, y, P.AMBER_GLOW if d.length() < 3.0 else P.BURNT_ORANGE.darkened(0.1))
	return ImageTexture.create_from_image(img)

func _paint_drip() -> ImageTexture:
	# 12 x 48: a run of ooze, thin at the top, with a bulb at the bottom
	var img := Image.create(12, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var core := P.BURNT_ORANGE.lerp(P.AMBER_GLOW, 0.25)
	var rim := P.BURNT_ORANGE.darkened(0.35)
	for y in 48:
		var t := y / 47.0
		var half := lerpf(2.2, 1.4, t)
		if y > 40:
			half = 3.2 - absf(y - 44.0) * 0.45   # the bulb
		for x in 12:
			var dx := absf(x + 0.5 - 6.0)
			if dx < half:
				img.set_pixel(x, y, core if dx < half - 1.0 else rim)
	img.set_pixel(5, 43, P.AMBER_GLOW.lerp(P.WARM_CHALK, 0.4))
	return ImageTexture.create_from_image(img)
