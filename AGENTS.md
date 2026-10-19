# AGENTS.md — The Drive Thru

Instructions for coding agents (Codex, Claude, etc.) working in this repo.

## What this is

A Godot **4.3** first-person zombie-siege game set in a roadside drive-through.
The player is Cleatimus Maximus, a redneck mushroom farmer. Read `README.md`
for the full tour; it describes every system that exists today.

The game design is `docs/GAME_DESIGN.md`, with cooking detail in `docs/COOKING_DESIGN.md`. The burger loop is built; see README.

## Who's working on what (two agents in parallel)

To avoid stepping on each other, the owner has split the work:

- **Claude:** the cooking system (`game/grill.gd`, `game/prep_bench.gd`, new
  kitchen stations under `game/`, patty visuals), the shop terminal and
  economy (`game/shop_terminal.gd`, `game/economy.gd`), and the shotgun
  (`weapons/shotgun/`, slot 4, bought at the terminal).
- **Codex:** quality-of-life improvements, audio (`game/sfx.gd` and any new
  sounds), kitchen textures (calming the tiles; reuse the serving-room
  ones), and tightening up the visuals of scenery and NPCs
  (`tools/build_shop.gd`, `tools/shop_decor.gd`, `tools/make_textures.gd`,
  `textures/`, enemy and vehicle looks).

Shared files (`main.gd`, `player/player.gd`, README, this file): keep edits
small, pull before you start, and commit often. If you need something in the
other agent's area, make the smallest change that works and say so in the
commit message.

## Hard rules

1. **Godot 4.3, GDScript, statically typed.** When the right-hand side is a
   Variant (a dictionary value, an untyped method's return value), write
   `var x: Vector3 = ...`. `:=` on a Variant is a parse error in 4.3. Check every
   script you touch:
   `godot --headless --path . --check-only --script res://path/to/file.gd`
2. **Never hand-edit generated files.** These are rebuilt by scripts:
   - `levels/shop/generated/*`, `materials/*.tres`: `tools/build_shop.gd`
   - `enemies/shambler/shambler_model.tscn` and `shambler_*`: `tools/build_zombie.gd`
   - `weapons/knife/knife_model.tscn`, `knife_mesh.res`, `knife_material.tres`: `tools/build_knife.gd`
   - `weapons/knife/knife_viewmodel.tscn`, `cleatimus_arms_*`, `cleatimus_right_hand_mesh.res`, `dagger_viewmodel.tscn`, `cleatimus_dagger_hand_mesh.res`: `tools/build_knife_viewmodel.gd` (hand fit in `tools/knife_hand_mesh.gd`)
   - `enemies/scuttler/scuttler_model.tscn` and `scuttler_*`: `tools/build_scuttler.gd`
   - `enemies/lancer/lancer_model.tscn` and `lancer_*`: `tools/build_lancer.gd`
   - `pickups/mushroom/mushroom_pickup_mesh.res`, `mushroom_pickup_material.tres`, `mushroom_*.png`: `tools/build_pickup.gd`
   - `vehicles/*/` models, meshes, materials, albedos (school bus, armoured truck): `tools/build_vehicles.gd`
   - `fonts/pixel/pixel_font.tres`, `ui_theme.tres`: `tools/build_font.gd` (from the editable `fonts/pixel/glyphs.txt`)
   - `textures/*.png`: `tools/make_textures.gd` (it never overwrites existing PNGs)

   Change the build script, then rebuild.
3. **Keep every test passing.** Before you finish, run all of these. Each must
   print `0 failure(s)` or `problems: 0`:
   ```
   godot --headless --path . --import
   godot --headless --path . --script res://tools/validate.gd
   godot --headless --path . --fixed-fps 60 --script res://tools/movement_test.gd
   godot --headless --path . --fixed-fps 60 --script res://tools/zombie_test.gd
   godot --headless --path . --fixed-fps 60 --script res://tools/ooze_test.gd
   godot --headless --path . --fixed-fps 60 --script res://tools/knife_test.gd
   godot --headless --path . --fixed-fps 60 --script res://tools/knife_viewmodel_test.gd
   godot --headless --path . --fixed-fps 60 --script res://tools/spawn_test.gd
   godot --headless --path . --fixed-fps 60 --script res://tools/scuttler_test.gd
   godot --headless --path . --fixed-fps 60 --script res://tools/pickup_test.gd
   godot --headless --path . --fixed-fps 60 --script res://tools/loop_test.gd
   godot --headless --path . --fixed-fps 60 --script res://tools/lancer_test.gd
   ```
   The harmless engine message `Parameter "m" is null` in headless runs can be ignored.
4. **Check visuals by rendering, not by assuming.** Headless runs have no
   renderer. For pictures, use a virtual display and the Compatibility renderer:
   `xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tools/capture_knife.gd`
   (writes PNGs to `docs/previews/`). Then look at the images.
5. **Palette only.** Colours come from `core/palette.gd` (9 colours). Don't
   introduce new hues. Only light sources emit light. The exceptions are the
   Scuttler's glowing orange cap spots and the dropped mushroom pickups, which
   are deliberate bioluminescence.
6. **Respect licences.** The PSX FPS Arms Free pack is CC BY 4.0. Any use of it
   must keep its LICENSE file and the credit line in `CREDITS.md`.
7. **Small, honest commits.** Say in the commit message what you changed and
   what you tested. Don't claim something works unless a test or a render
   showed it.

## Layout

```
core/            palette, ooze FX, window barricades, shared hitscan
enemies/shambler shambler.gd (behaviour), built model + animations, source GLB
enemies/scuttler scuttler.gd (behaviour), built model + IK animations, source GLB
enemies/lancer   lancer.gd (behaviour), built model + animations, source GLB
weapons/knife    knife_weapon.gd (gameplay), built model, source GLB
pickups/mushroom glowing mushroom dropped by dead enemies (script, glow shader, built mesh)
vehicles/        customer vehicles (school bus, armoured truck) built from source GLBs
game/            the burger loop: economy, stations (store, grill, prep bench, drive-thru, terminal), customers, pixel icons, synth sounds
player/          player.gd (movement, health, repair, weapon switching), test_gun.gd
levels/shop      generated shop scene
fonts/pixel      the pixel font (project theme): glyph source, built font, owner's lettering sheet
tools/           build scripts, tests, capture/film scripts
docs/            previews, videos, handover briefs
```

Physics layers: 1 world · 2 barricades · 3 player · 4 enemies (bodies and
head hitboxes) · 5 player_clip · 6 interact (station look-zones, Area3D with meta "station").

Weapons are children of `Player/Head/Camera3D` that implement
`set_active(on: bool)`. The player collects them in order (slot 1 = pistol,
slot 2 = knife, slot 3 = dagger alternative using the same knife script).
