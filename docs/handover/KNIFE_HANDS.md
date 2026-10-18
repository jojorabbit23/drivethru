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

- [ ] Arms are visible holding our knife in idle, draw, slash and stab, checked
      by rendering `tools/capture_knife.gd` (update its shots if needed) and
      looking at the images. Commit the PNGs to `docs/previews/`.
- [ ] The hand closes on the handle. The knife doesn't float off the palm or
      pass through the fingers in any frame of draw, stab, slash or idle.
- [ ] Nothing clips into a wall when you stand against one (shot `knife7_stab_into_wall`).
- [ ] All six test commands in `AGENTS.md` pass. Update `knife_test.gd` only
      for intentional timing changes, and say so in the commit.
- [ ] `CREDITS.md` has the CC BY credit, and the pack's LICENSE is in the repo.
- [ ] `README.md`'s "The knife" section describes the arms and how they're set up.
- [ ] Re-film the clip:
      `xvfb-run -a godot --path . --rendering-method gl_compatibility --fixed-fps 30 --write-movie /tmp/knife.avi --script res://tools/film_knife.gd`,
      then encode it to `docs/video/knife_kill.mp4` with ffmpeg
      (`-c:v libx264 -crf 20 -pix_fmt yuv420p`).

## Findings

_(Fill in after inspecting the pack: bone names, clip lengths, contact frame
of the stab, the `weapon_r` offset you settled on.)_
