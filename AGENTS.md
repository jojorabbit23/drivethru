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
   - `levels/exterior/generated/surroundings.tscn`: `tools/build_exterior.gd` (static scenery; keep routes clear)
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

Stylized pistol: slot 1 now uses the owner's stylized_pistol.glb, preserving Cleatimus hands. tools/build_pistol.gd delegates mechanical geometry/clips to tools/stylized_pistol_rig.gd. All stylized_*.res, stylized_pistol_rig.tscn and stylized_albedo.png are generated; retain original sources. Run stylized_pistol_test.gd and capture_stylized_pistol.gd. See docs/handover/STYLIZED_PISTOL_RIG.md.

Scientist infected: tools/build_scientist.gd generates enemies/scientist/scientist_model.tscn and scientist_*.res from the retained owner GLB. tools/audio/make_scientist_audio.py generates its WAVs. fallen_head.gd is cosmetic, capped at six, world-only collisions and five-second cleanup; never award kills or drops for heads. Run scientist_test.gd and native capture_scientist.gd. See docs/handover/SCIENTIST_INFECTED.md.

Garage extension: tools/garage_room_builder.gd is called by tools/build_shop.gd; rebuild the shop scene/export after edits. game/garage_room.gd owns the $250 fridge rear-door unlock. Window_C is excluded from the windows group until purchase; the second rear door stays closed. Keep exactly three shared destructible empty bottles. Run garage_test.gd and capture_garage.gd. See docs/handover/GARAGE_EXTENSION.md.

Garage motorcycle: props/motorcycle/motorcycle_mesh.res is generated by tools/build_motorcycle.gd from the retained owner GLB. Rebuild it before tools/build_shop.gd. Keep the supplied texture colours, grounded 2.35 m length and clear centre aisle.
Building decoration guide: props/building_decor/generated/*.tscn are generated by
 tools/build_building_decor.gd; original synthesized WAVs by tools/audio/make_decor_audio.py.
The owner's Building Decoration Guide explicitly permits its 14-colour local palette
(props/building_decor/palette.gd), including faint spore moss emission. Keep this local.
The fryer remains decorative until fried food is designed (owner decision).
Interior loose props use world-layer damage Areas so they do not trap the player;
Hitscan.cast includes world Areas. Solid exterior cover and the booth use bodies.
Run building_decor_test.gd and all existing tests. Native captures on this Windows
machine use --rendering-method mobile (Vulkan); do not switch to GL, which caused
whole-machine slowdown. Keep existing shadow-budget limits and cooking APIs.

Mixed orders: game/order_progression.gd owns wave-scaled demand and timing.
CustomerCar.order remains the first outstanding recipe for legacy callers; use
remaining_lines()/wants()/record_delivery()/ticket_text() for full mixed tickets.
Keep single-recipe quantity/received compatibility and existing freshness/discount
rules. See docs/handover/MIXED_CUSTOMER_ORDERS.md; run mixed_orders_test.gd and
capture_mixed_orders.gd as well as all existing checks. Decorations stay disabled.

Delivery hatch: main.delivery extends the existing customer window with a phone
ticket and independent four-box tray, gated by the $250 garage then a $200 hatch.
Keep existing zombie Window_C separate and rear door closed. G selects prep channel;
bench.hatch remains the original car hatch, active_hatch() returns the selected one.
Grill flip_fraction metadata must survive the patty warmer and assembly; shared
BurgerItems.payment applies the accurate-flip bonus before freshness scaling.
See docs/handover/UNDEAD_DELIVERY.md; run delivery_test.gd and capture_delivery.gd.

Mushroom grinder: game/grinder_station.gd owns the deposit transaction at Codex's grinder (group mushroom_grinder; play_deposit is cosmetic only). Never create stock from the visual, and keep exactly one grinder model. Run tools/grinder_test.gd and tools/capture_grinder_station.gd.

First-person arms: every weapon uses shared rigged arms in weapons/fps_arms/ (fps_arms.gd; AKS rig for knife/dagger/shotguns, Pistol 43 rig for the handguns, one-handed with left_weight raised for reloads; credits in CREDITS.md). Weapons keep their own animation and old hand nodes; FpsArms.attach() hides the old hand meshes and IK-follows those nodes. Don't re-show or delete the old hand nodes: they are the IK targets. When a weapon's hand placement changes, re-solve FITS with tools/fps_arms_fit_export.gd + tools/fps_arms_frames_export.gd + tools/fps_arms_fit.py (grip-frame start; plain ICP can turn hands backwards; handguns: tools/fps_arms_gun_fit.gd), and check fingers with tools/capture_fps_arms_close.gd. Run tools/fps_arms_test.gd and render tools/capture_fps_arms.gd.

Wave flow: main.gd stages enemy types by wave (scuttler/scientist/lancer_from_wave), spawns groups (group_size) through distinct windows, retries capped spawns after CAP_RETRY, and grows breaks (break_length). Customer patience bonus applies from wave 1. Run tools/wave_flow_test.gd; use tools/wave_flow_sim.gd to measure flow. See docs/handover/WAVE_FLOW.md.

SMG: weapons/smg/smg_weapon.gd extends player/test_gun.gd (shooting, ammo, HUD hooks) but builds its own viewmodel from the full weapons/fps_arms/source/aks74u_hands.glb (gun kept, rig animations played; it does not use FpsArms IK). Bought at the shop terminal (Economy.SMG_PRICE / SMG_AMMO_*), display_name "SMG". fps_arms.gdshader has an albedo_color uniform for untextured parts. Run tools/smg_test.gd and render tools/capture_smg.gd.
