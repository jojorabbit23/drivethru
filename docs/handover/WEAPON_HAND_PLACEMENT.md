# Knife and shotgun hand placement — 26 October 2026

The survival knife's shared right shoulder is moved towards the screen-right
edge, with a less downward elbow pole. Its hand socket, blade, slash/stab paths,
damage and attack timings remain unchanged. The adjustment rotates the forearm's
approach instead of moving the whole knife sideways or letting the wrist drift.
Other weapon fits retain the default shoulder location.

Owner follow-up: the survival knife grip rolls 100 degrees in the reverse
direction (-100 degrees) about its own blade axis at the hand bone. A rigid presentation
transform carries blade and fingers together, retaining the wrist location and
blade direction without deforming the authored skin. The alternate dagger is
explicitly excluded. `KNIFE_WRIST_ROLL` in knife_weapon.gd controls this turn;
no generated mesh or fit needs rebuilding for this rigid roll.

Both shotguns now use explicitly placed grip frames for both hands, solved at
the runtime 1.25x rig size. The sawn-off rear hand sits higher and rolls slightly
round its stock; the pump rear hand is fitted against the narrow grip rather than
the older oversized glove. Both support palms sit beneath their fore-ends.

The existing shell-loading hand targets were authored for a different grip.
`loading_l` preserves their prior fit; weapon presentation code supplies
`loading_weight` to smoothly blend between the corrected support fit and the
loading fit. This is visual only: shell counts, sound events, weapon actions,
damage, purchases and base animation timing are unchanged.

## Reproduce the fit

Export with `tools/fps_arms_fit_export.gd -- <directory>` and
`tools/fps_arms_frames_export.gd -- <directory>`, then run
`python tools/fps_arms_fit.py <directory>` (NumPy/SciPy required).
The GRIPS table contains the four shotgun grip constraints. Copy only the
corresponding solved entries into `FITS`; do not replace handgun fits with ICP
results. Old hand nodes remain hidden IK targets. No generated model was edited.

## Checks

`fps_arms_test.gd` checks screen-right knife forearm entry, and follows both
shotguns through complete reloads as well as recoil/attack/holster transitions.
`capture_fps_arms.gd` shows idle/action/reload for knife and both shotguns.
`capture_fps_arms_close.gd` now converts Vulkan readbacks to RGBA8 before building
contact sheets (previously produced black sheets); its near clip and framing
allow both hands to be inspected. `capture_hand_reload_fit.gd` captures the two
sawn-off insertion phases and recovery, plus the pump's shell-loading phases.

Previews: `fps_arms_knife.png`, `fps_arms_crop_duster.png`, `fps_arms_pump.png`,
the corresponding `fps_arms_close_*.png`, and `hand_reload_fit.png`, all in
`docs/previews/`.

Verified: Godot 4.3 import, explicit script check-only, Python compile,
validator and all 43 test suites passed. Native Vulkan mobile
first-person and external close-ups of all three weapons, shell insertion
contact sheet, kitchen, serving room, pistol, knife, inventory and pump
captures were rendered and visually inspected.
