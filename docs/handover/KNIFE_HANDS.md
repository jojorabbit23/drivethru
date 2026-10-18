# Task: put Cleatimus's hands on the knife

## Goal

Today the knife (`weapons/knife/`) floats in view with no arms. Add
first-person arms from **PSX FPS Arms Free** (heyheythere, CC BY 4.0), holding
*our* knife model, and animated by the pack's skeleton. Keep all the current
knife gameplay working, and keep `tools/knife_test.gd` passing.

When done, pressing 2 should show Cleatimus's gloved hands drawing the knife.
LMB slashes, RMB stabs, both with hands, and nothing clips through walls.

## What exists now (read these files first)

| File | What it does |
|---|---|
| `weapons/knife/knife_weapon.gd` | All knife gameplay and the current hand-keyed motion. Read it fully. |
| `weapons/knife/knife_model.tscn` | Built knife: 32 cm, **origin on the grip centre**, tip toward **-Z**, serrated spine toward **+Y**, flat faces ±X. A `Tip` marker sits at the point. |
| `tools/build_knife.gd` | Builds the above from `weapons/knife/source/knife_3d_model.glb`, plus a viewmodel shader (see below). |
| `player/player.gd` / `player.tscn` | `Head/Camera3D` (near = 0.01, fov 75) holds `TestGun` and `Knife`. Weapon switching calls `set_active()`. |
| `core/hitscan.gd` | Shared hit test, used by the knife's `_strike()`. |
| `tools/knife_test.gd` | 18 checks: timing, arcs, reach, head stabs, backstabs, walls, switching. |
| `tools/capture_knife.gd`, `tools/film_knife.gd` | First-person renders and a video clip, for checking how it looks. |

### Gameplay contract (must not change unless asked)

- `request("slash" | "stab")` starts an attack and buffers one more during the
  last 40% of a swing. Attacks are blocked during the draw.
- **Slash:** hit at **0.15 s**, swing length 0.5 s, 40 damage, wide arc (±34° rays).
- **Stab:** hit at **0.24 s**, swing length 0.72 s, 75 damage, narrow cone. A
  stab that finds the head uses the zombie's headshot multiplier. A stab from
  behind kills outright.
- Reach is 1.6 m from the eye. Walls and boards block hits. Ooze follows the cut.
- Signals `hit(target, headshot, killed)` and `swung(kind)`, plus
  `set_active()` and `is_busy()`, are used by the player, HUD and tests.

Hits are timed in code (`_attack_t >= _attack["hit"]`), not by the animation.
If you drive visuals from the pack's clips, keep the hit time and the visible
contact roughly in sync. Either retime the clip's playback speed so contact
lands at 0.15 s / 0.24 s, or move the hit time to match the clip **and** update
`knife_test.gd` to match.

### The viewmodel shader (important for the arms too)

`build_knife.gd` gives the knife a shader that draws it shrunk toward the eye.
It keeps the same screen position at a tenth of the depth, so it never sinks
into walls:

```glsl
vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
view_pos.xyz *= mix(1.0, 0.1, viewmodel);
POSITION = PROJECTION_MATRIX * view_pos;
```

This works in Forward+, Mobile **and** Compatibility. Don't use the "push
POSITION.z toward the near plane" trick. Godot's depth direction differs
between renderers, and that trick hid the knife entirely in Compatibility. The
arms need the same treatment, or they will clip into walls while the knife
doesn't. Apply the same vertex code to the arms' material: duplicate it as a
ShaderMaterial using the pack's texture with nearest filtering. Also turn off
shadow casting on viewmodel meshes.

## The arms pack

**It is not in the repo yet.** The owner downloads it from
https://heyheythere.itch.io/psx-fps-arms-free (`psx-fps-arms-free-assets.zip`,
9.4 MB, v1.0.2, free) and commits it. If it isn't present, stop and ask for
it; don't substitute other assets.

Suggested location: `addons/psx_fps_arms/` (the pack ships a Godot addon
folder), with its LICENSE kept. Add to `CREDITS.md`:

> PSX FPS Arms Free by heyheythere - https://heyheythere.itch.io/psx-fps-arms-free - CC BY 4.0

### What the pack is reported to contain

This comes from the store page and an earlier handover; verify it against the
actual files.

- An arms mesh (about 900 triangles) with a `Skeleton3D` and `AnimationPlayer`.
  The weapon socket bone is **`weapon_r`**.
- Three overlapping rigs:
  - `fp_arms_free_model.glb`: pistol + unarmed, 27 clips.
  - `fp_arms_free_v7_model.glb`: **corrected knife rig**, 11 clips.
  - `fp_arms_flashlight_model.glb`: flashlight, 6 clips.
- Knife clips: `kitchen_knife_idle`, `kitchen_knife_draw`,
  `kitchen_knife_holster`, `kitchen_knife_stab`, `kitchen_knife_inspect`.
  There is **one attack clip (stab), no slash.**
- Unarmed clips include `unarmed_punch_r`, `unarmed_punch_l` and `unarmed_push`.
- 30 fps animation, real-world scale, one 512×512 texture atlas.
- The pack README says to rotate the arms **180° around Y** under a
  first-person camera, and to **cancel the imported bone rest axes** on the
  held weapon. Follow its README rather than guessing transforms.
- It also contains its own kitchen knife mesh. **Hide or remove it**, because
  our knife replaces it.

## Suggested approach

1. **Inspect first.** Load the knife rig GLB headless and print the bone names,
   the animation list and lengths, `weapon_r`'s rest transform, and where the
   pack's kitchen knife is attached. Write what you found into this file under
   "Findings", so the next person doesn't redo it.
2. **Build a viewmodel scene**, e.g. `weapons/knife/knife_viewmodel.tscn`:
   - the arms rig under a `Node3D` rotated 180° on Y, per the README;
   - a `BoneAttachment3D` on `weapon_r` holding `knife_model.tscn`;
   - an offset `Node3D` between them, tuned so the hand wraps the handle. Our
     grip origin is the handle centre, the tip is -Z, the spine (serrated back)
     is +Y. Edge down and spine up is how a knife is normally held.
   - the pack's knife mesh hidden.

   Prefer a small build script (`tools/build_knife_viewmodel.gd`) over a
   hand-made `.tscn`, to match the rest of the repo, but either is acceptable.
3. **Drive it from `knife_weapon.gd`.** Replace the floating `Pivot` and model
   with the viewmodel:
   - draw: `kitchen_knife_draw`;
   - idle: `kitchen_knife_idle`, keeping the existing bob and sway as a small
     additive offset on the viewmodel root;
   - stab: `kitchen_knife_stab`;
   - slash: there's no clip. Options, in order of preference:
     - (a) keep the current procedural slash motion, but apply it to the
       viewmodel root, so the hands move with the knife;
     - (b) author a `slash` clip on the pack skeleton in code. `build_zombie.gd`
       shows how this repo authors clips with rotation tracks;
     - (c) as a fallback, play `kitchen_knife_stab` mirrored or with a sideways
       root motion.
   - When switching away, `set_active(false)` should hide everything.
     Optionally play `kitchen_knife_holster` first if that doesn't delay the
     swap noticeably (keep it under 0.25 s).
4. **Apply the viewmodel shader** to the arms (see above).
5. **Optional, only if the owner asks:** recolour the arms toward the
   character design: orange bomber sleeves, charcoal cuffs, teal fingerless
   gloves, dirty exposed fingertips, and a small watch on the **left** wrist
   that always reads **4:20**. Palette hex values are in `core/palette.gd`.
   Edit a copy of the atlas, not the original.

## Done means

- [x] Arms are visible holding our knife in idle, draw, slash and stab, checked
      by rendering `tools/capture_knife.gd` (update its shots if needed) and
      looking at the images. Commit the PNGs to `docs/previews/`.
- [x] The hand closes on the handle. The knife doesn't float off the palm or
      pass through the fingers in any frame of draw, stab, slash or idle.
- [x] Nothing clips into a wall when you stand against one (shot `knife7_stab_into_wall`).
- [x] All six test commands in `AGENTS.md` pass. Update `knife_test.gd` only
      for intentional timing changes, and say so in the commit.
- [x] `CREDITS.md` has the CC BY credit, and the pack's LICENSE is in the repo.
- [x] `README.md`'s "The knife" section describes the arms and how they're set up.
- [x] Re-film the clip:
      `xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --write-movie /tmp/knife.avi --script res://tools/film_knife.gd`,
      then encode it to `docs/video/knife_kill.mp4` with ffmpeg
      (`-c:v libx264 -crf 20 -pix_fmt yuv420p`).

## Findings

Implementation verified with **Godot 4.3 stable (77dcf97d8), Windows**, using the native display and `--rendering-method gl_compatibility` as the Windows equivalent of the brief's xvfb command.

### Actual source and skeleton

The original user-supplied PSX FPS Arms Free v1.0.2 addon is committed at `addons/psx_fps_arms/`, with its README and full CC BY 4.0 licence. The corrected knife rig is `models/fp_arms_free_v7_model.glb`. The active source GLB contains one skinned arms mesh and **no attached kitchen knife mesh**; the pack's separate kitchen knife scene is never instantiated. Only our existing `knife_model.tscn` is attached.

The imported skeleton is `Arms/fp_arms/Skeleton3D`, with **36 bones**, in this order:

```
root
lowerarm_r, hand_r
index_01_r, index_02_r, index_03_r
middle_01_r, middle_02_r, middle_03_r
ring_01_r, ring_02_r, ring_03_r
pinky_01_r, pinky_02_r, pinky_03_r
thumb_01_r, thumb_02_r, thumb_03_r
weapon_r
lowerarm_l, hand_l
index_01_l, index_02_l, index_03_l
middle_01_l, middle_02_l, middle_03_l
ring_01_l, ring_02_l, ring_03_l
pinky_01_l, pinky_02_l, pinky_03_l
thumb_01_l, thumb_02_l, thumb_03_l
```

`weapon_r` is bone 18. Its global rest transform, rounded:

```
X = (1, 0, 0)
Y = (0, 0, -1)
Z = (0, 1, 0)
origin = (-0.093916, -0.155331, 0.392123)
```

The rig has **11** clips:

| Clip | Seconds |
|---|---:|
| kitchen_knife_idle | 3.000000 |
| kitchen_knife_draw | 0.533333 |
| kitchen_knife_holster | 0.533333 |
| kitchen_knife_stab | 0.466667 |
| kitchen_knife_inspect | 3.200000 |
| flashlight_idle | 3.000000 |
| flashlight_draw | 0.533333 |
| flashlight_holster | 0.533333 |
| flashlight_swing | 0.533333 |
| flashlight_switch | 0.600000 |
| flashlight_inspect | 3.200000 |

There is no knife slash clip. `tools/inspect_knife_arms.gd` reproduces these observations and prints the 30 Hz stab samples.

### Attachment and animation timing

The builder rotates the rig by PI on Y, following the pack README. `KnifeSocket` follows `weapon_r`; its `GripOffset` has zero positional offset and this basis:

```gdscript
skeleton.get_bone_global_rest(weapon_bone).basis.inverse() * Basis(Vector3.UP, PI)
```

The extra PI converts our knife's -Z tip direction into the pack's +Z weapon convention. The spine remains up relative to the grip. Our knife geometry, scale and grip-centred origin are unchanged. The complete viewmodel root sits at `(0, -0.015, -0.025)` relative to the camera before additive motion.

Source stab **frame 7 at 7/30 = 0.233333 s** is the start of full extension; the socket's source-space position there is approximately `(-0.082268, -0.203117, 0.542888)`. Frames 7–9 form the extended part of the thrust. The controller manually samples frame 7 at the original gameplay **0.24 s** hit, then samples the rest of the source clip over the original recovery to **0.72 s**. Draw compresses the 0.533333-second source clip into the existing **0.32 s** draw gate. Idle is a native loop with existing bob/sway added to the root.

Slash retains its original **0.15 s** hit, **0.5 s** duration and original keyframe times. It samples the closed native knife idle grip and applies the existing procedural sweep to the entire rig. Root translation is attenuated to 0.45 and angular motion to `(0.45, 0.45, 0.40)` so the hands remain more visible. No attack constants, hit rays, damage, reach, head/backstab rules, buffer window or gameplay tests were changed. Switching away hides the full rig immediately; no holster delay was added.

### Recolour and rendering

The builder edits a **copy** of the original atlas. Four new tiles use the existing palette for orange sleeves, charcoal cuffs, teal gloves and dirty exposed distal fingers. Face-level UV-region assignment avoids stretching a cuff transition over a large forearm triangle. Original bone weights and vertex shading are retained. A non-emissive watch is attached only to `lowerarm_l`; its seven-segment atlas face is fixed at 4:20. The Cleatimus hand texture pack and WRAD textures are not used.

The arms/watch shader uses exactly the brief's `MODELVIEW_MATRIX` view-space shrink by 0.1, followed by `PROJECTION_MATRIX`. It does not write a renderer-specific depth value. All viewmodel meshes have shadow casting off and no colliders. The pack's original GLB and atlas are preserved. Generated viewmodels are flattened before packing; keeping both inherited instance state and explicit child ownership caused orphaned source nodes in Godot 4.3, which was corrected and checked with repeated instantiation/freeing.

### Validation and visual review

All six required commands completed successfully under Godot 4.3: import, validate, movement, zombie, ooze and knife. Each gameplay suite reported `0 failure(s)` or `problems: 0`. The unchanged `knife_test.gd` retains its original checks. The additional `knife_viewmodel_test.gd` passes seven checks covering the corrected rig, collider/shadow isolation, source stab/contact timing, slash grip and full-rig hiding. Every changed/new GDScript passes `--check-only`.

`tools/capture_knife.gd` was rendered with Compatibility and the resulting **eight PNGs were opened and visually reviewed**: draw, idle, slash windup/contact, stab drawback/thrust, recovery and the close-wall stab. The arms and existing knife remain visible in the close-wall shot. A further **48-frame** audit covers all 17 source draw samples, 16 slash samples and 15 source stab samples. Its contact sheets were inspected for grip separation, blade orientation and motion; no visible grip detachment was found in those samples. This is sampled visual verification, not an exact continuous mesh-intersection proof.

Capture/film tools now ignore desktop mouse steering for reproducibility. The knife kill film was re-recorded with Compatibility at 30 FPS and encoded with `libx264 -crf 20 -pix_fmt yuv420p` to `docs/video/knife_kill.mp4`. It contains 172 frames (5.73 seconds). A decoded MP4 frame was also inspected.


### Follow-up: right-side forearm entry

The original idle elbow was approximately `(-0.0475, -0.2855, +0.0880)` in eye space, behind the camera and left of centre, while the wrist was around `(0.0974, -0.1522, -0.2602)`. This made the arm appear to emerge from the chest.

`_position_right_forearm()` now solves the elbow from the wrist using the eye-space direction `(0.33, -0.18, 0.14)`, normalized to the source forearm length of 0.4 m. It reorients `lowerarm_r` toward the wrist and restores the original global `hand_r` pose. Finger and `weapon_r` transforms consequently stay unchanged. There is no new knife offset, arm scaling, mesh edit, hit timing or gameplay change.

The viewmodel suite now has ten passing checks. The added checks compare hand/socket transforms across native draw, idle and stab samples, confirm constant forearm length, and verify the resting elbow is to the right of the wrist and in front of the eye. All required gameplay suites pass. Updated Compatibility captures, the 48-frame audit sheets and the re-recorded knife video were reviewed. Offline captures were wall-limited to 30 rendered FPS; the existing 60/15 FPS play/background caps remain in place.
