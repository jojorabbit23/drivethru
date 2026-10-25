# Handgun fits for weapons/fps_arms/fps_arms.gd, taken from how the Pistol 43
# rig's own hands hold its own Glock (hand-shape ICP alone is ambiguous for a
# pistol grip and can turn the fingers backwards). In the source animation we
# read each hand relative to the Glock (frame at its magazine/grip, +Z barrel,
# +Y up: the same axes as our pistol model), scale by our pistol's size and
# re-express it relative to our pistol's old hand nodes.
#   godot --headless --path . --script res://tools/fps_arms_gun_fit.gd
# Prints the "pistol" and "desert_eagle" FITS entries (r/l offsets, rig scale):
# each handgun model is fitted from its own grip, plus an owner-requested nudge.
#
# The rig only shoots one-handed, so the support (left) hand is the right
# hand's grip mirrored across the gun's centre plane (the rig's arms mirror
# each other), nudged left/down/forward so it wraps over the right fingers;
# its fingers keep the curled pose from Inspect (see RIGS in fps_arms.gd).
extends SceneTree
const SOURCE := "res://weapons/fps_arms/source/pistol43_hands.glb"
const POSE := ["Hands|Shot", 0.0]
# support hand: shift (our model frame: +X is the gun's left side, +Z forward)
# and roll under the gun about the barrel axis through the grip (degrees)
var support_shift := Vector3(0.025, -0.04, 0.0)
var support_roll := 30.0
# hand scale: the Glock-to-our-pistol size ratio makes the hand fill the lower
# right of the screen; the stylized pistol is chunky, so the hand grows less
var hand_scale := 1.3
const HANDS := {"r": "r_wrist", "l": "l_wrist"}
# fit name: [viewmodel, grip node, nudge of the HAND in the gun's model frame
# (+X the gun's left, +Y up, +Z forward; moving the hand one way moves the gun
# the other way in the hand)]
const VIEWMODELS := {
	# owner: "move the gun slightly towards the thumb, it's a bit too deep in his hand"
	# (both use the stylized pistol's grip as the base: the owner approved that
	# placement on the starter pistol; the hand nodes sit identically in both)
	"pistol": ["res://weapons/pistol/pistol_viewmodel.tscn", "Model/StylizedPistol/pistol_magazine", Vector3(-0.006, 0.0, 0.0)],
	# owner: "the Desert Eagle needs to go up and forward slightly"
	"desert_eagle": ["res://weapons/pistol/pistol_viewmodel.tscn", "Model/StylizedPistol/pistol_magazine", Vector3(0.0, -0.008, -0.012)],
}

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() >= 4:
		support_shift = Vector3(float(a[0]), float(a[1]), float(a[2]))
		support_roll = float(a[3])
	if a.size() >= 5:
		hand_scale = float(a[4])
	run.call_deferred()

func bone_xf(sk: Skeleton3D, prefix: String) -> Transform3D:
	for b in sk.get_bone_count():
		if sk.get_bone_name(b).begins_with(prefix):
			var t: Transform3D = sk.global_transform * sk.get_bone_global_pose(b)
			return Transform3D(t.basis.orthonormalized(), t.origin)
	push_error("no bone " + prefix)
	return Transform3D()

func euler_deg(b: Basis) -> Vector3:
	return b.get_euler() * 180.0 / PI   # YXZ, matching Basis.from_euler in fps_arms.gd

func run() -> void:
	var src: Node3D = (load(SOURCE) as PackedScene).instantiate()
	root.add_child(src)
	var sk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play(POSE[0])
	ap.seek(float(POSE[1]), true)
	ap.pause()
	await process_frame
	var body := bone_xf(sk, "Wpn_body")
	var mag := bone_xf(sk, "Magazine_0")
	var glock := Transform3D(body.basis, mag.origin)          # gun axes, origin in the grip
	var right0 := glock.affine_inverse() * bone_xf(sk, HANDS["r"])
	right0.origin *= hand_scale                                # the hand (and wrist offset) at its game size
	var mirror := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	var left0 := Transform3D(mirror * right0.basis * mirror, mirror * right0.origin)
	left0 = Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(support_roll)), Vector3.ZERO) * left0
	left0.origin += support_shift
	for fit_name in VIEWMODELS:
		var spec: Array = VIEWMODELS[fit_name]
		var pistol: Node3D = (load(spec[0]) as PackedScene).instantiate()
		root.add_child(pistol)
		await process_frame
		var model: Node3D = pistol.get_node("Model")
		var our_grip: Vector3 = model.to_local(pistol.get_node(spec[1]).global_position)
		var nudge: Vector3 = spec[2]
		var refs := {"r": pistol.get_node("Model/GripSocket/RightHand"), "l": pistol.get_node("Model/SupportSocket/LeftHand")}
		var hands := {"r": right0, "l": left0}
		var parts := []
		for side in ["r", "l"]:
			var hand_in_model := Transform3D(Basis.IDENTITY, our_grip + nudge) * (hands[side] as Transform3D)
			var ref: Node3D = refs[side]
			var ref_in_model := model.global_transform.affine_inverse() * ref.global_transform
			var o: Transform3D = Transform3D(ref_in_model.basis.orthonormalized(), ref_in_model.origin).affine_inverse() * hand_in_model
			var e := euler_deg(o.basis)
			parts.append('"%s": [Vector3(%.4f, %.4f, %.4f), Vector3(%.1f, %.1f, %.1f)]' % [side, o.origin.x, o.origin.y, o.origin.z, e.x, e.y, e.z])
		print('"%s": {"rig": "pistol43", %s, "scale": %.2f}' % [fit_name, ", ".join(parts), hand_scale])
		pistol.queue_free()
	quit()
