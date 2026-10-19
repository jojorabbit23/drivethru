# Builds the pump shotgun's first-person model:
#
#   godot --headless --path . --script res://tools/build_shotgun.gd
#
# Writes res://weapons/shotgun/:
#   shotgun_hand_r.res / shotgun_hand_l.res  Cleatimus's sculpted glove (the
#       knife hand, already fitted round a handle) moved into handle space, and
#       a mirrored copy for the left hand on the pump
#   shotgun_model.tscn  the gun: blocky boxes and 8-sided tubes in palette
#       colours, with a sliding Pump, the hands on GripSocket / PumpSocket,
#       and Muzzle / LoadPort markers for shotgun_weapon.gd
# Handle space is the knife's: the handle runs along +Z from the origin and the
# thumb points down -Z (where the knife's blade went).
extends SceneTree

const Palette = preload("res://core/palette.gd")
const OUT := "res://weapons/shotgun/"
const KNIFE_VM := "res://weapons/knife/knife_viewmodel.tscn"
const SLEEVE_FROM := 0.14     # handle-space z where the sleeve starts stretching
const SLEEVE_STRETCH := 1.6

# Hand sockets on the gun: position, and rotation in degrees (applied Y, X, Z).
# The right hand's thumb runs up the pistol grip; the left hand's along the pump.
const GRIP_SOCKET := [Vector3(0.0, 0.01, 0.015), Vector3(70.0, 0.0, 0.0), 0.0]   # pos, rot (x, y, z), roll about the handle
const PUMP_SOCKET := [Vector3(0.0, 0.0, -0.07), Vector3(0.0, -8.0, 0.0), 62.0]

var metal := StandardMaterial3D.new()
var dark := StandardMaterial3D.new()
var wood := StandardMaterial3D.new()
var steel := StandardMaterial3D.new()

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var hands := build_hands()
	build_model(hands[0], hands[1])
	quit()

# ------------------------------------------------------------- hands ----
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
	for mirror in [false, true]:
		var a := src.surface_get_arrays(0)
		var v: PackedVector3Array = PackedVector3Array(a[Mesh.ARRAY_VERTEX])
		var n: PackedVector3Array = PackedVector3Array(a[Mesh.ARRAY_NORMAL])
		# the knife hand's sleeve is a short stub: stretch it along its own
		# direction so the forearm runs off the bottom of the screen
		var arm_dir := Vector3.ZERO
		for i in v.size():
			var q: Vector3 = inv * v[i]
			if q.z > 0.2:
				arm_dir += q
		arm_dir = arm_dir.normalized()
		for i in v.size():
			v[i] = inv * v[i]
			if v[i].z > SLEEVE_FROM:
				v[i] += arm_dir * (v[i].z - SLEEVE_FROM) * SLEEVE_STRETCH
			n[i] = (inv.basis * n[i]).normalized()
			if mirror:
				v[i].x = -v[i].x
				n[i].x = -n[i].x
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_BONES] = null
		a[Mesh.ARRAY_WEIGHTS] = null
		a[Mesh.ARRAY_TANGENT] = null
		if mirror:
			# mirroring turns the triangles inside out: swap their winding
			var idx = a[Mesh.ARRAY_INDEX]
			if idx != null:
				var ix := PackedInt32Array(idx)
				for t in range(0, ix.size(), 3):
					var k := ix[t + 1]
					ix[t + 1] = ix[t + 2]
					ix[t + 2] = k
				a[Mesh.ARRAY_INDEX] = ix
			else:
				for arr_i in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
					if a[arr_i] == null:
						continue
					var arr = a[arr_i]
					for t in range(0, arr.size(), 3):
						var k = arr[t + 1]
						arr[t + 1] = arr[t + 2]
						arr[t + 2] = k
					a[arr_i] = arr
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		m.surface_set_material(0, src.surface_get_material(0))
		var path := OUT + ("shotgun_hand_l.res" if mirror else "shotgun_hand_r.res")
		ResourceSaver.save(m, path)
		m.take_over_path(path)
		print("hand %s: %d vertices, aabb %s" % ["left" if mirror else "right", v.size(), m.get_aabb()])
		out.append(m)
	vm.queue_free()
	return out

# ------------------------------------------------------------- model ----
func build_model(hand_r: Mesh, hand_l: Mesh) -> void:
	for pair in [[metal, Palette.WET_CHARCOAL, 0.45], [dark, Palette.MIDNIGHT_TYNE, 0.6], [wood, Palette.BURNT_ORANGE.darkened(0.35), 0.8], [steel, Palette.CONCRETE_GREY, 0.35]]:
		var m: StandardMaterial3D = pair[0]
		m.albedo_color = pair[1]
		m.roughness = pair[2]
		m.metallic = 0.4 if pair[0] != wood else 0.0
	var gun := Node3D.new()
	gun.name = "ShotgunModel"
	# receiver, barrel, magazine tube
	box(gun, "Receiver", Vector3(0.052, 0.074, 0.23), Vector3(0, 0.05, -0.075), metal)
	box(gun, "ReceiverTop", Vector3(0.04, 0.01, 0.21), Vector3(0, 0.091, -0.075), steel)
	box(gun, "EjectionPort", Vector3(0.004, 0.026, 0.07), Vector3(0.027, 0.062, -0.07), dark)
	box(gun, "LoadingPort", Vector3(0.034, 0.004, 0.08), Vector3(0, 0.012, -0.085), dark)
	tube(gun, "Barrel", 0.0155, 0.52, Vector3(0, 0.072, -0.45), metal)
	tube(gun, "Muzzle", 0.018, 0.03, Vector3(0, 0.072, -0.70), steel)
	tube(gun, "MagTube", 0.013, 0.46, Vector3(0, 0.034, -0.41), metal)
	tube(gun, "MagCap", 0.016, 0.03, Vector3(0, 0.034, -0.64), steel)
	box(gun, "BarrelBand", Vector3(0.036, 0.06, 0.02), Vector3(0, 0.053, -0.6), steel)
	box(gun, "Bead", Vector3(0.007, 0.012, 0.012), Vector3(0, 0.093, -0.69), steel)
	# trigger group, pistol grip and stock
	box(gun, "TriggerGuard", Vector3(0.012, 0.008, 0.07), Vector3(0, -0.012, -0.03), metal)
	box(gun, "TriggerGuardFront", Vector3(0.012, 0.03, 0.008), Vector3(0, 0.0, -0.064), metal)
	var trig := box(gun, "Trigger", Vector3(0.006, 0.026, 0.008), Vector3(0, 0.002, -0.032), steel)
	trig.rotation_degrees.x = 15.0
	var g := box(gun, "Grip", Vector3(0.036, 0.11, 0.05), Vector3(0, -0.04, 0.035), wood)
	g.rotation_degrees.x = -20.0   # top forward, heel back
	var st := box(gun, "Stock", Vector3(0.042, 0.072, 0.30), Vector3(0, 0.0, 0.21), wood)
	st.rotation_degrees.x = 7.0
	box(gun, "ButtPad", Vector3(0.046, 0.09, 0.02), Vector3(0, -0.012, 0.36), dark)
	# the pump slides back along the tube; the left hand rides on it
	var pump := Node3D.new()
	pump.name = "Pump"
	pump.position = Vector3(0, 0.034, -0.37)
	gun.add_child(pump)
	pump.owner = gun
	box(pump, "Fore", Vector3(0.058, 0.05, 0.17), Vector3.ZERO, wood, gun)
	for k in 5:
		box(pump, "Rib%d" % k, Vector3(0.06, 0.006, 0.008), Vector3(0, -0.026, -0.06 + k * 0.03), dark, gun)
	socket(gun, pump, "PumpSocket", PUMP_SOCKET, hand_l, "LeftHand")
	socket(gun, gun, "GripSocket", GRIP_SOCKET, hand_r, "RightHand")
	marker(gun, "MuzzleTip", Vector3(0, 0.072, -0.72))
	marker(gun, "LoadPort", Vector3(0, 0.0, -0.085))
	var ps := PackedScene.new()
	ps.pack(gun)
	var err := ResourceSaver.save(ps, OUT + "shotgun_model.tscn")
	print("saved shotgun_model.tscn err=%d" % err)

func box(parent: Node3D, n: String, size: Vector3, pos: Vector3, mat: Material, own: Node = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = n
	var b := BoxMesh.new()
	b.size = size
	b.material = mat
	m.mesh = b
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.owner = own if own else parent
	return m

func tube(parent: Node3D, n: String, r: float, length: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = n
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 8
	c.rings = 1
	c.material = mat
	m.mesh = c
	m.position = pos
	m.rotation_degrees.x = 90.0
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.owner = parent
	return m

func socket(gun: Node3D, parent: Node3D, n: String, spec: Array, hand: Mesh, hand_name: String) -> void:
	var s := Node3D.new()
	s.name = n
	s.position = spec[0]
	s.rotation_degrees = spec[1]
	parent.add_child(s)
	s.owner = gun
	var h := MeshInstance3D.new()
	h.name = hand_name
	h.mesh = hand
	h.rotation.z = deg_to_rad(spec[2])
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(h)
	h.owner = gun

func marker(gun: Node3D, n: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = n
	m.position = pos
	gun.add_child(m)
	m.owner = gun
