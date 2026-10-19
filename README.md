Burger service update: V cycles carried burgers; E on an empty hatch-tray slot places the selected burger, E on a box retrieves it, and E at the hatch bin discards the selected item. Capacity starts at one and increases after clearing waves 3/6/9, to four. Burgers cool after 150 seconds including tray time; each cold item pays 50%. Both shotguns and separate shell packs are in the shop. See docs/handover/BURGER_INVENTORY_TRAY.md.

Performance update: menu input targets 60 FPS, intro clips decode at 720p, fullscreen keeps the 720p render budget, and balanced nearby shadows are now the default. Full lighting shadows remain available in settings. All 21 suites pass; see docs/handover/PERFORMANCE_MENU_RENDERING.md for measured results and remaining hitch limits.

# Current combined recovery — 2026-10-19

Use `../Play_DriveThru.cmd` to play this combined project. Restored kitchen/serving
art, GitHub main's newer cooking/prep/pump/Lancer/vehicles, OpenCode movement and
new pistol hands, and the original textured pistol are integrated here. Original
slots 1–4 remain; the purchased pump is appended and selectable with the wheel.
R reloads firearms; Esc pauses. See docs/handover/RECOVERY_2026_10_19.md for provenance
and verification. Older sections below record earlier stages of development.


---

Historical notes below (superseded by the recovery above).

# Current combined playtest — 19 October 2026

Open Play_DriveThru.cmd in the parent outputs folder. The menu, intro and bus cinematic now load the same game containing cooking, customer service, economy, storage, grill, shop terminal, waves, Scuttlers and mushroom pickups, plus the animated custom pistol, Crop Duster and revised knife/dagger hands.

E uses a station; 1–4 choose options while its menu is open. Otherwise 1 pistol, 2 knife, 3 Crop Duster, 4 dagger; mouse wheel also switches. R reloads firearms; F inspects. R restarts after death or while holding a knife. F2 toggles auto-collect. Z/X spawn Shambler/Scuttler. Kill → collect → store → cook → bag → serve → buy supplies. Continue remains disabled until saves exist.

Latest gameplay source integrated: GitHub main fefcb797c8c942749151d9783571c6aa90b8f2de. The custom pistol retains its existing 15-round magazine, 90 reserve and 2.1 s reload; the terminal adds 24 reserve rounds for $12. The cooking-loop test now exercises that actual animated pistol through player fire gates and its real reload timing. Gameplay and intro buses are separate owner-supplied assets.

All 84 owned scripts parse; all 15 suites pass (validate, movement, zombie, ooze, knife, knife viewmodel, spawn, Scuttler, pickup, cooking loop, pistol, Crop Duster, menu, presentation and kitchen visuals). Rendered and inspected menu/video handoff, grill/customer stations and current weapon poses. The short capped performance check passed focus limits; it does not prove sustained 60 FPS under every load.

See docs/handover/FINAL_COMBINED.md for provenance, integration and verification. Esc now pauses; F1 toggles detailed controls. Audio, sensitivity and comfort settings persist between sessions. The kitchen uses calmer serving-room tiles and steel. See docs/handover/PRESENTATION_POLISH.md for this pass. Older sections below describe earlier development stages and may use superseded controls.

Original sawn-off update: over-chamber reload hand, stronger recoil/report, brief vapor and 22 damage per pellet. Kitchen grinder/bin visuals and distant ambience are included. These props await Claude’s transaction/interaction wiring. See docs/handover/CODEX_SIDE_IMPLEMENTED.md and docs/video/sawn_off_updated.mp4.

---

# The Drive Thru — greybox prototype

Godot 4.3+ project. Open `project.godot` and press **F5** to walk around the shop.

**Controls:** WASD move · Shift sprint · Space jump · 1 pistol / 2 knife / 3 Crop Duster (or mouse wheel) · LMB fire / slash · RMB aim / stab · R reload firearms (restart after death, or while holding knife) · F inspect firearms · hold E repair · Z spawn zombie · L labels · Esc release mouse (click to recapture)

The first Shambler comes down Window A's lane (east, kitchen side) three seconds after you start.

## What's here

A four-room, blocked-out drive-through shop on a 12 × 10 m footprint with 3 m ceilings:

| Room | Corner | Exterior feature |
|---|---|---|
| Shop floor | north-west | Service hatch + counter facing the customer road |
| Kitchen | north-east | **Window A**, boarded, east approach lane |
| Back office | south-west | **Window B**, boarded, west approach lane |
| Storeroom | south-east | Delivery door (closed) onto the delivery apron |

All four rooms connect through 1.2 m doorways, which form a loop.

Each breach window has:

- 4 boards, each its own `StaticBody3D` on the `barricades` physics layer. Removing a board or disabling its layer opens that part of the window.
- An 11 m approach lane lined with jersey barriers and timber palisades, plus a lamp post.
- Markers: `Breach_Point` (outside, where an enemy would stand to rip boards), `Repair_Point` (inside, where the player stands to repair) and `Lane_Spawn` (far end of the lane).

There are also site-wide markers under `ShopGreybox/Markers`: `PlayerStart`, `Customer_Lane_Start`, `Customer_Stop`, `Customer_Lane_End`, `Delivery_Spawn` and `Delivery_Drop`.

Physics layers: 1 world · 2 barricades · 3 player · 4 enemies (bodies and head hitboxes) · 5 player_clip.

## Decoration (starter state)

The decoration follows the concept sheet's starter look.

**Outside:**
- Teal painted block walls on a concrete plinth.
- A rusty orange fascia with concrete coping.
- Dark steel window frames and concrete sills.
- Caged wall lamps over each window, the back door and the frontage.
- An awning and amber strip over the hatch.
- Orange bollards and downpipes.
- The grinning burger-and-crown mascot on the roof and on a pole sign at the road corner.
- Condenser units and an extract stack on the roof.
- Timber palisades behind the lane barriers and round the site.
- Stacked crates, a pallet of stock, an oil drum, and X barricades across the far side of the road.

**Inside:**
- Grubby tiled walls, a drop ceiling with light panels, and exposed pipe runs, including an orange gas line.
- Steel posts, a lintel and a caged lamp framing each window.
- **Shop floor:** a teal-cabinet service counter with a steel top and a shelf through the hatch, a till, condiments, bags and cups, stock shelving, a lit drinks fridge and a bin.
- **Kitchen:** a prep bench, a griddle with patties, a twin fryer and a bun tray under an extractor hood, plus a tall fridge and a bun rack.
- **Back office:** a desk with a CRT, a chair, a pinboard, a filing cabinet, a safe, a camp cot, and Cleatimus's mushroom grow shelf.
- **Storeroom:** four stocked shelving units, a pallet of crates, a sandbag pile and a hand truck.

Decoration lives in `tools/shop_decor.gd`. It ends up under `ShopGreybox/Decor` as one merged mesh per group: `Decor_Shell`, `Decor_Roof`, `Decor_Exterior`, `Decor_Fences`, `Decor_Interior` and `Props_<room>`. That makes it easy to hide or swap a whole set for upgrade tiers later.

Furniture has simple box collision. `validate.gd` checks that every doorway, both window repair spots, the counter and the delivery door stay reachable.

## Movement

`tools/movement_test.gd` drives the real player controller around the shop and fails if anything feels wrong:

```
godot --headless --path . --fixed-fps 60 --script res://tools/movement_test.gd   # add -- --seed N for a different fuzz
```

Each run (about 10 seconds) covers:
- **Floor map:** every 10 cm of floor is checked for whether the player fits there and can reach it from the start.
- **Doorways:** 124 passes through the doorways, walking and sprinting, centred, hugging each frame, and at ±35°, in both directions.
- **Tours and slides:** full tours of every room and working spot, plus diagonal slides along every wall and run of furniture.
- **Gaps:** every gap narrower than the player is jabbed from five angles, with a jump.
- **Windows:** runs and jumps at both windows, boarded and open.
- **Fuzz:** 24 random bots running, sprinting and jumping for 60 s each.

The current result is 0 problems: no stuck spots, wedges, escapes, pockets, bumps or floor seams. That held across four fuzz seeds. `docs/movement_map.png` shows the walkable floor.

**Player clip.** Physics layer 5 (`player_clip`) holds invisible blockers that only the player collides with, as in Source-engine maps. They:
- stop you climbing the shop counter, kitchen line, office desk bank, bin, storeroom crate stack and sandbag corner;
- fill the slots beside them that would otherwise jam the capsule.

Bullets and enemies ignore this layer. The player's mask is `1 | 2 | 16`. Add clips in `shop_decor.gd` with `b.clip(group, from, to)`.

**What's deliberately left:**
- You can hop onto the office cot. It's 30 cm high, with full headroom.
- If you slide along a wall past an open doorway, you drift in and brush the far frame. That's normal physics, not a snag.
- The windows can't be climbed. Their sills sit just above jump height, and the opening is shorter than the player even with the boards gone. If you raise `jump_velocity` above about 4.2, rerun the test.

## The Shambler (first zombie)

`enemies/shambler/` is built from your `voxel_zombie_3d_model.glb`. The original is kept in `source/`.

**Model:** `tools/build_zombie.gd` turns the static model into a game-ready one:
- It's scaled to 1.8 m, faces forward, and stands with its feet on the floor.
- It has an 18-bone skeleton placed on this model's own proportions. The club arm and the rooted leg each get their own chain.
- Skin weights come from limb-shaped capsules: fat for the club, slim for the normal arm. The mushroom cap is its own region, above the gap over the shoulders. The spine and neck bend smoothly instead of creasing, and every limb joint blends over a few centimetres; the armpit on the normal arm gets an extra-wide blend.
- No triangles are removed: the build checks that the mesh stays watertight. The material is double-sided, so if a joint folds a sliver over at an extreme pose you see the inside of his shirt, not through him.
- There are 4 LOD levels, from 9,600 triangles close up down to about 1,300 at range. Godot switches between them automatically.
- The 4K textures are reduced to one 1024 px colour map with crisp pixel filtering.

**Animations:** 7 clips are authored in code and editable in Godot's animation editor afterwards:
- `idle`, and a limping `shamble`;
- `rip`: hook a board and yank it, with the board coming off at 1.05 s;
- `swing`: a club swing, with the hit at 0.62 s;
- `climb`, `flinch` and `death`.

`docs/previews/shambler_animations.png` shows them all.

**Behaviour** (`shambler.gd`):
- **Lane:** shambles down the lane at walking pace.
- **Breach:** rips boards top-down, and each one tumbles into the lane.
- **Climb:** clambers through once the window is empty.
- **Hunt:** paths to you anywhere in the building, using a navmesh baked by `build_shop.gd`.
- **Attack:** swings for 20 damage if you're still in front of it when the hit lands.

Zombies steer round each other, so a crowd doesn't jam in doorways. A heavy hit makes it flinch. It has 100 health: three body shots or one headshot, with a separate head hitbox that follows the head bone. Corpses stop blocking straight away and vanish after 10 s.

**Windows** (`core/window_barricade.gd`): `rip_board()`, `repair_board()`, `boards_left()` and `is_breached()`, plus signals. Holding E within 1.4 m of a window's repair spot puts a board back every 0.9 s. That's just quicker than one Shambler rips them, so you can hold off one zombie alone but not two.

**Ooze** (`core/ooze.gd`): every hit sprays orange ooze from the exact wound:
- **Where it goes:** most of it blows through along the bullet's path, some splashes back toward you, and a little dribbles straight down. Headshots also fountain out of the top of the cap.
- **Real droplets:** each droplet flies under gravity and leaves a splat on whatever it actually hits: the floor, the wall behind, window boards, the frame, a fridge.
- **Shape follows the hit:** square-on hits make round splats, and glancing ones streak along their direction of travel.
- **Drips:** on walls and boards the ooze runs downwards, but only as far as that surface goes, so drips stop at a board's edge.
- **Fitting:** each splat probes the surface under it and shrinks to fit, so nothing hangs off edges or bridges the gaps between boards. Splats too big for a sliver of surface are skipped.
- **Corpse puddle:** a puddle spreads under the body after it falls, as far as the floor allows.
- **Other details:** a quick spiky burst flashes at the wound. Hitting a board makes no ooze.
- **Limits:** up to 180 splats at once; the oldest are recycled, and each fades after 60 s. Splats are alpha-cut quads painted from the palette at startup, so they work in every renderer, including Compatibility, which has no decals.

Weapons pass hit info with `zombie.take_damage(damage, headshot, {"pos": hit_point, "dir": bullet_dir, "normal": surface_normal})`. Without it there's no spray.

`tools/ooze_test.gd` checks the following, and passes on repeated runs:
- every splat and drip sits fully on real geometry;
- most ooze lands behind the zombie, and flips side when you shoot from the other direction;
- the wall behind gets hit and drips, and drips never appear on floors;
- headshots make more mess than body shots, and corpses leave a puddle;
- wood doesn't ooze;
- the caps hold. 60 headshots in a row cost about 170 ms of simulation in total.

The clips `docs/video/ooze_closeup.mp4` and `shambler_encounter.mp4` show it in action.

**Placeholder bits** (to be replaced by the Glock and FPS arms): `player/test_gun.gd` is an invisible hitscan pistol with a muzzle flash and spark. Player health is 100, with a damage flash and a death screen.

**Zombie test** (`tools/zombie_test.gd`, about 1 min):
- A zombie comes from each lane to each of four hiding spots.
- Repair holds off a ripping zombie.
- Shooting: through the boards, a one-shot headshot, three body shots, and the corpse stops blocking.
- Six-zombie crowds from both lanes reach you at three different spots, with nothing stuck or jammed.

Everything currently passes. Typical timeline: at the window at 10 s, boards gone and climbing at 15.6 s, inside at 17 s.

## The knife

`weapons/knife/` is built from your `knife_3d_model.glb`; the original is kept in `source/`.

**Model:** `tools/build_knife.gd` makes the weapon model:
- It works out the knife's own axes from its shape. The long axis is the length. The tip is the thin end, since the handle is chunkier. The spine is the thicker long edge, since the cutting edge is ground thin.
- It turns the knife tip-forward with the serrated spine up and scales it to 32 cm.
- The origin sits on the grip, which is where the PSX arms' `weapon_r` bone holds it.
- A `Tip` marker marks the point.
- The texture is reduced to a 512 px nearest-filtered map.

`docs/previews/knife_orthographic.png` has side, top and front views on a 1 cm grid.

**In hand**, `knife_weapon.gd` drives the corrected-v7 PSX FPS Arms Free skeleton with our existing knife attached to `weapon_r`:
- **Slash (LMB):** a quick sweep from right to left. It does 40 damage with a wide arc of about ±34° and lands 0.15 s into the swing.
- **Stab (RMB):** a draw-back then a thrust in from the lower right. It does 75 damage in a narrow cone and lands at 0.24 s.
- **Head stabs** use the zombie's headshot multiplier, so they kill. A slash that clips the head is a normal hit.
- **Backstab:** a stab from behind kills outright.
- **Reach:** 1.6 m. That's just over a Shambler's 1.5 m swing, so stepping in and striking first works.
- **Buffering:** pressing an attack late in a swing queues the next one.
- **Ooze:** follows the blade, sideways for a slash and forward for a stab.
- **Walls and boards:** the blade clinks on them and never hits through them.
- **Feel:** a draw animation, idle breathing, bob while walking and lag behind mouse look.

The right forearm is re-aimed from the lower-right side of the view. The source elbow sat slightly left of centre and behind the eye; the runtime adjustment moves that elbow while retaining the original 40 cm forearm length and preserving the wrist position and relative finger/knife attachment. The blade stays in the same grip during draw, slash and stab.

The native `kitchen_knife_draw`, `kitchen_knife_idle` and `kitchen_knife_stab` clips animate the arms. There is no supplied slash clip: the existing procedural sweep moves the complete rig while retaining its closed knife grip. Source stab frame 7 (full extension) maps to the existing 0.24-second contact; recovery ends at the original 0.72 seconds. Gameplay damage, reach, buffering, head stabs, backstabs, switching, wall blocking and ooze are unchanged.

`tools/build_knife_viewmodel.gd` generates `weapons/knife/knife_viewmodel.tscn`, its skinned recoloured mesh, material and a copy of the atlas. The arms rotate 180 degrees around Y; `GripOffset` cancels the imported socket rest axes and turns our -Z-facing knife into the pack's +Z convention. Original assets are preserved in `addons/psx_fps_arms/` with README, licence and credit in `CREDITS.md`. No pack knife or colliders are included in the active viewmodel.

The optional character recolour uses the shared palette: orange sleeves, charcoal cuffs, teal fingerless gloves and dirty fingertips. A small watch follows the **left** forearm and always displays **4:20**. Its face reflects light rather than emitting it. The supplied Cleatimus HD base-colour and roughness atlases are now applied with mipmapped filtering. The older non-HD pack and WRAD textures remain unused. The elbow direction blends halfway between the original and outward poses; the resting grip is tilted 15 degrees more upright, easing to the native stab orientation at contact.

Rebuild with `godot --headless --path . --script res://tools/build_knife_viewmodel.gd` after importing the source assets. `tools/inspect_knife_arms.gd` prints bones, clips and stab extension samples. `tools/knife_viewmodel_test.gd` checks the visual/gameplay interface alongside the unchanged `knife_test.gd`. Detailed transforms and validation are recorded in `docs/handover/KNIFE_HANDS.md`.

The knife, arms and watch all use the same view-space depth shrink (same screen position at a tenth of the depth), with shadow casting off. The required Compatibility renders, including the close-wall stab, are in `docs/previews/knife0_draw.png` through `knife7_stab_into_wall.png`. Run `tools/capture_knife.gd` to refresh them. Its optional `-- --audit` captures every source frame of draw/stab and 30 Hz slash samples; set `KNIFE_AUDIT_DIR` to choose the output folder.

**Weapon switching:** `player.gd` collects every child of `Head/Camera3D` with `set_active()`. Slot 1 is the placeholder pistol and slot 2 is the knife; the HUD shows the current one, bottom right.

**Shared hit test** (`core/hitscan.gd`): walls and boards block everything, then a head hitbox wins over a body. Both the pistol and the knife use it. It also fixes headshots against a hunched zombie, whose movement capsule wraps round its head.

`tools/knife_test.gd` checks the following, all passing:
- weapon switching, and no swinging mid-draw;
- the exact hit frames, and that ooze sprays;
- swing buffering;
- the slash arc versus the stab cone, and reach;
- body and head stabs;
- backstabs, which only count from behind, not side-on;
- no hits or ooze through walls.

The clip `docs/video/knife_kill.mp4` shows it in action.

## Textures

`tools/make_textures.gd` paints 23 small pixel textures into `textures/` using only palette colours. World-mapped surfaces use 64 px per 2 m.

The script **never overwrites an existing PNG** unless you pass `-- --force`. You can repaint any texture by hand (Aseprite etc.) and rebuilds will keep your version.

Imports are set to lossless with mipmaps and nearest filtering, so pixels stay crisp.

## Rebuilding

Edit the layout constants at the top of `tools/build_shop.gd`, or the props in `tools/shop_decor.gd`. Don't edit `levels/shop/generated/`, because it's rebuilt every time. Then run:

```
godot --headless --path . --script res://tools/make_textures.gd   # paints only missing PNGs
godot --headless --path . --import                                # picks up new/changed PNGs
godot --headless --path . --script res://tools/build_shop.gd
godot --headless --path . --script res://tools/validate.gd
godot --headless --path . --fixed-fps 60 --script res://tools/movement_test.gd
godot --headless --path . --fixed-fps 60 --script res://tools/zombie_test.gd
godot --headless --path . --fixed-fps 60 --script res://tools/ooze_test.gd
godot --headless --path . --fixed-fps 60 --script res://tools/knife_test.gd
```

To rebuild the zombie after changing bones, weights or animations in `tools/build_zombie.gd`, run `godot --headless --path . --script res://tools/build_zombie.gd`.

To regenerate the screenshots in `docs/previews/`, run:

```
godot --path . --script res://tools/capture_previews.gd
```

## Colours and materials

`core/palette.gd` holds the nine palette colours and is the single source of truth. The builder writes one shared `StandardMaterial3D` per surface type into `materials/`. Only lamps, light panels, screens and the fridge glass emit light; painted teal never does. The interiors are lit warm by amber lights, and the exterior is cool moonlight with amber lane lamps.

`export/shop_greybox.glb` is the same geometry for Blender or other tools. It contains no gameplay nodes or collision.

## Numbers

- About 12,500 triangles for the whole decorated site, with 18 lights. Shadows are only on the room and lane lights.
- Collision uses simple box shapes, not trimesh.

## Not done yet

- No customers, deliveries, stock, economy or waves. Zombies come one at a time on a timer or with the Z key.
- The delivery door is a closed `StaticBody3D`, hinged at its west edge so it can be animated open later.
- The player uses the existing capsule/camera controller with visible pistol, knife and Crop Duster viewmodels. The camera near clip is 0.01.
- The upgraded "redneck fortress" exterior isn't built yet. The concept's neon, floodlights, sandbag walls, fire barrels, plated windows and spikes are a natural next tier.
- There's no monster truck at the hatch.
- The Shambler's rig is automatic and its animations are hand-keyed in code. They read well at game distance, but an animator pass in Blender would add polish, especially to the death and climb. Because the normal arm and the shirt are one continuous surface, lifting that arm high still stretches the armpit a little, so the clips keep it below about 65°.
- The previews were rendered with the Compatibility renderer under a virtual display. The project's default is Forward+, so lighting on your machine will look somewhat different (generally richer).


## Desktop performance limits

Ordinary play is capped at 60 FPS with VSync requested, dropping to 15 FPS when the application loses focus. Physics/gameplay continues at its existing rate. Headless test scenes lift the display cap so simulation tests stay fast. Knife poses are applied once per update; a redundant second AnimationPlayer evaluation was removed.

For a bounded rendered check, run `godot --path . --rendering-method gl_compatibility --script res://tools/performance_check.gd`. It caps itself at 30 FPS, profiles the pistol/shop, knife attacks, Crop Duster reload and a 12-zombie/ooze stress case, then exits; a 20-second watchdog also closes it if a check stalls. Set `FPS_PROFILE_OUTPUT` to save JSON. Results and limits are described in `docs/handover/PERFORMANCE_CHECK.md`.

The reference knife grip now has continuous teal glove coverage and an 18-degree resting roll to show the curled fingers. The roll eases into the authored stab pose at contact and returns during recovery. The original hand-to-knife attachment and gameplay timing remain intact.


## Current combined weapon build

The main loadout is now **1 pistol, 2 knife, 3 Crop Duster**, with number keys or the wheel to switch. LMB fires/slashes; RMB aims firearms or stabs with the knife. R reloads a firearm (and restarts after death); F inspects a firearm. The pistol has a 15-round magazine and 90 reserve rounds. Its existing custom model, moving slide and magazine are restored, with animated hands, reload, draw/holster, inspection, sounds and slide lockback when empty. Its original 34 body damage and headshot behaviour remain unchanged. The public low-level shoot() API remains available for the existing scripted hitscan tests; normal player input uses the gated request_fire().

The Crop Duster is a two-shot break-action weapon with 24 reserve shells. It uses its original mechanical reload animation and the new pack's shotgun hands. Shells seat at 1.9 and 2.4 seconds; the full reload takes 3.4 seconds. Interrupted reloads retain seated ammunition and never create extra rounds. Draw, firing, inspection and reversed-draw holstering are included; a pump cycle is deliberately not used for this break-action gun. Eight camera-centred pellets respect cover and zombie head hitboxes. Its game-view model is fitted at 0.65 scale; the original source dimensions/data are preserved.

Both firearms use the world renderer and the existing viewmodel depth technique, without another full-screen 3D viewport. The Crop Duster's game texture copies are 1024px instead of the source's 4096px, reducing measured video memory by about 120 MB in the bounded check. Original source files are retained. Build scripts: tools/build_pistol.gd and tools/build_crop_duster.gd. Source animation clips and licences are in addons/psx_firearms/. See docs/handover/CURRENT_BUILD_CHECK.md for verification and limits.

The Crop Duster has a further bulk/animation pass: broader sleeves and padded gloves, palm-relative support/shell anchors, queued reload after shot recovery, live-shell retention during top-ups, and a pose-preserving holster. See docs/handover/CROP_DUSTER_POLISH.md and docs/video/crop_duster.mp4. The supplied static gloved-hands model was used as a proportion reference; native animated hand geometry remains active.

The playtest now opens the animated main menu. Use Up/Down and Enter or the mouse; Start Cooking plays the bus cinematic, then loads the game. Continue is disabled until a save system exists. Settings changes volume/fullscreen for the current session. Menu artwork/video supplied by the project owner; details in docs/handover/MAIN_MENU.md.

### Claude additions now combined

This project also includes the Scuttler, recurring 11-second enemy spawns (every third a Scuttler), randomized lanes, next-enemy countdown, dropped glowing mushrooms with proximity collection and a mushroom counter, and Claude's sculpt-derived knife grip. Z spawns a Shambler; X spawns a Scuttler. The first automatic enemy arrives after three seconds. These were integrated from D:/zombys/versions/drivethru-main, retaining the current pistol, Crop Duster, menu and bus cinematic. Mushrooms are counted but not yet spent.

Serving room refreshed from the owner's concept and atlas: room-specific tile finishes, teal cabinets, stock/packaging and poster art. Builder/rebuild notes and validation: docs/handover/SERVING_ROOM.md.

Kitchen updated from the owner's two references and Kitchen_Texture_Pack.zip: stained tiles, steel cooking line, hood/utensils, labelled ingredient storage, teal fridge and sink. Live cooking and service mechanics retained. Builder/verification notes: docs/handover/KITCHEN.md.
