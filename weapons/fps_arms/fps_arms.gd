# Shared first-person arms for every weapon, from two recoloured rigs by
# Vlasov Daniil (CC BY 4.0; see CREDITS.md), gun meshes removed: the AKS-74U
# hands (knife, dagger, shotguns) and the Pistol 43 hands (handguns: posed
# for a two-handed pistol grip).
#
# Each weapon keeps all of its own animation. It hands us two reference nodes,
# where its old right and left hands were, and every frame these arms reach
# for them with an analytic two-bone IK (shoulder fixed, elbow on a pole,
# hand matching the reference's orientation, forearm twist spread across the
# four twist bones). The old hand meshes are hidden.
#
#   FpsArms.attach(pivot, right_ref, left_ref, "pump", [old meshes to hide])
#
# Fits (how each rig's hand sits relative to each reference) live in FITS below.
extends Node3D

const SHADER := preload("res://weapons/fps_arms/fps_arms.gdshader")
# Per rig: source, the animation frame that gives the finger pose, which meshes
# are arms (the rest are guns), bone name prefixes (%s = r/l) and the forearm
# twist bones with the share of the wrist's twist each one takes.
const RIGS := {
	"aks": {"source": "res://weapons/fps_arms/source/aks74u_hands.glb",
		"pose": "armature|Fire_single", "time": 0.0, "meshes": ["Object_9"],
		"upper": "upperarm_%s_0", "fore": "forearm_%s_0", "hand": "hand_%s_0",
		# chained one under the next: a quarter each adds up to the full twist
		"twists": [["forearm_twist_1_%s_", 0.25], ["forearm_twist_2_%s_", 0.25], ["forearm_twist_3_%s_", 0.25], ["forearm_twist_4_%s_", 0.25]]},
	"pistol43": {"source": "res://weapons/fps_arms/source/pistol43_hands.glb",
		"pose": "Hands|Shot", "time": 0.0, "meshes": ["Object_98", "Object_99"],
		# Shot is one-handed (left arm hangs loose): take the left fingers from the
		# Inspect frame where that hand holds the pistol, for the support grip
		"pose_l": ["Hands|Inspect", 2.65],
		# its camera looks along +X: turn it to Godot's -Z, and start the right
		# hand near our pistols' grip so the arms keep their authored shape
		"root": Transform3D(Basis(Vector3.UP, PI), Vector3(0.06, -0.10, -0.13)),
		"upper": "%s_upperarm", "fore": "%s_forearm", "hand": "%s_wrist",
		# siblings along the forearm: each takes the twist at its own position
		"twists": [["%s_sleeve_foretwist", 0.03], ["%s_arm_foretwist", 0.15], ["%s_arm_2_foretwist", 0.87], ["%s_watch_foretwist", 0.87]]},
}

# Per weapon: hand frame relative to the reference node (position m, rotation deg),
# elbow pole directions in camera space, whether the right hand closes into a fist,
# and an optional rig scale (long guns: the old hands were ~1.18x the AKS hands,
# and the bigger arm keeps the slid shoulder below the frame).
const FITS := {
	# long guns and blades: tools/fps_arms_fit.py (grip-frame start, then trimmed ICP onto each old hand)
	# handguns: tools/fps_arms_gun_fit.gd (the rig's own hand-on-Glock grip, scaled to our
	# pistol; support hand = that grip mirrored and wrapped over the right fingers;
	# per-gun nudges from the owner's playtest)
	"pistol": {"rig": "pistol43", "r": [Vector3(0.0527, -0.0118, 0.0409), Vector3(-52.7, 132.4, -82.1)],
		"l": [Vector3(-0.0479, -0.0585, 0.0453), Vector3(-49.6, -72.7, 5.8)], "scale": 1.30, "one_handed": true,
		"pole_r": Vector3(1.0, -1.4, 0.6), "pole_l": Vector3(-1.0, -1.4, 0.6), "fist": false},
	"desert_eagle": {"rig": "pistol43", "r": [Vector3(0.0573, -0.0118, 0.0558), Vector3(-52.7, 132.4, -82.1)],
		"l": [Vector3(-0.0505, -0.0734, 0.0492), Vector3(-49.6, -72.7, 5.8)], "scale": 1.30, "one_handed": true,
		"pole_r": Vector3(1.0, -1.4, 0.6), "pole_l": Vector3(-1.0, -1.4, 0.6), "fist": false},
	"pump": {"r": [Vector3(-0.0872, -0.0324, 0.0746), Vector3(-40.3, 12.3, -98.8)],
		"l": [Vector3(-0.0746, -0.0784, -0.0051), Vector3(66.5, 176.8, 71.4)],
		"pole_r": Vector3(1.0, -1.4, 0.6), "pole_l": Vector3(-0.6, -1.4, 0.2), "fist": false, "scale": 1.25},
	"crop_duster": {"r": [Vector3(0.1975, -0.0051, 0.0534), Vector3(-29.8, 161.9, -86.3)],
		"l": [Vector3(0.0273, -0.0088, 0.0731), Vector3(63.6, 41.4, 135.3)],
		"pole_r": Vector3(1.0, -1.4, 0.6), "pole_l": Vector3(-0.6, -1.4, 0.2), "fist": false, "scale": 1.25},
	"dagger": {"r": [Vector3(-0.0041, -0.0097, 0.0029), Vector3(-19.4, -96.1, -32.3)],
		"l": [Vector3(0.0321, 0.0087, -0.0025), Vector3(-29.6, 92.7, 31.7)],
		"pole_r": Vector3(1.0, -1.4, 0.6), "pole_l": Vector3(-1.0, -1.4, 0.6), "fist": true},
	"knife": {"r": [Vector3(0.0432, -0.0072, -0.0063), Vector3(21.0, -96.9, -48.0)],
		"l": [Vector3(0.0321, 0.0087, -0.0025), Vector3(-29.6, 92.7, 31.7)],
		"pole_r": Vector3(1.0, -1.4, 0.6), "pole_l": Vector3(-1.0, -1.4, 0.6), "fist": true},
}

var right_ref: Node3D
var left_ref: Node3D
var right_offset := Transform3D.IDENTITY
var left_offset := Transform3D.IDENTITY
var pole_r := Vector3(1, -1, 0.5)
var pole_l := Vector3(-1, -1, 0.5)
var fist := false
var rig := "aks"
var skeleton: Skeleton3D
var mesh: MeshInstance3D                # the main arms mesh (tests/fitting)
var meshes: Array[MeshInstance3D] = []
var _local: Array[Transform3D] = []     # captured local pose of every bone
var _global: Array[Transform3D] = []    # captured skeleton-space pose of every bone
var _arms := {}                         # "r"/"l" -> {upper, fore, hand, twists}
var reach_error := {"r": 0.0, "l": 0.0} # metres the hand fell short last frame (tests)
var shoulder_slide := {"r": 0.0, "l": 0.0} # metres the shoulder slid towards a far grip
var pivot: Node3D                       # the weapon's viewmodel: we show when it shows
# 0..1: how much the left hand follows its reference. Below 1 it eases back to
# the rig's own pose (Pistol 43: hanging out of view; it shoots one-handed and
# the pistol brings the left hand in only to change the magazine).
var left_weight := 1.0
const REACH_USE := 0.92                 # bend the elbow a little even at full reach
const HIDE_DROP := Vector3(0.05, -1.0, 0.3) # camera space: where a slid shoulder heads (below the frame)

static func fit_transform(spec: Array) -> Transform3D:
	var rot: Vector3 = spec[1]
	return Transform3D(Basis.from_euler(rot * PI / 180.0), spec[0])

# Build arms beside `pivot` (the weapon's moving viewmodel root), following the
# two reference nodes, and hide the weapon's old hand meshes. The arms hang
# from the camera, not the gun, so a reload roll doesn't swing a shoulder
# across the screen; the hands still follow every motion of the gun.
static func attach(pivot: Node3D, right: Node3D, left: Node3D, fit_name: String, hide: Array) -> Node3D:
	if OS.get_environment("FPS_ARMS_OFF") != "":   # old hands only, for comparisons
		return null
	var arms: Node3D = (load("res://weapons/fps_arms/fps_arms.gd") as GDScript).new()
	arms.name = "FpsArms"
	var fit: Dictionary = FITS[fit_name]
	arms.right_ref = right
	arms.left_ref = left
	arms.right_offset = fit_transform(fit["r"])
	arms.left_offset = fit_transform(fit["l"])
	arms.pole_r = fit["pole_r"]
	arms.pole_l = fit["pole_l"]
	arms.fist = fit["fist"]
	arms.rig = fit.get("rig", "aks")
	if fit.get("one_handed", false):
		arms.left_weight = 0.0   # the weapon raises it (e.g. for a reload)
	arms.pivot = pivot
	pivot.get_parent().add_child(arms)   # the weapon node, in camera space
	arms.transform = Transform3D.IDENTITY.scaled(Vector3.ONE * float(fit.get("scale", 1.0)))
	arms.visible = pivot.visible
	if OS.get_environment("FPS_ARMS_SHOW_OLD") == "":   # set it to compare with the old hands
		for node in hide:
			_hide_mesh(node)
	return arms

# Keep only one shader region of an old mesh (arms_viewmodel.gdshader UV2.x
# region ids): the dagger is baked into its old hand mesh as region 4 (NATIVE:
# blade, guard and neck), so the dagger survives while its old hand goes.
static func keep_region(mi: MeshInstance3D, region: int) -> void:
	var src: Mesh = mi.mesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var a := src.surface_get_arrays(s)
		var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for i in (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
				idx.append(i)
		var kept := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var ok := true
			for k in 3:
				if int(floor(uv2[idx[t + k]].x + 0.5)) != region:
					ok = false
			if ok:
				kept.append_array([idx[t], idx[t + 1], idx[t + 2]])
		a[Mesh.ARRAY_INDEX] = kept
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(s, src.surface_get_material(s))
	mi.mesh = out
	mi.set_meta("replaced_by_fps_arms", true)
	mi.set_meta("fps_arms_kept_region", region)

# Hide an old hand/arm mesh without hiding anything parented under it.
static func _hide_mesh(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.get_child_count() > 0:
			mi.mesh = null
		else:
			mi.visible = false
		mi.set_meta("replaced_by_fps_arms", true)
	elif node is Node3D:
		(node as Node3D).visible = false
		node.set_meta("replaced_by_fps_arms", true)

func _ready() -> void:
	process_priority = 1000   # after the weapon scripts and AnimationPlayers
	var spec: Dictionary = RIGS[rig]
	var src: Node3D = (load(spec["source"]) as PackedScene).instantiate()
	src.name = "Rig"
	add_child(src)
	src.transform = spec.get("root", Transform3D.IDENTITY)
	skeleton = src.find_children("*", "Skeleton3D", true, false)[0]
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		if (spec["meshes"] as Array).has(String(mi.name)):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.material_override = _material(mi.mesh.surface_get_material(0) as BaseMaterial3D)
			meshes.append(mi)
		else:
			mi.queue_free()
	mesh = meshes[0]
	# capture the finger pose from one frame of the source animation, then drop the player
	var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play(spec["pose"])
	ap.seek(float(spec["time"]), true)
	ap.pause()
	for b in skeleton.get_bone_count():
		_local.append(skeleton.get_bone_pose(b))
	if spec.has("pose_l"):
		var left_hand := _bone(String(spec["hand"]) % "l")
		ap.play(spec["pose_l"][0])
		ap.seek(float(spec["pose_l"][1]), true)
		for b in skeleton.get_bone_count():
			var p := skeleton.get_bone_parent(b)
			while p >= 0 and p != left_hand:
				p = skeleton.get_bone_parent(p)
			if p == left_hand:
				_local[b] = skeleton.get_bone_pose(b)
	ap.get_parent().remove_child(ap)
	ap.free()
	for b in skeleton.get_bone_count():
		skeleton.set_bone_pose(b, _local[b])
	for b in skeleton.get_bone_count():
		var p := skeleton.get_bone_parent(b)
		_global.append(_local[b] if p < 0 else _global[p] * _local[b])
	for side in ["r", "l"]:
		var twists: Array = []
		for t in spec["twists"]:
			var b := _bone(String(t[0]) % side, false)
			if b >= 0:
				twists.append([b, float(t[1])])
		_arms[side] = {"upper": _bone(String(spec["upper"]) % side), "fore": _bone(String(spec["fore"]) % side),
			"hand": _bone(String(spec["hand"]) % side), "twists": twists}
	if fist:
		_make_fist()
	_solve()

func _bone(prefix: String, required := true) -> int:
	for b in skeleton.get_bone_count():
		if skeleton.get_bone_name(b).begins_with(prefix):
			return b
	if required:
		push_error("fps_arms: no bone " + prefix)
	return -1

func _material(src: BaseMaterial3D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	if src:
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		m.set_shader_parameter("normal_tex", src.normal_texture)
		m.set_shader_parameter("roughness_tex", src.roughness_texture)
		m.set_shader_parameter("use_normal", src.normal_texture != null)
	return m

# Knife: curl the trigger finger round the handle like the other three.
func _make_fist() -> void:
	for k in 3:
		var index := _bone("finger_2%d_r_" % (k + 1))
		var middle := _bone("finger_3%d_r_" % (k + 1))
		if index >= 0 and middle >= 0:
			_local[index].basis = Basis(_local[middle].basis.get_rotation_quaternion()).scaled(_local[index].basis.get_scale())
			skeleton.set_bone_pose_rotation(index, _local[middle].basis.get_rotation_quaternion())

func _process(_delta: float) -> void:
	if pivot and is_instance_valid(pivot):
		visible = pivot.visible
	if is_visible_in_tree():
		_solve()

func _solve() -> void:
	if skeleton == null:
		return
	var to_skel := skeleton.global_transform.affine_inverse()
	if right_ref and is_instance_valid(right_ref):
		_solve_arm("r", to_skel * (right_ref.global_transform * right_offset), pole_r)
	if left_ref and is_instance_valid(left_ref):
		if left_weight <= 0.001:
			_rest_arm("l")
		else:
			var goal: Transform3D = to_skel * (left_ref.global_transform * left_offset)
			var rest: Transform3D = _global[_arms["l"]["hand"]]
			rest = Transform3D(rest.basis.orthonormalized(), rest.origin)
			_solve_arm("l", rest.interpolate_with(goal, clampf(left_weight, 0.0, 1.0)), pole_l)

# The rig's own captured pose for one arm (no IK).
func _rest_arm(side: String) -> void:
	var arm: Dictionary = _arms[side]
	for b in [arm["upper"], arm["fore"], arm["hand"]]:
		skeleton.set_bone_pose_position(b, _local[b].origin)
		skeleton.set_bone_pose_rotation(b, _local[b].basis.get_rotation_quaternion())
	for t in arm["twists"]:
		skeleton.set_bone_pose_rotation(t[0], _local[t[0]].basis.get_rotation_quaternion())
	reach_error[side] = 0.0
	shoulder_slide[side] = 0.0

func _solve_arm(side: String, target: Transform3D, pole_camera: Vector3) -> void:
	var arm: Dictionary = _arms[side]
	var upper: int = arm["upper"]
	var fore: int = arm["fore"]
	var hand: int = arm["hand"]
	var parent_g: Transform3D = _global[skeleton.get_bone_parent(upper)]
	var shoulder: Vector3 = (parent_g * _local[upper]).origin
	var l1: float = (_global[upper].basis * _local[fore].origin).length()
	var l2: float = (_global[fore].basis * _local[hand].origin).length()
	var goal := target.origin
	var to_goal := goal - shoulder
	var dist := to_goal.length()
	# a long gun's fore-end is further than an arm. Move the shoulder to arm's
	# length from the grip, swinging it down below the screen as the overshoot
	# grows, so the arm reads as coming up from under the frame (no open sleeve
	# end in view). Continuous: a small overshoot just slides along the arm.
	var arm_len := (l1 + l2) * REACH_USE
	var over := dist - arm_len
	shoulder_slide[side] = maxf(0.0, over)
	if over > 0.0:
		var below := skeleton.global_transform.basis.inverse() * (global_transform.basis * HIDE_DROP)
		var anchor := shoulder.lerp(shoulder + below, smoothstep(0.0, 0.12, over))
		shoulder = goal + (anchor - goal).normalized() * arm_len
	skeleton.set_bone_pose_position(upper, parent_g.affine_inverse() * shoulder)
	to_goal = goal - shoulder
	dist = to_goal.length()
	var reach := (l1 + l2) * 0.999
	reach_error[side] = maxf(0.0, dist - reach)
	dist = clampf(dist, absf(l1 - l2) + 0.001, reach)
	var dir := to_goal.normalized()
	goal = shoulder + dir * dist
	# elbow: on the circle of the two-bone solution, towards the pole
	var pole := (skeleton.global_transform.basis.inverse() * (global_transform.basis * pole_camera)).normalized()
	var side_dir := (pole - dir * dir.dot(pole)).normalized()
	var a := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(0.0, l1 * l1 - a * a))
	var elbow := shoulder + dir * a + side_dir * h
	# rotate the captured bones the least amount that lines them up
	var parent_rot := parent_g.basis.get_rotation_quaternion()
	var upper_q0 := parent_rot * _local[upper].basis.get_rotation_quaternion()
	var upper_q := _aim(upper_q0, (elbow - shoulder).normalized())
	var fore_q0 := upper_q * _local[fore].basis.get_rotation_quaternion()
	var fore_q := _aim(fore_q0, (goal - elbow).normalized())
	var hand_q := target.basis.get_rotation_quaternion()
	# extra twist of the hand about the forearm (vs the captured pose), spread
	# over the twist bones so the wrist doesn't pinch
	var hand_local := fore_q.inverse() * hand_q
	var rel := hand_local * _local[hand].basis.get_rotation_quaternion().inverse()
	var twist := 2.0 * atan2(rel.y, rel.w)
	if twist > PI:
		twist -= TAU
	elif twist < -PI:
		twist += TAU
	skeleton.set_bone_pose_rotation(upper, parent_rot.inverse() * upper_q)
	skeleton.set_bone_pose_rotation(fore, upper_q.inverse() * fore_q)
	skeleton.set_bone_pose_rotation(hand, hand_local)
	for t in arm["twists"]:
		var tb: int = t[0]
		skeleton.set_bone_pose_rotation(tb, _local[tb].basis.get_rotation_quaternion() * Quaternion(Vector3.UP, twist * float(t[1])))

# q with its +Y axis turned onto `y` by the shortest arc.
static func _aim(q: Quaternion, y: Vector3) -> Quaternion:
	var current := q * Vector3.UP
	if current.dot(y) > 0.99999:
		return q
	return Quaternion(current, y) * q

# Where the hand bone actually is (skeleton -> global), for tests and captures.
func hand_global(side: String) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(_arms[side]["hand"])
