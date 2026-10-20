# Builds the pistol's first-person viewmodel, following the knife and the
# shotgun:
#
#   godot --headless --path . --script res://tools/build_pistol.gd
#
# Writes res://weapons/pistol/:
#   pistol_hand_r.res / pistol_hand_l.res  Cleatimus's sculpted glove (the knife
#       hand, already fitted round a handle) moved into handle space, and a
#       mirrored copy for the left support hand
#   pistol_viewmodel.tscn  owner's stylized pistol with Cleatimus hands.
#   stylized_pistol_rig.tscn / stylized_*.res / stylized_albedo.png: mechanical
#       rig from tools/stylized_pistol_rig.gd. Pack measurements are retained
#       for the established hand sockets; retain the pack's CC BY 4.0 credit.
#
# Handle space is the knife's: the handle runs along +Z from the origin, the
# thumb points down -Z (where the knife's blade went) and the back of the hand
# is +Y -- the same frame the shotgun sockets its hands in. The pistol's own
# space is measured, not assumed: +X right, +Y up, +Z forward (the muzzle), with
# the pack's origin in the grip. Its parts are boxes on those axes, so the slide
# gives the bore, the magazine gives the grip and the hammer gives up.
#
# The knife hand's forearm is only about 30 deg off the handle it grips, so a
# fist wrapped round a pistol grip sends the wrist straight down. The grip hand
# is therefore rolled about the grip (which is what sets how the fingers wrap
# it) and lifted about the grip's perpendicular (which brings the wrist up); both
# numbers were picked off rendered variants, kept as the sheets
# docs/previews/pistol_grip_sheet.png and pistol_wrist_sheet.png, and the fist is
# then slid back up the grip by the amount the lift drops it.
extends SceneTree

const OUT := "res://weapons/pistol/"
# The model itself, not the addon's prop scene: the prop only adds StaticBody3D
# collision (for picking the gun up in a demo), and a viewmodel parented to the
# camera must not have collision bodies sitting inside the player.
const PISTOL := "res://addons/psx_fps_arms/models/pistol_model.glb"
const KNIFE_VM := "res://weapons/knife/knife_viewmodel.tscn"
const Common = preload("res://tools/build_crop_duster.gd")

const CUT := 0.14              # along the forearm: keep the glove and cuff up to here
const SLEEVE_R0 := 0.045       # new sleeve radius at the cuff ...
const SLEEVE_R1 := 0.058       # ... and at the elbow
const SLEEVE_LEN := 0.62
const SLEEVE_UV := Vector2(0.0, 0.2)   # the sleeve fabric on the arms atlas

# Where the fist closes on the grip, in the pistol's own space. The knife hand's
# handle origin is the middle of its fist, so this is the top of the grip, under
# the trigger guard -- the same place the shotgun puts its grip socket.
const GRIP_POINT := Vector3(0.0, 0.008, -0.006)
const SUPPORT_OFFSET := Vector3(0.0, -0.018, 0.014)   # support hand: lower, and forward
const SUPPORT_YAW := 35.0      # its palm, swung from the grip's left side toward the muzzle

# The pistol's own "down": the magazine's long axis, which the sockets line the
# knife hand's handle up with. The wrist fixes below are rotations about it (the
# roll, which is what sets how the fingers wrap the grip) and about the axis
# perpendicular to it (the lift, which is what raises the wrist).
const GRIP_AXIS := Vector3(0.0, -1.0, 0.0)
const GRIP_ROLL := 90.0        # the wrap the owner picked (pistol_grip_sheet.png, cell 3)
const WRIST_LIFT := 45.0       # the arm angle they picked (pistol_wrist_sheet.png, cell 4)
const GRIP_RAISE := 0.005      # up the grip again, by what the lift drops the fist

var pistol: Node3D

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	pistol = (load(PISTOL) as PackedScene).instantiate() as Node3D
	print("pistol root: ", pistol.name, " <", pistol.get_class(), "> from ", pistol.scene_file_path)
	var hands := build_hands()
	build_model(hands[0], hands[1], hands[2], hands[3])
	quit()

# ------------------------------------------------------------- hands ----
# Cleatimus's glove, taken out of the knife viewmodel and expressed in handle
# space. Returns the right and the left (mirrored) mesh, then each hand's own
# forearm direction (which the wrist fix needs).
func build_hands() -> Array:
	var vm: Node3D = (load(KNIFE_VM) as PackedScene).instantiate()
	root.add_child(vm)
	var anim: AnimationPlayer = vm.find_child("AnimationPlayer", true, false)
	anim.play("kitchen_knife_idle", 0.0)
	anim.seek(0.0, true)
	var skel: Skeleton3D = vm.find_child("Skeleton3D", true, false)
	var grip: Node3D = vm.find_child("GripOffset", true, false)
	var model: Node3D = grip.get_node("Model")
	var knife0: Transform3D = skel.get_bone_global_pose(skel.find_bone("weapon_r")) * grip.transform * model.transform
	var src: ArrayMesh = (vm.find_child("RightHand", true, false) as MeshInstance3D).mesh
	var inv := knife0.affine_inverse()
	var out := []
	var arms := []
	for mirror in [false, true]:
		var a := _unindexed(src.surface_get_arrays(0))
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		for i in v.size():
			v[i] = inv * v[i]
			n[i] = (inv.basis * n[i]).normalized()
			if mirror:
				v[i].x = -v[i].x
				n[i].x = -n[i].x
		# The knife hand's sleeve is a short cone that tapers to a point. Keep
		# the glove and its cuff (up to CUT along the forearm), drop the cone,
		# and grow a proper sleeve out of the cuff instead.
		var arm_dir := Vector3.ZERO
		for q in v:
			if q.z > 0.2:
				arm_dir += q
		arm_dir = arm_dir.normalized()
		var cuff := Vector3.ZERO
		var nc := 0
		for q in v:
			var t := q.dot(arm_dir)
			if t > CUT - 0.03 and t < CUT:
				cuff += q
				nc += 1
		cuff /= maxf(nc, 1)
		var keep := PackedInt32Array()
		for tri in range(0, v.size(), 3):
			if v[tri].dot(arm_dir) <= CUT and v[tri + 1].dot(arm_dir) <= CUT and v[tri + 2].dot(arm_dir) <= CUT:
				keep.append(tri)
		a = _take_triangles(a, keep)
		v = a[Mesh.ARRAY_VERTEX]
		if mirror:
			_flip_winding(a)
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		m.surface_set_material(0, src.surface_get_material(0))
		# the sleeve starts tucked inside the cuff, so there's no seam to see
		var start := cuff - arm_dir * 0.02
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _sleeve(start, arm_dir, a))
		m.surface_set_material(1, src.surface_get_material(0))
		var path := OUT + ("pistol_hand_l.res" if mirror else "pistol_hand_r.res")
		ResourceSaver.save(m, path)
		m.take_over_path(path)
		print("hand %s: %d glove vertices kept, sleeve from %s along %s" % ["left" if mirror else "right", v.size(), start, arm_dir])
		out.append(m)
		arms.append(arm_dir)
	vm.queue_free()
	return [out[0], out[1], arms[0], arms[1]]

# An 8-sided sleeve: SLEEVE_R0 at the cuff widening to SLEEVE_R1 at the elbow,
# SLEEVE_LEN long (well off the bottom of the screen). Its UVs sit in the
# sleeve's fabric on the arms atlas; its vertex colour is the cuff's average.
func _sleeve(start: Vector3, dir: Vector3, glove: Array) -> Array:
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = dir.cross(Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	var col := Color(1, 1, 1)
	if glove[Mesh.ARRAY_COLOR] != null:
		var cs: PackedColorArray = glove[Mesh.ARRAY_COLOR]
		var gv: PackedVector3Array = glove[Mesh.ARRAY_VERTEX]
		var acc := Color(0, 0, 0, 0)
		var k := 0
		for i in gv.size():
			if gv[i].dot(dir) > CUT - 0.04:
				acc += cs[i]
				k += 1
		if k > 0:
			col = acc / k
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	const SEG := 8
	var rings := [[0.0, SLEEVE_R0], [SLEEVE_LEN * 0.5, (SLEEVE_R0 + SLEEVE_R1) * 0.5], [SLEEVE_LEN, SLEEVE_R1]]
	for r in rings.size() - 1:
		var a0: Array = rings[r]
		var a1: Array = rings[r + 1]
		for s in SEG:
			var quad := []
			for corner in [[a0, s], [a1, s], [a1, s + 1], [a0, s + 1]]:
				var ring: Array = corner[0]
				var ang: float = TAU * float(corner[1]) / SEG + PI / SEG
				var radial: Vector3 = side * cos(ang) + up * sin(ang)
				quad.append([start + dir * float(ring[0]) + radial * float(ring[1]), radial, Vector2(SLEEVE_UV.x + 0.08 * float(corner[1]) / SEG, SLEEVE_UV.y + 0.25 * float(ring[0]) / SLEEVE_LEN)])
			for idx in [0, 2, 1, 0, 3, 2]:
				var c: Array = quad[idx]
				verts.append(c[0])
				norms.append((c[1] as Vector3))
				uvs.append(c[2])
				cols.append(col)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	return arr

# Arrays with ARRAY_INDEX expanded, bones/weights/tangents dropped.
static func _unindexed(a: Array) -> Array:
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var idx = a[Mesh.ARRAY_INDEX]
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
		if a[k] == null:
			continue
		if idx == null:
			out[k] = a[k].duplicate()
		else:
			var src = a[k]
			var dst = src.duplicate()
			dst.resize(0)
			for i: int in idx:
				dst.append(src[i])
			out[k] = dst
	return out

static func _take_triangles(a: Array, starts: PackedInt32Array) -> Array:
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
		if a[k] == null:
			continue
		var src = a[k]
		var dst = src.duplicate()
		dst.resize(0)
		for s: int in starts:
			dst.append(src[s])
			dst.append(src[s + 1])
			dst.append(src[s + 2])
		out[k] = dst
	return out

# mirroring turns the triangles inside out: swap their winding
static func _flip_winding(a: Array) -> void:
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
		if a[k] == null:
			continue
		var arr = a[k]
		for t in range(0, arr.size(), 3):
			var tmp = arr[t + 1]
			arr[t + 1] = arr[t + 2]
			arr[t + 2] = tmp
		a[k] = arr

# ------------------------------------------------------------- model ----
func build_model(hand_r: Mesh, hand_l: Mesh, arm_r: Vector3, arm_l: Vector3) -> void:
	# --- measure the pistol: the bore, and which way is up -----------------
	var grip_box := part_box("magazine")
	var slide_box := part_box("slide")
	var hammer_box := part_box("hammer")
	var bore := longest_axis(slide_box.size)
	# the muzzle is the far end of the slide from the hammer, which sits at the back
	if bore.dot(slide_box.get_center() - hammer_box.get_center()) < 0.0:
		bore = -bore
	# up runs from the magazine (low, in the grip) to the hammer (high, at the back)
	var up := principal_axis(hammer_box.get_center() - grip_box.get_center())
	if up.dot(hammer_box.get_center() - grip_box.get_center()) < 0.0:
		up = -up
	var down := -up
	var sideways := up.cross(bore)     # the shooter's right
	print("grip box ", grip_box.get_center(), " size ", grip_box.size)
	print("slide box ", slide_box.get_center(), " size ", slide_box.size)
	print("hammer box ", hammer_box.get_center(), " size ", hammer_box.size)
	print("bore ", bore, " up ", up, " right ", sideways)

	# --- the scene ---------------------------------------------------------
	var scene := Node3D.new()
	scene.name = "PistolViewmodel"
	var model := Node3D.new()
	model.name = "Model"
	# the pack's props face their own +Z: swing the bore to Godot's forward
	model.basis = rotation_to(bore, Vector3.FORWARD, up, Vector3.UP)
	scene.add_child(model)
	model.owner = scene
	model.add_child(pistol)
	pistol.owner = scene
	print("model rotation degrees ", model.rotation_degrees)

	# --- the hands ---------------------------------------------------------
	# handle +Z runs down the grip, handle +Y is the back of the hand; the
	# shotgun sockets its grip hand the same way (rot 70 about X, no roll), but
	# the pistol's grip is vertical, so the wrist needs the two fixes below.
	var back := -bore
	var grip_basis := lifted(Basis(GRIP_AXIS, deg_to_rad(GRIP_ROLL)) * basis_from(back, down), arm_r)
	socket(model, scene, "GripSocket", GRIP_POINT + Vector3.UP * GRIP_RAISE, grip_basis, hand_r, "RightHand")
	# The support hand's back faces left, swung toward the muzzle, so its palm
	# meets the grip and its fingers cross the firing hand's. It keeps its own
	# wrap (the owner only ruled on the firing hand) but gets the same lift, so
	# both wrists read the same.
	var yaw := deg_to_rad(SUPPORT_YAW)
	var support_back := ((-sideways) * cos(yaw) + bore * sin(yaw)).normalized()
	socket(model, scene, "SupportSocket", GRIP_POINT + SUPPORT_OFFSET, lifted(basis_from(support_back, down), arm_l), hand_l, "LeftHand")
	var right_socket: Node3D = model.get_node("GripSocket")
	var support_socket: Node3D = model.get_node("SupportSocket")
	print("grip  box ", grip_box.get_center(), " size ", grip_box.size)
	print("right fist box ", right_socket.transform * glove_box(hand_r))
	print("support fist box ", support_socket.transform * glove_box(hand_l))
	print("right hand-only (pistol space) ", fist_box(hand_r, right_socket.transform))
	print("grip                              ", grip_box)
	print("right fingers at grip height      ", band_box(hand_r, right_socket.transform, -0.03, 0.0))

	# --- the muzzle: the far end of the slide, for the flash ---------------
	var half := maxf(maxf(slide_box.size.x, slide_box.size.y), slide_box.size.z) * 0.5
	var marker := Marker3D.new()
	marker.name = "MuzzleTip"
	marker.position = slide_box.get_center() + bore * half
	model.add_child(marker)
	marker.owner = scene
	print("muzzle ", marker.position)
	# Keep the established hand sockets; replace only the owner's weapon rig.
	model.remove_child(pistol)
	pistol.free()
	pistol = preload("res://tools/stylized_pistol_rig.gd").new().build()
	model.add_child(pistol)
	marker.position = (Vector3(0,0.485,0.48)-Vector3(0,0.21,-0.30))*0.22
	pistol.scene_file_path = ""
	Common.own_children(pistol, pistol)
	var standalone := PackedScene.new()
	assert(standalone.pack(pistol) == OK)
	assert(ResourceSaver.save(standalone, OUT + "stylized_pistol_rig.tscn") == OK)
	Common.own_children(scene, scene)

	var packed := PackedScene.new()
	var err := packed.pack(scene)
	if err == OK:
		err = ResourceSaver.save(packed, OUT + "pistol_viewmodel.tscn")
	print("pistol_viewmodel.tscn saved, err=", err)
	_dump(scene, "")
	scene.free()
	if err == OK:
		var again: Node = (load(OUT + "pistol_viewmodel.tscn") as PackedScene).instantiate()
		print("--- reloaded from disk ---")
		_dump(again, "")
		again.free()

# ------------------------------------------------------------------------
# A part's box in the pistol's own space. The parts are flat children of the
# pack's root with no rotation, so their mesh boxes only need their position.
func part_box(needle: String) -> AABB:
	for mi in pistol.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if String(inst.name).to_lower().contains(needle):
			return inst.transform * inst.mesh.get_aabb()
	push_error("pistol has no part matching '" + needle + "'")
	return AABB()

# The glove's own box in handle space: surface 0, without the grown sleeve.
func glove_box(mesh: Mesh) -> AABB:
	var arrays := _unindexed((mesh as ArrayMesh).surface_get_arrays(0))
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return AABB()
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	return box

# The closed hand alone: surface 0 vertices nearer the grip than the wrist stub,
# each moved by "to_space" and boxed. Used to check the fist sits on the grip.
func fist_box(mesh: Mesh, to_space: Transform3D) -> AABB:
	var arrays := _unindexed((mesh as ArrayMesh).surface_get_arrays(0))
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var box := AABB()
	var first := true
	for v in verts:
		if v.z > 0.06:
			continue
		var p: Vector3 = to_space * v
		if first:
			box = AABB(p, Vector3.ZERO)
			first = false
		else:
			box = box.expand(p)
	return box

# Glove vertices inside a band of the pistol's own Y, boxed: the fist where it
# meets a given height on the grip.
func band_box(mesh: Mesh, to_space: Transform3D, y_lo: float, y_hi: float) -> AABB:
	var arrays := _unindexed((mesh as ArrayMesh).surface_get_arrays(0))
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var box := AABB()
	var first := true
	for v in verts:
		var p: Vector3 = to_space * v
		if p.y < y_lo or p.y > y_hi:
			continue
		if first:
			box = AABB(p, Vector3.ZERO)
			first = false
		else:
			box = box.expand(p)
	return box

func longest_axis(size: Vector3) -> Vector3:
	if size.x >= size.y and size.x >= size.z:
		return Vector3.RIGHT
	if size.y >= size.z:
		return Vector3.UP
	return Vector3.FORWARD

# the +X/+Y/+Z axis that "v" leans on most, pointing the same way
func principal_axis(v: Vector3) -> Vector3:
	if absf(v.x) >= absf(v.y) and absf(v.x) >= absf(v.z):
		return Vector3(signf(v.x), 0.0, 0.0)
	if absf(v.y) >= absf(v.z):
		return Vector3(0.0, signf(v.y), 0.0)
	return Vector3(0.0, 0.0, signf(v.z))

# a right-handed basis with the given +Y and +Z axes (+X is their cross product)
func basis_from(y_axis: Vector3, z_axis: Vector3) -> Basis:
	return Basis(y_axis.normalized().cross(z_axis.normalized()), y_axis.normalized(), z_axis.normalized())

# The knife hand's forearm is only about 30 deg off the handle it grips (it was
# sculpted for a knife), so a fist wrapped round a pistol grip hangs its wrist
# straight down. Rotating the fist about the axis perpendicular to both the grip
# and the glove's own forearm swings the wrist up without changing how the
# fingers wrap the grip, at the price of tipping the grip in the fist; the sign
# is chosen so that it always lifts.
func lifted(basis: Basis, arm: Vector3) -> Basis:
	var axis := GRIP_AXIS.cross((basis * arm).normalized()).normalized()
	var out := Basis(axis, deg_to_rad(WRIST_LIFT)) * basis
	if (out * arm).y < (basis * arm).y:
		out = Basis(axis, deg_to_rad(-WRIST_LIFT)) * basis
	return out

# the rotation taking "from_a" to "to_a", with "from_b" following "to_b"
func rotation_to(from_a: Vector3, to_a: Vector3, from_b: Vector3, to_b: Vector3) -> Basis:
	var fa := from_a.normalized()
	var fb := (from_b - fa * from_b.dot(fa)).normalized()
	var ta := to_a.normalized()
	var tb := (to_b - ta * to_b.dot(ta)).normalized()
	return Basis(tb.cross(ta), tb, ta) * Basis(fb.cross(fa), fb, fa).inverse()

func socket(parent: Node3D, root_node: Node, sock_name: String, pos: Vector3, basis: Basis, mesh: Mesh, mesh_name: String) -> void:
	var s := Node3D.new()
	s.name = sock_name
	s.transform = Transform3D(basis, pos)
	parent.add_child(s)
	s.owner = root_node
	var h := MeshInstance3D.new()
	h.name = mesh_name
	h.mesh = mesh
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(h)
	h.owner = root_node

func _dump(node: Node, indent: String) -> void:
	var extra := ""
	if node is Node3D:
		extra = " pos " + str((node as Node3D).position)
	if node is MeshInstance3D:
		extra += " mesh " + str((node as MeshInstance3D).mesh.resource_name) + " surfaces " + str((node as MeshInstance3D).mesh.get_surface_count())
	print(indent, node.name, " <", node.get_class(), ">", extra)
	for child in node.get_children():
		_dump(child, indent + "  ")
