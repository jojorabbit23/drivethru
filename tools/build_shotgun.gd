# Rebuild the new pump shotgun, preserving its node paths and Survivor skin.
# Native PSX pump gloves are fitted independently around the two handles;
# cuffs and sleeves use the same Cleatimus HD materials as the other weapons.
# Generated: weapons/shotgun/shotgun_hand_[lr].res and shotgun_model.tscn.
extends SceneTree

const Palette = preload("res://core/palette.gd")
const OUT := "res://weapons/shotgun/"
const ARMS := "res://addons/psx_firearms/models/fp_pump_shotgun_model.glb"
const HAND_MATERIAL := "res://weapons/knife/cleatimus_arms_material.tres"
const SKIN := "res://weapons/shotgun/source/Shotgun_Survivor_Skin.glb"
const SLEEVE_R0 := 0.045       # new sleeve radius at the cuff ...
const SLEEVE_R1 := 0.058       # ... and at the elbow
const SLEEVE_LEN := 0.62
const SLEEVE_UV := Vector2(0.0, 0.2)   # the sleeve fabric on the arms atlas

# Hand sockets on the gun: position, and rotation in degrees (applied Y, X, Z).
# The right hand's thumb runs up the pistol grip; the left hand's along the pump.
const GRIP_SOCKET := [Vector3.ZERO, Vector3.ZERO, 0.0]   # pos, rot (x, y, z), roll about the handle
const PUMP_SOCKET := [Vector3.ZERO, Vector3.ZERO, 0.0]

var metal := StandardMaterial3D.new()
var dark := StandardMaterial3D.new()
var wood := StandardMaterial3D.new()
var steel := StandardMaterial3D.new()

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var hands := build_hands()
	build_model(hands[0], hands[1])
	for i in 3:await process_frame
	quit()

# ------------------------------------------------------------- hands ----
func build_hands() -> Array:
	var arms: Node3D = (load(ARMS) as PackedScene).instantiate()
	root.add_child(arms)
	var anim: AnimationPlayer = arms.get_node("AnimationPlayer")
	anim.play("idle",0.0)
	anim.seek(0.0,true)
	var held: Node3D = arms.find_child("fp_pump_shotgun_held",true,false)
	var out: Array = []
	var turn := Transform3D(Basis(Vector3.UP,PI),Vector3.ZERO)
	for left in [false,true]:
		var source: MeshInstance3D = arms.find_child("fp_pump_shotgun_hand_l" if left else "fp_pump_shotgun_hand_r",true,false)
		var transform: Transform3D = turn * held.global_transform.affine_inverse() * source.global_transform
		# Native hands are rigid meshes, so their actual gripping pose is preserved.
		# New left vertices are in PumpSocket space; right vertices in GripSocket space.
		var offset: Vector3 = Vector3(0,0,0.455) if left else Vector3(0,-0.035,0.055)
		var a: Array = _unindexed(source.mesh.surface_get_arrays(0))
		var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var tags := PackedVector2Array()
		tags.resize(vertices.size())
		var grip := Transform3D.IDENTITY if left else Transform3D(Basis(Vector3.RIGHT,deg_to_rad(-20)),Vector3(0,-0.04,0.035))
		var half: Vector3 = Vector3(0.029,0.025,0.085) if left else Vector3(0.018,0.055,0.025)
		var swivel := Basis(Vector3.BACK,deg_to_rad(-35)) if left else Basis(Vector3.UP,deg_to_rad(-35))
		var posed: Transform3D = grip * Transform3D(swivel,Vector3.ZERO) * grip.affine_inverse()
		var moved: int = 0
		for i in vertices.size():
			vertices[i] = posed * (transform * vertices[i] + offset)
			normals[i] = (posed.basis * transform.basis * normals[i]).normalized()
			tags[i] = Vector2(2,0) # same fully gloved teal material as the other weapons
			var local: Vector3 = grip.affine_inverse() * vertices[i]
			var radial := Vector2(local.x,local.y if left else local.z)
			var radii := Vector2(half.x+0.0015,(half.y if left else half.z)+0.0015)
			var axial: float = local.z if left else local.y
			var extent: float = half.z if left else half.y
			var metric: float = maxf(absf(radial.x)/radii.x,absf(radial.y)/radii.y)
			if absf(axial)<extent+0.002 and metric>0.01 and metric<1.0:
				radial/=metric
				if left:local=Vector3(radial.x,radial.y,local.z)
				else:local=Vector3(radial.x,local.y,radial.y)
				vertices[i]=grip*local
				moved+=1
		a[Mesh.ARRAY_VERTEX]=vertices
		a[Mesh.ARRAY_NORMAL]=normals
		a[Mesh.ARRAY_TEX_UV2]=tags
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
		mesh.surface_set_material(0,load(HAND_MATERIAL))
		# Each sleeve exits toward its own lower screen corner, away from the stock.
		var wrist: Vector3 = transform * (Vector3(-0.03129,0.02742,0.01415) if left else Vector3(0.07736,0.009853,0.046568)) + offset
		wrist=posed*wrist
		var elbow := Vector3(-0.36,-0.34,0.48) if left else Vector3(0.35,-0.42,0.32)
		var direction: Vector3 = (elbow-wrist).normalized()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_sleeve(wrist-direction*0.012,direction,a,0.045,0.033,0.043,1))
		mesh.surface_set_material(1,load(HAND_MATERIAL))
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_sleeve(wrist+direction*0.025,direction,a,SLEEVE_LEN,0.042,0.064,0))
		mesh.surface_set_material(2,load(HAND_MATERIAL))
		var path: String = OUT+("shotgun_hand_l.res" if left else "shotgun_hand_r.res")
		ResourceSaver.save(mesh,path)
		mesh.take_over_path(path)
		out.append(mesh)
		print("Pump glove ","left" if left else "right",": ",vertices.size()," vertices, ",moved," fitted clear of the handle")
	arms.free()
	return out

# An 8-sided sleeve: SLEEVE_R0 at the cuff widening to SLEEVE_R1 at the elbow,
# SLEEVE_LEN long (well off the bottom of the screen). Its UVs sit in the
# sleeve's fabric on the arms atlas; its vertex colour is the cuff's average.
func _sleeve(start: Vector3, dir: Vector3, glove: Array, length: float=SLEEVE_LEN, radius0: float=SLEEVE_R0, radius1: float=SLEEVE_R1, region: int=0) -> Array:
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = dir.cross(Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	var col := Color.WHITE
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	const SEG := 8
	var rings := [[0.0, radius0], [length * 0.5, (radius0 + radius1) * 0.5], [length, radius1]]
	for r in rings.size() - 1:
		var a0: Array = rings[r]
		var a1: Array = rings[r + 1]
		for s in SEG:
			var quad := []
			for corner in [[a0, s], [a1, s], [a1, s + 1], [a0, s + 1]]:
				var ring: Array = corner[0]
				var ang: float = TAU * float(corner[1]) / SEG + PI / SEG
				var radial: Vector3 = side * cos(ang) + up * sin(ang)
				quad.append([start + dir * float(ring[0]) + radial * float(ring[1]), radial, Vector2(SLEEVE_UV.x + 0.08 * float(corner[1]) / SEG, SLEEVE_UV.y + 0.25 * float(ring[0]) / length)])
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
	var tags := PackedVector2Array()
	tags.resize(verts.size())
	tags.fill(Vector2(region,0))
	arr[Mesh.ARRAY_TEX_UV2] = tags
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
	apply_skin(gun)
	var ps := PackedScene.new()
	ps.pack(gun)
	var err := ResourceSaver.save(ps, OUT + "shotgun_model.tscn")
	print("saved shotgun_model.tscn err=%d" % err)
	gun.free()

# The owner's "survivor" skin (weapons/shotgun/source/Shotgun_Survivor_Skin.glb):
# the same parts, re-UV'd and textured. Each part here takes the skin's mesh,
# material and transform by name; textures stay nearest-filtered (pixel look).
func apply_skin(gun: Node3D) -> void:
	if not ResourceLoader.exists(SKIN):
		print("no skin at %s: flat colours" % SKIN)
		return
	var skin: Node = (load(SKIN) as PackedScene).instantiate()
	var n := 0
	for src: Node in skin.find_children("*", "MeshInstance3D", true, false):
		var mi := src as MeshInstance3D
		var dst := gun.find_child(mi.name, true, false) as MeshInstance3D
		if dst == null:
			continue
		# own copies (saved into the scene); textures stay the skin's PNGs
		var mesh := mi.mesh.duplicate() as ArrayMesh
		for si in mesh.get_surface_count():
			var src_mat := mesh.surface_get_material(si) as BaseMaterial3D
			if src_mat:
				var mat := ShaderMaterial.new()
				mat.shader=load("res://weapons/shotgun/viewmodel.gdshader")
				mat.set_shader_parameter("colour",src_mat.albedo_color)
				mat.set_shader_parameter("albedo_tex",src_mat.albedo_texture)
				mat.set_shader_parameter("textured",src_mat.albedo_texture!=null)
				mesh.surface_set_material(si, mat)
		dst.mesh = mesh
		dst.material_override = null
		dst.transform = mi.transform
		n += 1
	skin.free()
	print("skin applied to %d parts" % n)

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
