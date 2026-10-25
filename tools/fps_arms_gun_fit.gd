# Handgun fits for weapons/fps_arms/fps_arms.gd, taken from how the Pistol 43
# rig's own hands hold its own Glock (hand-shape ICP alone is ambiguous for a
# pistol grip and can turn the fingers backwards). In the source animation we
# read each hand relative to the Glock (frame at its magazine/grip, +Z barrel,
# +Y up: the same axes as our pistol model), scale by our pistol's size and
# re-express it relative to our pistol's old hand nodes.
#   godot --headless --path . --script res://tools/fps_arms_gun_fit.gd
# Prints the "pistol" FITS entry (r/l offsets and the rig scale).
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
	var pistol: Node3D = load("res://weapons/pistol/pistol_viewmodel.tscn").instantiate()
	root.add_child(pistol)
	var model: Node3D = pistol.get_node("Model")
	var our_grip: Vector3 = model.to_local(pistol.get_node("Model/StylizedPistol/pistol_magazine").global_position)
	var our_muzzle: Vector3 = model.to_local(pistol.get_node("Model/MuzzleTip").global_position)
	var refs := {"r": pistol.get_node("Model/GripSocket/RightHand"), "l": pistol.get_node("Model/SupportSocket/LeftHand")}
	var scale := 1.0
	var out := {}
	ap.play(POSE[0])
	ap.seek(float(POSE[1]), true)
	ap.pause()
	await process_frame
	var body := bone_xf(sk, "Wpn_body")
	var mag := bone_xf(sk, "Magazine_0")
	var barrel := bone_xf(sk, "Barrel")
	var glock := Transform3D(body.basis, mag.origin)          # gun axes, origin in the grip
	scale = our_grip.distance_to(our_muzzle) / mag.origin.distance_to(barrel.origin)
	var right := glock.affine_inverse() * bone_xf(sk, HANDS["r"])
	right.origin *= hand_scale                                 # the hand (and wrist offset) at its game size
	var mirror := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	var left := Transform3D(mirror * right.basis * mirror, mirror * right.origin)
	left = Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(support_roll)), Vector3.ZERO) * left
	left.origin += support_shift
	var hands := {"r": right, "l": left}
	for side in ["r", "l"]:
		var hand_in_model := Transform3D(Basis.IDENTITY, our_grip) * (hands[side] as Transform3D)
		var ref: Node3D = refs[side]
		var ref_in_model := model.global_transform.affine_inverse() * ref.global_transform
		out[side] = Transform3D(ref_in_model.basis.orthonormalized(), ref_in_model.origin).affine_inverse() * hand_in_model
		print("# %s: wrist %.3f m from the grip" % [side, (hands[side] as Transform3D).origin.length()])
	print("# our pistol / Glock size: %.2f" % scale)
	var parts := []
	for side in ["r", "l"]:
		var o: Transform3D = out[side]
		var e := euler_deg(o.basis)
		parts.append('"%s": [Vector3(%.4f, %.4f, %.4f), Vector3(%.1f, %.1f, %.1f)]' % [side, o.origin.x, o.origin.y, o.origin.z, e.x, e.y, e.z])
	print('"pistol": {"rig": "pistol43", %s, "scale": %.2f}' % [", ".join(parts), hand_scale])
	quit()
