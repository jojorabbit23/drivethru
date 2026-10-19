# Builds the drive-through shop (structure + starter decoration).
#
# Run from the project folder:
#   godot --headless --path . --script res://tools/make_textures.gd   # only paints missing PNGs
#   godot --headless --path . --import                                # import new/changed PNGs
#   godot --headless --path . --script res://tools/build_shop.gd
#
# Outputs (overwritten every run — do not hand-edit them):
#   res://levels/shop/generated/shop_greybox.tscn  scene used by main.tscn
#   res://export/shop_greybox.glb                  same geometry for Blender etc.
#   res://materials/*.tres                         shared materials
#
# Structure and layout live in this file; decoration lives in shop_decor.gd.
#
# Coordinates: metres. +X east, -Z north (road / customer side), +Y up.
# Floor top is y = 0. Room plan (seen from above, north at top):
#
#              road / customer lane (north)
#        +-----------[hatch]-----+---------------+
#        |                       |               |
#        |   SHOP FLOOR      ===door===  KITCHEN [Window A] -> east lane
#        |                       |               |
#        +-------door------------+-----door------+
#        |                       |               |
# west <-[Window B] BACK OFFICE ===door=== STOREROOM |
#  lane  |                       |               |
#        +-----------------------+--[delivery]---+
#                       delivery bay (south)
extends SceneTree

const Palette = preload("res://core/palette.gd")
const Serving = preload("res://tools/serving_room.gd")
const Decor = preload("res://tools/shop_decor.gd")

const OUT_SCENE := "res://levels/shop/generated/shop_greybox.tscn"
const OUT_GLB := "res://export/shop_greybox.glb"
const MAT_DIR := "res://materials/"
const TEX_DIR := "res://textures/"

# ---------------------------------------------------------------- layout ----
const HALF_W := 6.0        # building is 12 m wide (x)
const HALF_D := 5.0        # building is 10 m deep (z)
const WALL_H := 3.0        # floor to ceiling
const EXT_OUTER := 0.18    # exterior wall outer skin
const EXT_INNER := 0.07    # exterior wall inner (interior-finish) skin
const INT_T := 0.15        # interior partition thickness

const DOOR_W := 1.2
const DOOR_H := 2.2

# Boarded breach windows. "side" is the exterior wall; "at" is the position
# along that wall (z for east/west walls, x for north/south walls).
const WINDOWS := [
	{"id": "A", "side": "east", "at": -2.4, "w": 1.4, "bottom": 0.9, "top": 2.1, "room": "Kitchen"},
	{"id": "B", "side": "west", "at": 2.4, "w": 1.4, "bottom": 0.9, "top": 2.1, "room": "BackOffice"},
]
const BOARD_TILTS := [4.0, -3.0, 6.0, -5.0]   # degrees, one per plank
const BOARD_ROWS := [-0.45, -0.15, 0.15, 0.45] # plank centres relative to window centre
const BOARD_H := 0.2
const BOARD_T := 0.05
const LANE_LEN := 11.0     # approach lane length from the wall
const LANE_W := 3.2

const HATCH := {"at": -3.0, "w": 1.8, "bottom": 1.0, "top": 2.0}      # north wall, shop
const DELIVERY_DOOR := {"at": 3.0, "w": 1.4, "bottom": 0.0, "top": 2.3} # south wall, storeroom

const ROOMS := [
	{"name": "ShopFloor", "label": "SHOP FLOOR", "c": Vector2(-3.0, -2.4), "floor": "floor_tile", "light": 1.6},
	{"name": "Kitchen", "label": "KITCHEN", "c": Vector2(3.0, -2.4), "floor": "floor_tile", "light": 1.5},
	{"name": "BackOffice", "label": "BACK OFFICE", "c": Vector2(-3.0, 2.4), "floor": "floor_concrete", "light": 1.6},
	{"name": "Storeroom", "label": "STOREROOM", "c": Vector2(3.0, 2.4), "floor": "floor_concrete", "light": 1.35},
]

const LAYER_WORLD := 1
const LAYER_BARRICADE := 2
const LAYER_PLAYER_CLIP := 16  # layer 5: blocks only the player (see README)

# ------------------------------------------------------------- materials ----
# c: flat colour (or tint when tex is set) · tex: res://textures/<tex>.png
# uv: "world" (default, 2 m per texture), "local" (object space, centred) or
#     "face" (each face shows the whole texture) · emit: emission colour
# alpha: cut-out transparency (double-sided)
func material_specs() -> Dictionary:
	var P = Palette
	return {
		# building shell
		"ext_wall": {"tex": "wall_teal_block"},
		"plinth": {"tex": "plinth_concrete"},
		"fascia": {"tex": "fascia_orange"},
		"int_wall": {"tex": "wall_tile"},
		"ceiling": {"tex": "ceiling_tiles"},
		"roof": {"tex": "roof_panels"},
		"floor_tile": {"tex": "floor_tile"},
		"floor_concrete": {"tex": "floor_concrete"},
		"trim": {"c": P.OXIDISED_TEAL},
		"door": {"tex": "door_teal", "uv": "face"},
		"boards": {"tex": "wood_board", "uv": "local"},
		# site
		"ground": {"tex": "ground"},
		"road": {"tex": "asphalt"},
		"concrete": {"tex": "concrete"},
		"lane_floor": {"tex": "concrete", "c": Color(0.82, 0.82, 0.82)},
		"barrier": {"tex": "concrete"},
		"palisade": {"tex": "palisade", "uv": "face", "alpha": true},
		"paint_line": {"c": P.WARM_CHALK.darkened(0.15)},
		"paint_hazard": {"c": P.BURNT_ORANGE},
		"paint_orange": {"c": P.BURNT_ORANGE},
		"paint_amber": {"c": P.AMBER_GLOW.darkened(0.1)},
		# metals & woods
		"metal": {"tex": "metal_dark"},
		"steel": {"tex": "steel", "c": Color(0.82, 0.9, 0.96), "metal": 0.35},
		"wood": {"tex": "wood_board", "uv": "local"},
		"crate": {"tex": "crate", "uv": "face"},
		"cardboard": {"tex": "cardboard", "uv": "face"},
		"sandbag": {"tex": "sandbag", "uv": "face"},
		"cabinet": {"tex": "cabinet_teal", "uv": "face"},
		"drawers": {"tex": "drawers", "uv": "face"},
		"ac_unit": {"tex": "ac_unit", "uv": "face"},
		"rubber_mat": {"tex": "rubber_mat"},
		# small props (flat palette colours)
		"chalk": {"c": P.WARM_CHALK},
		"paper_bag": {"c": P.WARM_CHALK.lerp(P.AMBER_GLOW, 0.25).darkened(0.1)},
		"plastic": {"c": P.WARM_CHALK.darkened(0.3)},
		"ink": {"c": P.MIDNIGHT_TYNE},
		"bun": {"c": P.AMBER_GLOW},
		"patty": {"c": P.WET_CHARCOAL.lerp(P.BURNT_ORANGE, 0.35)},
		"lettuce": {"c": P.OXIDISED_TEAL},
		"cheese": {"c": P.AMBER_GLOW.lerp(P.WARM_CHALK, 0.45)},
		"fries": {"c": P.AMBER_GLOW.lerp(P.WARM_CHALK, 0.2)},
		"gem": {"c": P.ELECTRIC_TEAL},
		"mushroom_cap": {"c": P.OXIDISED_TEAL},
		"soil": {"c": P.WET_CHARCOAL.lerp(P.BURNT_ORANGE, 0.2).darkened(0.2)},
		# light sources (the only emissive surfaces)
		"lamp": {"c": P.AMBER_GLOW, "emit": P.AMBER_GLOW, "emit_e": 2.5},
		"panel_light": {"c": P.WARM_CHALK, "emit": P.WARM_CHALK.lerp(P.AMBER_GLOW, 0.3), "emit_e": 1.8},
		"screen": {"c": P.BLUE_SLATE, "emit": P.ELECTRIC_TEAL, "emit_e": 0.6},
		"fridge_glass": {"c": P.BLUE_SLATE, "emit": P.ELECTRIC_TEAL.lerp(P.WARM_CHALK, 0.5), "emit_e": 0.45},
	}

var mats := {}
var uv_modes := {}

func make_materials() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAT_DIR))
	var specs := material_specs()
	specs.merge(Serving.material_specs())
	var missing := []
	for name in specs:
		var spec: Dictionary = specs[name]
		var m := StandardMaterial3D.new()
		m.resource_name = name
		m.albedo_color = spec.get("c", Color.WHITE)
		m.roughness = spec.get("roughness", 0.92)
		m.metallic = spec.get("metal", 0.0)
		m.metallic_specular = 0.25
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		if spec.has("tex"):
			var tpath: String = TEX_DIR + spec["tex"] + ".png"
			if ResourceLoader.exists(tpath):
				m.albedo_texture = load(tpath)
			else:
				missing.append(tpath)
				m.albedo_color = Palette.CONCRETE_GREY
		if spec.has("texture_path"):
			assert(ResourceLoader.exists(spec["texture_path"]), "missing serving-room texture: " + str(spec["texture_path"]))
			m.albedo_texture = load(spec["texture_path"])
			m.uv1_scale = Vector3.ONE * float(spec.get("repeat", 1.0))
		elif spec.has("atlas"):
			# Extract unchanged atlas cells to repeatable textures; never paint over the source.
			var source: Texture2D = load("res://art/serving_room/service_atlas.png")
			var cell: Image = source.get_image().get_region(spec["atlas"])
			cell.generate_mipmaps()
			var texture := ImageTexture.create_from_image(cell)
			var texture_path: String = MAT_DIR + name + "_atlas.res"
			ResourceSaver.save(texture, texture_path)
			texture.take_over_path(texture_path)
			m.albedo_texture = texture
			m.uv1_scale = Vector3.ONE * float(spec.get("repeat", 1.0))
		if spec.get("alpha", false):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if spec.has("emit"):
			m.emission_enabled = true
			m.emission = spec["emit"]
			m.emission_energy_multiplier = spec["emit_e"]
		var path: String = MAT_DIR + name + ".tres"
		var err := ResourceSaver.save(m, path)
		assert(err == OK, "could not save " + path)
		m.take_over_path(path)
		mats[name] = m
		uv_modes[name] = spec.get("uv", "world")
	if not missing.is_empty():
		push_warning("Textures not imported yet (run make_textures + --import): %s" % [missing])

# ----------------------------------------------------- piece accumulation ----
# Everything is boxes and n-sided prisms, merged per group & material.
# Entry: {k: "box"|"prism"|"col", m, c, s (box size), r, h, n (prism), b: basis, col}
var groups := {}
var group_order := []

func _add(group: String, e: Dictionary) -> void:
	if not groups.has(group):
		groups[group] = []
		group_order.append(group)
	groups[group].append(e)

func box(group: String, mat: String, a: Vector3, b: Vector3, collide := true) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	obox(group, mat, (lo + hi) * 0.5, hi - lo, Basis.IDENTITY, collide)

func obox(group: String, mat: String, c: Vector3, s: Vector3, basis: Basis, collide := true) -> void:
	_add(group, {"k": "box", "m": mat, "c": c, "s": s, "b": basis, "col": collide})

# Box given in the local space of transform t (centre + size in local axes).
func tbox(group: String, mat: String, t: Transform3D, c: Vector3, s: Vector3, collide := false) -> void:
	obox(group, mat, t * c, s, t.basis, collide)

# Prism standing on base centre c, axis along basis.y.
func prism(group: String, mat: String, c: Vector3, r: float, h: float, sides := 8, basis := Basis.IDENTITY, collide := false) -> void:
	_add(group, {"k": "prism", "m": mat, "c": c, "r": r, "h": h, "n": sides, "b": basis, "col": collide})

func tprism(group: String, mat: String, t: Transform3D, c: Vector3, r: float, h: float, sides := 8, local_basis := Basis.IDENTITY, collide := false) -> void:
	prism(group, mat, t * c, r, h, sides, t.basis * local_basis, collide)

# Player clip: invisible blocker on its own layer that only the player hits.
# Used to stop climbing onto furniture and to fill slots that would snag.
# Bullets, enemies and thrown things ignore it.
func clip(group: String, a: Vector3, b: Vector3) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	_add(group, {"k": "clip", "c": (lo + hi) * 0.5, "s": hi - lo, "b": Basis.IDENTITY, "col": false})

# Invisible collision box.
func col(group: String, a: Vector3, b: Vector3) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	_add(group, {"k": "col", "c": (lo + hi) * 0.5, "s": hi - lo, "b": Basis.IDENTITY, "col": true})

# A straight wall between y0 and y1 with rectangular openings cut out of it.
# axis "x": runs along X at z = fixed. axis "z": runs along Z at x = fixed.
func wall(group: String, mat: String, axis: String, fixed: float, t: float,
		from: float, to: float, openings: Array, y0 := 0.0, y1 := WALL_H, collide := true) -> void:
	var ops := openings.filter(func(op): return op["bottom"] < y1 and op["top"] > y0)
	ops.sort_custom(func(p, q): return p["at"] < q["at"])
	var cursor := from
	for op in ops:
		var s: float = op["at"] - op["w"] * 0.5
		var e: float = op["at"] + op["w"] * 0.5
		if s > cursor + 0.001:
			wall_piece(group, mat, axis, fixed, t, cursor, s, y0, y1, collide)
		if op["bottom"] > y0 + 0.001:
			wall_piece(group, mat, axis, fixed, t, s, e, y0, minf(op["bottom"], y1), collide)
		if op["top"] < y1 - 0.001:
			wall_piece(group, mat, axis, fixed, t, s, e, maxf(op["top"], y0), y1, collide)
		cursor = e
	if to > cursor + 0.001:
		wall_piece(group, mat, axis, fixed, t, cursor, to, y0, y1, collide)

func wall_piece(group: String, mat: String, axis: String, fixed: float, t: float,
		a: float, b: float, y0: float, y1: float, collide := true) -> void:
	if axis == "x":
		box(group, mat, Vector3(a, y0, fixed - t * 0.5), Vector3(b, y1, fixed + t * 0.5), collide)
	else:
		box(group, mat, Vector3(fixed - t * 0.5, y0, a), Vector3(fixed + t * 0.5, y1, b), collide)

func side_openings(side: String) -> Array:
	var ops := []
	if side == "north":
		ops.append(HATCH)
	if side == "south":
		ops.append(DELIVERY_DOOR)
	for w in WINDOWS:
		if w["side"] == side:
			ops.append(w)
	return ops

# Extra lights requested by the decor pass.
var extra_lights := []

func light(name: String, pos: Vector3, colour: Color, energy: float, rng_m: float, shadow := false) -> void:
	extra_lights.append({"name": name, "pos": pos, "c": colour, "e": energy, "r": rng_m, "shadow": shadow})

# --------------------------------------------------------- mesh output ----
const DIRS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]

func emit_quad(st: SurfaceTool, p: Array, uv: Array, n: Vector3) -> void:
	# Godot treats clockwise triangles (seen from the front) as front faces.
	var ccw: bool = ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).dot(n) > 0.0
	for i in ([0, 2, 1, 0, 3, 2] if ccw else [0, 1, 2, 0, 2, 3]):
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])

func emit_tri(st: SurfaceTool, p: Array, uv: Array, n: Vector3) -> void:
	var ccw: bool = ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]).dot(n) > 0.0
	for i in ([0, 2, 1] if ccw else [0, 1, 2]):
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])

func world_uv(p: Vector3, n: Vector3) -> Vector2:
	# Box-projected UVs, 1 unit = 2 m, oriented to read correctly from outside.
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return Vector2(p.x, p.z) * 0.5
	elif a.x >= a.z:
		return Vector2(-p.z * signf(n.x), -p.y) * 0.5
	return Vector2(p.x * signf(n.z), -p.y) * 0.5

func box_uv(mode: String, q: Vector3, n: Vector3, s: Vector3, w: Vector3, wn: Vector3) -> Vector2:
	match mode:
		"local":
			return world_uv(q, n) + Vector2(0.5, 0.5)
		"face":
			if absf(n.y) > 0.5:
				return Vector2(q.x / s.x + 0.5, q.z / s.z + 0.5)
			var hd := Vector3.UP.cross(n)
			return Vector2(q.dot(hd) / absf(s.dot(hd)) + 0.5, 0.5 - q.y / s.y)
	return world_uv(w, wn)

func emit_box(st: SurfaceTool, c: Vector3, s: Vector3, basis: Basis, mode: String) -> void:
	var h := s * 0.5
	for n in DIRS:
		var u: Vector3 = Vector3.RIGHT if absf(n.y) > 0.5 else Vector3.UP
		var v: Vector3 = n.cross(u)
		var fc: Vector3 = n * h
		var U: Vector3 = u * h
		var V: Vector3 = v * h
		var lp := [fc - U - V, fc + U - V, fc + U + V, fc - U + V]
		var wn: Vector3 = (basis * n).normalized()
		var wp := []
		var uv := []
		for q in lp:
			var w: Vector3 = basis * q + c
			wp.append(w)
			uv.append(box_uv(mode, q, n, s, w, wn))
		emit_quad(st, wp, uv, wn)

func emit_prism(st: SurfaceTool, c: Vector3, r: float, h: float, sides: int, basis: Basis, mode: String) -> void:
	var off := PI / sides
	var circ := TAU * r
	for i in sides:
		var a0 := TAU * i / sides + off
		var a1 := TAU * (i + 1) / sides + off
		var am := (a0 + a1) * 0.5
		var b0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var b1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		var up := Vector3(0, h, 0)
		var lp := [b0, b1, b1 + up, b0 + up]
		var u0 := float(i) / sides
		var u1 := float(i + 1) / sides
		var uv := []
		if mode == "face":
			uv = [Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(u0, 0)]
		else:
			uv = [Vector2(u0 * circ, 0) * 0.5, Vector2(u1 * circ, 0) * 0.5, Vector2(u1 * circ, -h) * 0.5, Vector2(u0 * circ, -h) * 0.5]
		var wp := []
		for q in lp:
			wp.append(basis * q + c)
		emit_quad(st, wp, uv, (basis * Vector3(cos(am), 0, sin(am))).normalized())
		# caps
		var k := 0.5 / r if mode == "face" else 0.5
		var cuv := func(q: Vector3) -> Vector2: return Vector2(q.x, q.z) * k + Vector2(0.5, 0.5)
		var top := [up, b0 + up, b1 + up]
		emit_tri(st, [basis * top[0] + c, basis * top[1] + c, basis * top[2] + c],
			[cuv.call(top[0]), cuv.call(top[1]), cuv.call(top[2])], (basis * Vector3.UP).normalized())
		var bot := [Vector3.ZERO, b1, b0]
		emit_tri(st, [basis * bot[0] + c, basis * bot[1] + c, basis * bot[2] + c],
			[cuv.call(bot[0]), cuv.call(bot[1]), cuv.call(bot[2])], (basis * Vector3.DOWN).normalized())

var tri_count := 0
var group_tris := {}

func build_mesh(entries: Array) -> ArrayMesh:
	var by_mat := {}
	for e in entries:
		if e["k"] == "col" or e["k"] == "clip":
			continue
		if not by_mat.has(e["m"]):
			by_mat[e["m"]] = []
		by_mat[e["m"]].append(e)
	var keys := by_mat.keys()
	keys.sort()
	var mesh := ArrayMesh.new()
	for m in keys:
		assert(mats.has(m), "unknown material " + m)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for e in by_mat[m]:
			if e["k"] == "box":
				emit_box(st, e["c"], e["s"], e["b"], uv_modes[m])
			else:
				emit_prism(st, e["c"], e["r"], e["h"], e["n"], e["b"], uv_modes[m])
		st.index()
		st.generate_tangents()
		st.set_material(mats[m])
		st.commit(mesh)
		mesh.surface_set_name(mesh.get_surface_count() - 1, m)
	return mesh

func entry_tris(e: Dictionary) -> int:
	match e["k"]:
		"box": return 12
		"prism": return int(e["n"]) * 4
	return 0

func make_group_node(name: String, entries: Array) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = build_mesh(entries)
	var t := 0
	for e in entries:
		t += entry_tris(e)
	group_tris[name] = t
	tri_count += t
	var body: StaticBody3D = null
	for e in entries:
		if not e["col"]:
			continue
		if body == null:
			body = StaticBody3D.new()
			body.name = "Collision"
			body.collision_layer = LAYER_WORLD
			body.collision_mask = 0
			mi.add_child(body)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		if e["k"] == "prism":
			shape.size = Vector3(e["r"] * 2.0, e["h"], e["r"] * 2.0)
			cs.transform = Transform3D(e["b"], e["c"] + e["b"] * Vector3(0, e["h"] * 0.5, 0))
		else:
			shape.size = e["s"]
			cs.transform = Transform3D(e["b"], e["c"])
		cs.shape = shape
		body.add_child(cs)
	var clip_body: StaticBody3D = null
	for e in entries:
		if e["k"] != "clip":
			continue
		if clip_body == null:
			clip_body = StaticBody3D.new()
			clip_body.name = "PlayerClip"
			clip_body.collision_layer = LAYER_PLAYER_CLIP
			clip_body.collision_mask = 0
			mi.add_child(clip_body)
		var ccs := CollisionShape3D.new()
		var cshape := BoxShape3D.new()
		cshape.size = e["s"]
		ccs.shape = cshape
		ccs.position = e["c"]
		clip_body.add_child(ccs)
	return mi

func single_box_mesh(mat: String, size: Vector3, centre := Vector3.ZERO) -> ArrayMesh:
	return build_mesh([{"k": "box", "m": mat, "c": centre, "s": size, "b": Basis.IDENTITY, "col": false}])

# ------------------------------------------------------------ structure ----
var IX: float # interior half-extents (inside faces of exterior walls)
var IZ: float

func build_structure() -> void:
	IX = HALF_W - EXT_OUTER - EXT_INNER
	IZ = HALF_D - EXT_OUTER - EXT_INNER
	var oz := HALF_D - EXT_OUTER * 0.5
	var iz := HALF_D - EXT_OUTER - EXT_INNER * 0.5
	var ox := HALF_W - EXT_OUTER * 0.5
	var ix := HALF_W - EXT_OUTER - EXT_INNER * 0.5
	var ew := HALF_D - EXT_OUTER

	# Exterior walls: painted block outer skin + tiled interior skin.
	wall("Walls_Exterior", "ext_wall", "x", -oz, EXT_OUTER, -HALF_W, HALF_W, side_openings("north"))
	wall("Walls_Exterior", "ext_wall", "x", oz, EXT_OUTER, -HALF_W, HALF_W, side_openings("south"))
	wall("Walls_Exterior", "ext_wall", "z", ox, EXT_OUTER, -ew, ew, side_openings("east"))
	wall("Walls_Exterior", "ext_wall", "z", -ox, EXT_OUTER, -ew, ew, side_openings("west"))
	wall("Walls_Interior", "int_wall", "x", -iz, EXT_INNER, -IX, IX, side_openings("north"))
	wall("Walls_Interior", "int_wall", "x", iz, EXT_INNER, -IX, IX, side_openings("south"))
	wall("Walls_Interior", "int_wall", "z", ix, EXT_INNER, -ew, ew, side_openings("east"))
	wall("Walls_Interior", "int_wall", "z", -ix, EXT_INNER, -ew, ew, side_openings("west"))

	# Partitions: east-west wall at z = 0, north-south wall at x = 0 (split in two).
	var door := func(at: float) -> Dictionary:
		return {"at": at, "w": DOOR_W, "bottom": 0.0, "top": DOOR_H}
	wall("Walls_Interior", "int_wall", "x", 0.0, INT_T, -IX, IX, [door.call(-3.0), door.call(3.0)])
	var ht := INT_T * 0.5
	wall("Walls_Interior", "int_wall", "z", 0.0, INT_T, -IZ, -ht, [door.call(-2.4)])  # shop | kitchen
	wall("Walls_Interior", "int_wall", "z", 0.0, INT_T, ht, IZ, [door.call(2.4)])     # office | storeroom

	# Floors: one slab per room so rooms can be re-surfaced separately.
	for r in ROOMS:
		var c: Vector2 = r["c"]
		var x0 := -HALF_W if c.x < 0 else 0.0
		var x1 := 0.0 if c.x < 0 else HALF_W
		var z0 := -HALF_D if c.y < 0 else 0.0
		var z1 := 0.0 if c.y < 0 else HALF_D
		box("Floor", r["floor"], Vector3(x0, -0.1, z0), Vector3(x1, 0.0, z1))

	# Ceiling and roof (separate nodes so previews/tools can hide them).
	box("Ceiling", "ceiling", Vector3(-HALF_W, WALL_H, -HALF_D), Vector3(HALF_W, WALL_H + 0.05, HALF_D))
	box("Roof", "roof", Vector3(-HALF_W - 0.3, WALL_H + 0.05, -HALF_D - 0.3), Vector3(HALF_W + 0.3, WALL_H + 0.25, HALF_D + 0.3))

	# Service hatch: rolled shutter housing and jambs (counter is decor).
	var hx: float = HATCH["at"]
	var hw: float = HATCH["w"]
	box("Fixtures", "trim", Vector3(hx - hw * 0.5 - 0.1, HATCH["top"], -HALF_D - 0.18), Vector3(hx + hw * 0.5 + 0.1, HATCH["top"] + 0.32, -HALF_D))
	for sgn in [-1.0, 1.0]:
		box("Fixtures", "trim", Vector3(hx + sgn * (hw * 0.5), HATCH["bottom"], -HALF_D - 0.06), Vector3(hx + sgn * (hw * 0.5 + 0.08), HATCH["top"], -HALF_D))
	# Delivery door frame (the door itself is a separate, openable node).
	var dx: float = DELIVERY_DOOR["at"]
	var dw: float = DELIVERY_DOOR["w"]
	for sgn in [-1.0, 1.0]:
		box("Fixtures", "trim", Vector3(dx + sgn * (dw * 0.5), 0.0, HALF_D), Vector3(dx + sgn * (dw * 0.5 + 0.08), DELIVERY_DOOR["top"] + 0.08, HALF_D + 0.06))
	box("Fixtures", "trim", Vector3(dx - dw * 0.5 - 0.08, DELIVERY_DOOR["top"], HALF_D), Vector3(dx + dw * 0.5 + 0.08, DELIVERY_DOOR["top"] + 0.08, HALF_D + 0.06))
	# Ceiling light panels (emissive; no collision).
	for r in ROOMS:
		var c: Vector2 = r["c"]
		box("Fixtures", "metal", Vector3(c.x - 0.65, WALL_H - 0.06, c.y - 0.35), Vector3(c.x + 0.65, WALL_H, c.y + 0.35), false)
		box("Fixtures", "panel_light", Vector3(c.x - 0.6, WALL_H - 0.07, c.y - 0.3), Vector3(c.x + 0.6, WALL_H - 0.06, c.y + 0.3), false)

func window_basis(w: Dictionary) -> Basis:
	var outward: Vector3 = {"east": Vector3.RIGHT, "west": Vector3.LEFT, "north": Vector3.FORWARD, "south": Vector3.BACK}[w["side"]]
	return Basis(Vector3.UP.cross(outward), Vector3.UP, outward)

func window_origin(w: Dictionary) -> Vector3:
	var y: float = (w["bottom"] + w["top"]) * 0.5
	match w["side"]:
		"east": return Vector3(HALF_W, y, w["at"])
		"west": return Vector3(-HALF_W, y, w["at"])
		"north": return Vector3(w["at"], y, -HALF_D)
	return Vector3(w["at"], y, HALF_D)

# Transform with origin at the window opening's centre on the outer wall face,
# +Z pointing out of the building, +Y up.
func window_frame(w: Dictionary) -> Transform3D:
	return Transform3D(window_basis(w), window_origin(w))

func build_window_lane(w: Dictionary) -> void:
	var t := window_frame(w)
	var ww: float = w["w"]
	var wh: float = w["top"] - w["bottom"]
	# Heavy dark steel frame + concrete sill (concept: dark frames on teal walls).
	for sgn in [-1.0, 1.0]:
		tbox("Trim", "metal", t, Vector3(sgn * (ww * 0.5 + 0.05), 0.0, 0.035), Vector3(0.1, wh + 0.2, 0.07))
		tbox("Trim", "metal", t, Vector3(0.0, sgn * (wh * 0.5 + 0.05), 0.035), Vector3(ww + 0.2, 0.1, 0.07))
	tbox("Trim", "concrete", t, Vector3(0.0, -wh * 0.5 - 0.13, 0.08), Vector3(ww + 0.36, 0.07, 0.16))
	# Approach lane: concrete strip fenced by jersey barriers.
	var lane: String = "Lane_" + w["id"]
	var y0: float = -w["bottom"] - wh * 0.5  # local y of floor level
	tbox(lane, "lane_floor", t, Vector3(0.0, y0 - 0.01, LANE_LEN * 0.5), Vector3(LANE_W, 0.02, LANE_LEN), true)
	var seg := 1.9
	var n_seg := int(floor(LANE_LEN / 2.0))
	for side in [-1.0, 1.0]:
		var lx: float = side * (LANE_W * 0.5 + 0.25)
		for i in n_seg:
			var z := 0.2 + i * 2.0 + seg * 0.5
			tbox(lane, "barrier", t, Vector3(lx, y0 + 0.4, z), Vector3(0.5, 0.8, seg), true)
			tbox(lane, "barrier", t, Vector3(lx, y0 + 0.9, z), Vector3(0.28, 0.2, seg), true)
		tbox(lane, "paint_hazard", t, Vector3(side * 0.6, y0 + 0.002, 0.45), Vector3(0.6, 0.012, 0.25))
	# Lamp post on the far side of the lane, arm leaning over it.
	var px: float = LANE_W * 0.5 + 0.95
	tbox(lane, "metal", t, Vector3(px, y0 + 1.8, LANE_LEN * 0.55), Vector3(0.16, 3.6, 0.16), true)
	tbox(lane, "metal", t, Vector3(px - 0.8, y0 + 3.55, LANE_LEN * 0.55), Vector3(1.6, 0.1, 0.12))
	tbox(lane, "lamp", t, Vector3(px - 1.45, y0 + 3.47, LANE_LEN * 0.55), Vector3(0.4, 0.06, 0.2))

func build_site() -> void:
	box("Ground", "ground", Vector3(-40, -0.3, -40), Vector3(40, -0.02, 40))
	# Customer road along the north face, one-way west -> east past the hatch.
	box("Road", "road", Vector3(-40, -0.02, -10.0), Vector3(40, 0.0, -6.0))
	for i in range(-13, 14):
		var x := i * 3.0
		box("Road", "paint_line", Vector3(x, -0.005, -8.05), Vector3(x + 1.5, 0.008, -7.95), false)
	var hx: float = HATCH["at"]
	box("Road", "paint_hazard", Vector3(hx - 2.6, -0.005, -9.7), Vector3(hx - 2.45, 0.008, -6.3), false)
	box("Road", "paint_hazard", Vector3(hx + 2.45, -0.005, -9.7), Vector3(hx + 2.6, 0.008, -6.3), false)
	box("Road", "concrete", Vector3(-40, -0.02, -6.0), Vector3(40, 0.12, -5.75))  # kerb
	# Delivery apron at the back door.
	var dx: float = DELIVERY_DOOR["at"]
	box("Road", "lane_floor", Vector3(dx - 2.5, -0.02, HALF_D), Vector3(dx + 2.5, 0.0, HALF_D + 5.0))
	for i in 5:
		var z := HALF_D + 0.6 + i * 0.9
		box("Road", "paint_hazard", Vector3(dx - 2.3, -0.005, z), Vector3(dx - 1.9, 0.008, z + 0.45), false)
		box("Road", "paint_hazard", Vector3(dx + 1.9, -0.005, z), Vector3(dx + 2.3, 0.008, z + 0.45), false)

# --------------------------------------------------------- live nodes ----
func make_marker(parent: Node, name: String, pos: Vector3, yaw_deg := 0.0) -> Marker3D:
	var m := Marker3D.new()
	m.name = name
	m.position = pos
	m.rotation_degrees.y = yaw_deg
	m.gizmo_extents = 0.5
	parent.add_child(m)
	return m

func make_windows(parent: Node3D) -> void:
	for w in WINDOWS:
		var node := Node3D.new()
		node.name = "Window_" + w["id"]
		node.transform = window_frame(w)
		node.set_script(load("res://core/window_barricade.gd"))
		node.set_meta("window_id", w["id"])
		node.set_meta("room", w["room"])
		node.set_meta("opening_size", Vector2(w["w"], w["top"] - w["bottom"]))
		parent.add_child(node)
		var boards := Node3D.new()
		boards.name = "Boards"
		node.add_child(boards)
		var size := Vector3(w["w"] + 0.4, BOARD_H, BOARD_T)
		var mesh := single_box_mesh("boards", size)
		var shape := BoxShape3D.new()
		shape.size = size
		for i in BOARD_ROWS.size():
			var sb := StaticBody3D.new()
			sb.name = "Board_%d" % (i + 1)
			sb.collision_layer = LAYER_BARRICADE
			sb.collision_mask = 0
			sb.set_meta("board_index", i)
			sb.position = Vector3(0.0, BOARD_ROWS[i], 0.07 + BOARD_T * 0.5 + 0.01)
			sb.rotation = Vector3(0.0, 0.0, deg_to_rad(BOARD_TILTS[i % BOARD_TILTS.size()]))
			var mi := MeshInstance3D.new()
			mi.name = "Mesh"
			mi.mesh = mesh
			sb.add_child(mi)
			var cs := CollisionShape3D.new()
			cs.name = "Shape"
			cs.shape = shape
			sb.add_child(cs)
			boards.add_child(sb)
			tri_count += 12
		var floor_y: float = -(w["bottom"] + w["top"]) * 0.5
		make_marker(node, "Breach_Point", Vector3(0, floor_y, 0.8))
		make_marker(node, "Repair_Point", Vector3(0, floor_y, -0.9))
		make_marker(node, "Lane_Spawn", Vector3(0, floor_y, LANE_LEN - 1.0))

func make_delivery_door(parent: Node3D) -> void:
	var sb := StaticBody3D.new()
	sb.name = "Delivery_Door"
	sb.collision_layer = LAYER_WORLD
	var w: float = DELIVERY_DOOR["w"] - 0.04
	var h: float = DELIVERY_DOOR["top"] - 0.02
	# Hinged on its west edge: the node origin sits on the hinge.
	sb.position = Vector3(DELIVERY_DOOR["at"] - DELIVERY_DOOR["w"] * 0.5 + 0.02, 0.0, HALF_D - EXT_OUTER * 0.5)
	var size := Vector3(w, h, 0.07)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = single_box_mesh("door", size)
	mi.position = Vector3(w * 0.5, h * 0.5, 0.0)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = mi.position
	sb.add_child(cs)
	parent.add_child(sb)
	tri_count += 12

func add_omni(parent: Node3D, name: String, pos: Vector3, colour: Color, energy: float, range_m: float, shadow: bool) -> void:
	var l := OmniLight3D.new()
	l.name = name
	l.position = pos
	l.light_color = colour
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadow
	parent.add_child(l)

func make_lights(parent: Node3D) -> void:
	for r in ROOMS:
		var c: Vector2 = r["c"]
		add_omni(parent, "Light_" + r["name"], Vector3(c.x, WALL_H - 0.35, c.y),
			Palette.AMBER_GLOW.lerp(Palette.WARM_CHALK, 0.35), r["light"], 6.5, true)
	for w in WINDOWS:
		var t := window_frame(w)
		var y0: float = -(w["bottom"] + w["top"]) * 0.5
		add_omni(parent, "LaneLamp_" + w["id"], t * Vector3(LANE_W * 0.5 - 0.5, y0 + 3.3, LANE_LEN * 0.55),
			Palette.AMBER_GLOW, 2.2, 9.0, true)
	var s := SpotLight3D.new()
	s.name = "HatchLight"
	s.position = Vector3(HATCH["at"], HATCH["top"] + 0.45, -HALF_D - 0.4)
	s.rotation_degrees = Vector3(-70, 0, 0)
	s.light_color = Palette.AMBER_GLOW
	s.light_energy = 2.0
	s.spot_range = 7.0
	s.spot_angle = 45.0
	parent.add_child(s)
	add_omni(parent, "FrontageLight", Vector3(0.0, WALL_H + 0.6, -HALF_D - 1.6), Palette.AMBER_GLOW, 1.4, 9.0, false)
	for l in extra_lights:
		add_omni(parent, l["name"], l["pos"], l["c"], l["e"], l["r"], l["shadow"])

func make_labels(parent: Node3D) -> void:
	parent.visible = false # press L in game to show
	for r in ROOMS:
		var c: Vector2 = r["c"]
		var lb := Label3D.new()
		lb.name = "Label_" + r["name"]
		lb.text = r["label"]
		lb.position = Vector3(c.x, 2.45, c.y)
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.pixel_size = 0.004
		lb.font_size = 48
		lb.modulate = Palette.WARM_CHALK
		lb.outline_modulate = Palette.MIDNIGHT_TYNE
		lb.outline_size = 10
		parent.add_child(lb)
	for w in WINDOWS:
		var lb := Label3D.new()
		lb.name = "Label_Window_" + w["id"]
		lb.text = "WINDOW " + w["id"]
		lb.position = window_frame(w) * Vector3(0, 1.2, 0.3)
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.pixel_size = 0.004
		lb.font_size = 40
		lb.modulate = Palette.ELECTRIC_TEAL
		lb.outline_modulate = Palette.MIDNIGHT_TYNE
		lb.outline_size = 10
		parent.add_child(lb)

func make_sign(parent: Node3D) -> void:
	var lb := Label3D.new()
	lb.name = "ShopSign"
	lb.text = "THE DRIVE THRU"
	# Label3D reads from its +Z side, so turn it to face the road (-Z).
	lb.position = Vector3(-0.6, WALL_H - 0.38, -HALF_D - 0.03)
	lb.rotation_degrees = Vector3(0, 180, 0)
	lb.pixel_size = 0.009
	lb.font_size = 56
	lb.modulate = Palette.AMBER_GLOW
	lb.outline_modulate = Palette.MIDNIGHT_TYNE
	lb.outline_size = 14
	lb.shaded = false
	parent.add_child(lb)

func make_markers(parent: Node3D) -> void:
	var hx: float = HATCH["at"]
	var shop: Vector2 = ROOMS[0]["c"]
	make_marker(parent, "PlayerStart", Vector3(shop.x, 0.0, shop.y + 0.8))  # faces north, toward the hatch
	make_marker(parent, "Customer_Lane_Start", Vector3(-38, 0, -8.0), -90)
	make_marker(parent, "Customer_Stop", Vector3(hx, 0, -8.0), -90)
	make_marker(parent, "Customer_Lane_End", Vector3(38, 0, -8.0), -90)
	make_marker(parent, "Delivery_Spawn", Vector3(DELIVERY_DOOR["at"], 0, 30.0), 0)
	make_marker(parent, "Delivery_Drop", Vector3(DELIVERY_DOOR["at"], 0, HALF_D + 1.2), 0)

# Navigation mesh for zombies inside the building (they walk the lanes in
# straight lines, then climb through a window onto this mesh). Baked from the
# world collision layer only, so player-clip volumes don't affect it.
func bake_navigation(shop: Node3D) -> void:
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	var nm := NavigationMesh.new()
	nm.cell_size = 0.05
	nm.cell_height = 0.05
	nm.agent_radius = 0.35
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.15
	nm.agent_max_slope = 35.0
	nm.region_min_size = 1.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = LAYER_WORLD
	nm.filter_baking_aabb = AABB(Vector3(-HALF_W, -0.5, -HALF_D), Vector3(HALF_W * 2.0, 2.4, HALF_D * 2.0))
	region.navigation_mesh = nm
	shop.add_child(region)
	root.add_child(shop) # parsing needs global transforms
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, shop)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	root.remove_child(shop)
	print("navmesh: %d polygons, %d vertices" % [nm.get_polygon_count(), nm.get_vertices().size()])

func own_all(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		own_all(c, owner)

# ----------------------------------------------------------------- main ----
func _initialize() -> void:
	_build.call_deferred() # navmesh parsing needs a running SceneTree

func _build() -> void:
	make_materials()
	build_structure()
	for w in WINDOWS:
		build_window_lane(w)
	build_site()
	var decor = Decor.new()
	decor.build(self)

	var root := Node3D.new()
	root.name = "ShopGreybox"
	var structure := Node3D.new()
	structure.name = "Structure"
	root.add_child(structure)
	var decor_root := Node3D.new()
	decor_root.name = "Decor"
	root.add_child(decor_root)
	for g in group_order:
		var parent := decor_root if (g as String).begins_with("Decor") or (g as String).begins_with("Props") else structure
		parent.add_child(make_group_node(g, groups[g]))
	var windows := Node3D.new(); windows.name = "Windows"; root.add_child(windows)
	make_windows(windows)
	var doors := Node3D.new(); doors.name = "Doors"; root.add_child(doors)
	make_delivery_door(doors)
	var lights := Node3D.new(); lights.name = "Lights"; root.add_child(lights)
	make_lights(lights)
	var labels := Node3D.new(); labels.name = "GreyboxLabels"; root.add_child(labels)
	make_labels(labels)
	make_sign(root)
	var markers := Node3D.new(); markers.name = "Markers"; root.add_child(markers)
	make_markers(markers)
	bake_navigation(root)
	own_all(root, root)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels/shop/generated"))
	var packed := PackedScene.new()
	var err := packed.pack(root)
	assert(err == OK)
	err = ResourceSaver.save(packed, OUT_SCENE)
	print("saved ", OUT_SCENE, " err=", err)

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	err = doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT_GLB))
	print("saved ", OUT_GLB, " err=", err)

	var names := group_tris.keys()
	names.sort()
	for g in names:
		print("  %-22s %6d tris" % [g, group_tris[g]])
	print("lights: ", lights.get_child_count(), "   approx triangles: ", tri_count)
	root.free()
	quit()
