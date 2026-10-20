# AGENTS.md — The Drive Thru

Instructions for coding agents (Codex, Claude, etc.) working in this repo.

## What this is

A Godot **4.3** first-person zombie-siege game set in a roadside drive-through.
The player is Cleatimus Maximus, a redneck mushroom farmer. Read `README.md`
for the full tour; it describes every system that exists today.

The game design is `docs/GAME_DESIGN.md`. The first playable slice of it (the burger loop) is built; see README.

## Hard rules

1. **Godot 4.3, GDScript, statically typed.** When the right-hand side is a
   Variant (a dictionary value, an untyped method's return value), write
   `var x: Vector3 = ...`. `:=` on a Variant is a parse error in 4.3. Check every
   script you touch:
   `godot --headless --path . --check-only --script res://path/to/file.gd`
2. **Never hand-edit generated files.** These are rebuilt by scripts:
   - `enemies/hollowhead/hollowhead_model.tscn`, `hollowhead_mesh.res`: `tools/build_hollowhead.gd` (static source GLB retained)
   - `enemies/hollowhead/audio/click.wav`: `tools/audio/make_hollowhead_click.py` (NumPy)
   - `pickups/health/bottle_mesh.res`: `tools/build_health_bottle.gd` (owner GLB retained in source/)
   - `levels/shop/generated/*`, `materials/*.tres`: `tools/build_shop.gd`
   - `enemies/shambler/shambler_model.tscn` and `shambler_*`: `tools/build_zombie.gd`
   - `weapons/knife/knife_model.tscn`, `knife_mesh.res`, `knife_material.tres`: `tools/build_knife.gd`
   - `weapons/knife/knife_viewmodel.tscn`, `cleatimus_arms_*`, `cleatimus_right_hand_mesh.res`, `dagger_viewmodel.tscn`, `cleatimus_dagger_hand_mesh.res`: `tools/build_knife_viewmodel.gd` (hand fit in `tools/knife_hand_mesh.gd`)
   - `enemies/scuttler/scuttler_model.tscn` and `scuttler_*`: `tools/build_scuttler.gd`
   - `pickups/mushroom/mushroom_pickup_mesh.res`, `mushroom_pickup_material.tres`, `mushroom_*.png`: `tools/build_pickup.gd`
   - `vehicles/school_bus/bus_model.tscn`, `bus_*`: `tools/build_bus.gd`
   - `vehicles/rugged_truck/rugged_*`: `tools/build_rugged_truck.gd` (uses the shared vehicle builder)
   - `weapons/crop_duster/audio/sawn_off_deep_blast.wav`: `tools/audio/deepen_sawn_off.py` (NumPy; source WAV unchanged)
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
   ```
   The harmless engine message `Parameter "m" is null` in headless runs can be ignored.
4. **Check visuals by rendering, not by assuming.** Headless runs have no
   renderer. For pictures, use a virtual display and the Compatibility renderer:
   `xvfb-run -a godot --path . --rendering-method gl_compatibility --script res://tools/capture_knife.gd`
   (writes PNGs to `docs/previews/`). Then look at the images.
5. **Palette only.** Colours come from `core/palette.gd` (9 colours). Don't
   introduce new hues. Only light sources emit light. The exceptions are the
   Scuttler's glowing orange cap spots and the dropped mushroom pickups, which
   are deliberate bioluminescence. The owner-supplied tomato reference also permits
   natural red flesh for the kitchen tomato slices (local food-colour exception).
   The owner-supplied blue health bottle and Hollowhead retain their supplied textures, including Hollowhead blue trousers.
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
weapons/knife    knife_weapon.gd (gameplay), built model, source GLB
pickups/mushroom glowing mushroom dropped by dead enemies (script, glow shader, built mesh)
vehicles/        customer vehicles (school bus) built from source GLBs
game/            the burger loop: economy, stations (store, grill, drive-thru, terminal), cars, pixel icons, synth sounds
player/          player.gd (movement, health, repair, weapon switching), test_gun.gd
levels/shop      generated shop scene
tools/           build scripts, tests, capture/film scripts
docs/            previews, videos, handover briefs
```

Physics layers: 1 world · 2 barricades · 3 player · 4 enemies (bodies and
head hitboxes) · 5 player_clip · 6 interact (station look-zones, Area3D with meta "station").

Weapons are children of `Player/Head/Camera3D` that implement
`set_active(on: bool)`. The player collects them in order (slot 1 = pistol,
slot 2 = knife, slot 3 = Crop Duster, slot 4 = dagger alternative using the same knife script).

## Integrated project (2026-10-19)

The canonical project combines GitHub main's cooking/prep, purchases, vehicles and
Lancer with the custom pistol, original Crop Duster, menu, room art and presentation.
The purchased pump is appended as slot 5; use the wheel to select it. Never replace
the Crop Duster or dagger when integrating it. The pistol combines OpenCode's new
hand builder with the original textured pistol mesh; both pistol and pump emit
two ammo_changed arguments. main.gd also accepts the older zero-argument signature.

Rebuild room geometry/materials with tools/build_shop.gd. Keep its kitchen_room.gd
and serving_room.gd delegates: using an older shop_decor.gd removes the owner art.
Rebuild the pump model/hands with tools/build_shotgun.gd; keep the PSX Firearms licence.
Also run every tools/*test.gd suite, including integration_test.gd, plus validate.gd.
Render kitchen, serving room, pistol, knife and pump captures before shipping changes.
Claude owns cooking/station rules; Codex owns presentation. Shared main/player changes
must preserve both sets of APIs. Pull/merge before editing; do not replace whole files
with a copy from another branch. Do not hand-edit generated scenes or materials.

Burger inventory update: use player.add_burger()/take_selected_burger(), not
set_held(), for new gameplay. Burger dictionaries retain hot_remaining across
inventory/tray transfers; never reset it on retrieval. Capacity unlocks on
wave_started at 3/6/9, max four. ServingTray is boxed food, separate from the heated
patty tray. Sawn-off starts reserved in slot 3 but requires purchase; wheel skips it
until bought. Both shotguns have independent ammo purchases. See
docs/handover/BURGER_INVENTORY_TRAY.md; run burger_inventory_test.gd and the native
capture_serving_inventory.gd interaction assertions alongside all existing checks.

Rush shelf: age_seconds belongs to each burger; hot_remaining is a compatibility
projection. Never reset either on transfer. Freshness stages and payments live in
game/burger_items.gd. Discount Box shares the four tray spaces. The serving heater
is separate from the patty warmer. See docs/handover/RUSH_SHELF.md.

Kitchen radio BROADCASTS play once per run after track 2; retain played_broadcasts
across music loops and power toggles. Off/on pauses/resumes the current stream.

Fungal stock props: props/fungal_stock/cut_*.res and stock_material.tres are generated by tools/build_fungal_stock.gd; placements are in tools/shop_decor.gd. Rebuild the stock before tools/build_shop.gd.

Empty bottle mesh props/empty_bottle/bottle_mesh.res is generated by tools/build_empty_bottle.gd; glass_break.wav by tools/audio/make_glass_break.py. Destructible props use Hitscan.damage_prop and never join zombie groups.

Mushroom naming: the legacy internal red/double_red identifiers display as Yellow/Double Yellow. Keep identifiers compatible with stored burgers; use Economy.KIND_NAME and Recipes.name_of for player-facing labels.

Drop variants pickups/mushroom/pack_*.res and pack_material.tres are generated by tools/build_pickup_variants.gd from source/mushroom_pack.glb. Three morels are intentionally excluded; preserve complete-component selection.

Playtest clarity: presentation/clarity_hud.gd reads customer state and provides presentation only. Repair now requires facing and line of sight; headless repair scenarios must aim at the window. Run tools/clarity_test.gd and tools/capture_clarity.gd. See docs/handover/PLAYTEST_CLARITY.md.
