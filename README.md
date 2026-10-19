# The Drive Thru — greybox prototype

Godot 4.3+ project. Open `project.godot` and press **F5** to walk around the shop.

**Controls:** WASD move · Shift sprint · Space jump · 1 / 2 or mouse wheel switch weapon · LMB shoot (pistol) or slash (knife) · RMB stab (knife) · hold E at a window to repair · Z spawn a Shambler · X spawn a Scuttler · R restart · L show/hide room labels · Esc free the mouse (click to recapture)

Zombies come in waves: the first Shambler arrives 3 seconds after you start, then a new zombie every **11 seconds**. Every third one is a **Scuttler** (set `scuttler_every`, or 0 to turn them off). Each one comes down either the east lane (to Window A, in the kitchen) or the west lane (to Window B, in the back office), picked at random but never three in a row from the same side. The HUD (top right) counts down to the next one. Up to 12 can be alive at once; past that a spawn is skipped. Spawning stops when you die.

The settings are on the `Main` node in `main.tscn`, and are easy to tweak: `spawn_interval` (11), `first_zombie_delay` (3) and `max_zombies` (12).

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

## The burger loop

The designs are `docs/GAME_DESIGN.md` (the whole loop) and `docs/COOKING_DESIGN.md` (cooking). The aim is that the player thinks "what should I cook next?", not "why am I doing this animation again?". The grill cooks in the background while you defend; it's another front to keep an eye on.

**Kill → collect → store → grill → bag → serve → cash → buy → survive waves.** Look at a station and press **E**. Menus list numbered options: **1–4** picks one, **E** picks the first available.

| Station | Where | What E does |
|---|---|---|
| **Mushroom store** (`game/storage_bin.gd`) | storeroom, by the doorway | Stores everything you're carrying. The sign shows stock per kind. |
| **Grill** (`game/grill.gd`) | kitchen flat-top | Patty menu: **Common xN / Blue xN / Red xN / Cancel**. The patty goes on the first free slot. You can also scrape off a burnt patty. |
| **Prep bench** (`game/prep_bench.gd`) | left of the grill | One press: bun + topping + cooked patty = wrapped burger. It bags the ordered kind if one is ready, else the patty that's been waiting longest, else a burnt one as salvage. |
| **Drive-thru window** (`game/customer_window.gd`) | the service hatch | Serve the burger you're holding. |
| **Shop terminal** (`game/shop_terminal.gd`) | the back-office CRT | Ammo, supplies and grill upgrades. |

- **Mushroom kinds** are the livestock. Shamblers drop **common brown** (20% blue). Scuttlers drop **blue** (30% red). Pickups, carried counts, stock, patties and orders are all colour-coded with matching pixel icons.
- **Orders:** the armoured school bus pulls up, honks and shows a **pixel burger icon in its patty colour**, with no text: brown 55%, blue 30%, red 15%. It waits 50 s with a patience bar. A missed order costs nothing.
- **Grill states**, per slot: RAW (0–1 s, grey) → COOKING (1–6 s, sizzle, steam, %) → READY (6–18 s, golden, bell, tick icon, countdown) → BURNT (black, smoke, cross icon, a repeating alarm). Each patty also shows its kind's mushroom. No state relies on colour alone.
- **Quality** is set when you bag, by how long the patty sat READY. **Perfect** (≤ 4 s) pays $30 + $6, **Good** (≤ 8 s) $30 + $3, **Standard** $30. **Burnt salvage** pays $15 from any customer, so a mistake is recoverable. A burger of the wrong kind is refused.
- **Grill upgrades** (terminal): Starter 2 slots → **Reinforced** 3 ($90) → **Restaurant** 4 ($180) → **Apocalypse** 4 with a 20 s ready window ($300).
- **Supplies:** buns and toppings come in packs of 5 + 5 for $40 ($8 a burger, as designed). You start with 8 of each and 12 + 36 pistol rounds; ammo is 24 rounds for $12.
- **Cash:** $2 per kill. Pistol: 12-round magazine, 1.1 s reload, a reserve topped up at the terminal.
- **Waves:** wave *n* sends 4 + 2*n* enemies, one every max(5, 12 − *n*) s, then a 20 s break.
- **Auto-collect (F2):** pickups fly to you from anywhere.
- **HUD:** cash; per kind, carried (stored); buns and toppings; the burger you're holding (kind + quality); wave and ammo; prompts, menus and toasts such as "PERFECT +$36".
- **Art and sound:** icons are pixel art drawn in code from the palette (`game/icons.gd`). Sounds are synthesised in code (`game/sfx.gd`).

`tools/loop_test.gd` plays all of this headless. `tools/capture_loop.gd` renders `docs/previews/loop1..7*.png`, and `tools/film_loop.gd` films `docs/video/burger_loop.mp4`.

**Not yet:** the double and special (red + blue) burgers, the heated holding tray / prep station / bun dispenser / bell system upgrades, deliveries and the supply runner, traps and power-ups.

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

## The Scuttler (second enemy)

`enemies/scuttler/` is built from your `Mushroom_AllAround_Glow_1.glb`: the repainted cap colour plus the orange-spot glow map. The original is kept in `source/`. It's the brief's "fast small intruder": a mushroom on two boots.

**Model:** `tools/build_scuttler.gd` builds it:
- It's 1.05 m tall, with 10 bones: root, hips, body, cap, plus a thigh, shin and boot per leg. The legs hang off the hips, so the body and cap can squash and wobble without dragging them.
- **The right leg is rebuilt.** The sculpt has the right leg kicked back with the boot toe-down, and bending it into a stride tore the trousers and boot into spikes. The build swaps it for a mirror image of the planted left leg and smooths the right hip to match. Both legs go in as closed pieces tucked up into the belly, so a swinging leg never opens a gap at the hip.
- The legs use **inverse kinematics**. Each clip says where the ankles go and how the boots pitch, and the hip, knee and ankle angles are solved from that. Boots stay flat, the stance is symmetrical, and feet don't slide or sink.
- Each boot's direction is measured from its own vertices, not guessed.
- Skin weights: the cap is solid; the stalk bends smoothly from hips to body to cap; legs own only the trouser part, so the round belly never follows a swinging leg. A bone-colour render checks this.
- The mesh is watertight (checked at build time) and double-sided.
- There are 5 LOD levels, from 9,338 triangles down to about 330 at range.
- **Glow:** only your orange spots emit, using the glow map with multiply. Godot's default "add" mode made the whole creature glow white. These spots are the one deliberate exception to the "only light sources emit" rule: bioluminescent fungus.

**Animations:** 7 clips, authored in code and baked at 30 fps:
- `idle`: weight shifts, with the cap swaying a beat behind;
- `run`: a 0.36 s cycle with toe-off, heel strike and a bouncing, squashing body. Every curve in it is smooth through the loop, so there are no pops at plant or lift-off;
- `ram`: crouch, spring, and the cap smashes the board at 0.42 s;
- `dive`: the cap flattens and the boots tuck;
- `kick`: a hop-in dropkick, landing at 0.3 s;
- `flinch`;
- `death`: keels over sideways, kicks twice, goes still.

`docs/previews/scuttler_animations.png` shows them all.

**Behaviour** (`scuttler.gd`, same interface as the Shambler):
- **Lane:** sprints down the lane at 3.2 m/s.
- **Breach:** rams the boards with its cap, knocking them out **from the bottom**. A Shambler tears them from the top.
- **Dive:** as soon as **two neighbouring boards are gone**, it dives through with its cap squashed flat. It doesn't need the whole window open. If a Shambler has already opened a gap at the top, it dives straight through that without ramming.
- **Speed:** it's inside in about 5 s, against about 17 s for a Shambler.
- **Repair counters it:** repairs go back bottom-up, so they close its gap first. One ram takes 1.1 s, just slower than a 0.9 s repair, so holding E keeps a lone Scuttler out.
- **Hunt:** runs you down at 3.4 m/s, under your 6.5 m/s sprint.
- **Attack:** hops in and dropkicks your shins for 8 damage.
- **Health:** 55. The cap is the weak spot (×1.5 damage), and from eye height it covers the legs, so you'll usually hit it. Two pistol hits kill either way, as does a knife stab. A slash leaves it on 15. Every hit knocks it back.
- **Death:** the glowing spots fade out, and an ooze puddle spreads.
- **Size:** it's knee-high, so you aim down. A wide cap collision keeps the cap out of walls, and it steers round other zombies.

`tools/scuttler_test.gd` covers:
- both lanes to four hiding spots: ramming at 2.9 s, diving at 4.5 s, kicking you at 6 to 8 s;
- bottom-up ramming, and diving with two boards left;
- diving through a Shambler's top gap;
- repair holding it off;
- cap and body hits for the pistol and the knife, and knockback;
- the glow fading and the corpse not blocking;
- mixed crowds of 2 Scuttlers and 4 Shamblers at two spots.

It passed repeated runs. The clip `docs/video/scuttler_encounter.mp4` shows it in action.

## Mushroom drops

Every Shambler and Scuttler drops one glowing mushroom when it dies. The model is the owner's pixelated mushroom (`pickups/mushroom/source/pixelated_mushroom_3d_model.glb`), scaled to 0.34 m tall. `tools/build_pickup.gd` writes `pickups/mushroom/mushroom_pickup_mesh.res`, its material and textures.

- **Drop:** 0.6 s after the kill it pops out of the body in a little arc and lands hovering 0.42 m above the floor, a step to one side. It never lands inside a wall.
- **Look:** it spins (about one turn every 3.5 s) and bobs gently. It has a faint warm self-glow, a thin amber halo outlines it (`pickup_glow.gdshader`, an additive rim pass), and a small amber light pulses on the floor beneath it.
- **Pickup:** walk into it. Within 2.6 m, with nothing solid between you, it flies to you. Boards don't block it, so a mushroom dropped just outside a window can be pulled in from the repair spot; one under a sill rises over it first.
- **Count:** `player.mushrooms` (signal `mushrooms_changed`), shown on the HUD as `MUSHROOMS n`. Nothing spends them yet.
- **Script:** `pickups/mushroom/mushroom_pickup.gd` (`class_name MushroomPickup`). `main.drop_pickup(position)` drops one anywhere.

`tools/pickup_test.gd` checks both enemy types drop exactly one, that it floats, spins, bobs and glows, that it stays put while you're far away, that walking up collects it and updates the HUD, that one dropped outside a window can be pulled in, and that four at once are all collected. `docs/video/pickup.mp4` shows two kills, a close-up of a mushroom, and the pickup.

## The knife

`weapons/knife/` is built from your `knife_3d_model.glb`; the original is kept in `source/`.

**Model:** `tools/build_knife.gd` makes the weapon model:
- It works out the knife's own axes from its shape. The long axis is the length. The tip is the thin end, since the handle is chunkier. The spine is the thicker long edge, since the cutting edge is ground thin.
- It turns the knife tip-forward with the serrated spine up and scales it to 32 cm.
- The origin sits on the grip, which is where the PSX arms' `weapon_r` bone holds it.
- A `Tip` marker marks the point.
- The texture is reduced to a 512 px nearest-filtered map.
- It is simplified to about a third of the source triangles (9,680 → 3,264) and flat shaded, so it reads a little blocky like the voxel zombies (`tools/blocky_mesh.gd`).

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

**The right hand** is a sculpt, not the PSX hand. `tools/knife_hand_mesh.gd` derives it from the supplied `weapons/knife/source/reference_hand_with_dagger.glb` (left untouched): the fused dagger is cut away, the fist is fitted round *our* knife's handle, and the sleeve is lengthened to run off-screen. The viewmodel builder skins it to `hand_r` (fist) and `lowerarm_r` (sleeve), blended across the cuff, and drops the PSX right arm. The left arm and watch are still the PSX mesh. Like the knife, the hand is simplified (6,898 → 4,384 triangles) and flat shaded to match the zombies' blocky look. In every knife clip the PSX fingers and `weapon_r` never move relative to `hand_r`, so a fist that's rigid on the hand loses none of the source animation and can't drift off the handle.

The right forearm pivots about the sculpt's own wrist (the top of the cuff). It aims halfway between the authored elbow and the lower right of the view, 40 cm long. The sleeve is pre-bent at build time to that idle direction, so the skeleton adds at most about 26° of wrist bend (in the draw).

The native `kitchen_knife_draw`, `kitchen_knife_idle` and `kitchen_knife_stab` clips animate the arms. There is no supplied slash clip: the existing procedural sweep moves the complete rig while retaining its closed knife grip. Source stab frame 7 (full extension) maps to the existing 0.24-second contact; recovery ends at the original 0.72 seconds. Gameplay damage, reach, buffering, head stabs, backstabs, switching, wall blocking and ooze are unchanged.

`tools/build_knife_viewmodel.gd` generates `weapons/knife/knife_viewmodel.tscn`, its skinned recoloured mesh, material and a copy of the atlas. The arms rotate 180 degrees around Y; `GripOffset` cancels the imported socket rest axes and turns our -Z-facing knife into the pack's +Z convention. Original assets are preserved in `addons/psx_fps_arms/` with README, licence and credit in `CREDITS.md`. No pack knife or colliders are included in the active viewmodel.

The character recolour uses the shared HD tiles: orange sleeve, charcoal cuff, teal glove (the sculpt's fingers are gloved to match the reference shot), with the sculpt's own painted shading kept as vertex colour. A small watch follows the **left** forearm and always displays **4:20**. Its face reflects light rather than emitting it. The supplied Cleatimus HD base-colour and roughness atlases are now applied with mipmapped filtering. The older non-HD pack and WRAD textures remain unused. The elbow direction blends halfway between the original and outward poses; the resting grip is tilted 15 degrees more upright and rolled 18 degrees to show the blade's flat, easing to the native stab orientation at contact. The sculpted hand is built to face the camera after that turn.

Rebuild with `godot --headless --path . --script res://tools/build_knife_viewmodel.gd` after importing the source assets. `tools/inspect_knife_arms.gd` prints bones, clips and stab extension samples. `tools/knife_viewmodel_test.gd` checks the visual/gameplay interface alongside the unchanged `knife_test.gd`. Detailed transforms and validation are recorded in `docs/handover/KNIFE_HANDS.md`.

The knife, arms and watch all use the same view-space depth shrink (same screen position at a tenth of the depth), with shadow casting off. The required Compatibility renders, including the close-wall stab, are in `docs/previews/knife0_draw.png` through `knife7_stab_into_wall.png`. Run `tools/capture_knife.gd` to refresh them. Its optional `-- --audit` captures every source frame of draw/stab and 30 Hz slash samples; set `KNIFE_AUDIT_DIR` to choose the output folder.

**Alternative to compare (slot 3, key 3): DAGGER (alt hand).** This is the same knife gameplay script on a second viewmodel, `weapons/knife/dagger_viewmodel.tscn`. It keeps the sculpt's *own* dagger in its own hand: the fingers were sculpted round it, so nothing is cut or refitted, and the dagger keeps the sculpt's painted colours. The arm, sleeve, rig, wrist pre-bend and blocky treatment match the knife hand. Both are built by `tools/build_knife_viewmodel.gd`. Renders are `docs/previews/dagger*.png` (`capture_knife.gd -- --dagger`) and the film is `docs/video/dagger_kill.mp4` (`film_knife.gd -- --dagger`). To keep only one, delete the other node from `player/player.tscn`.

**Weapon switching:** `player.gd` collects every child of `Head/Camera3D` with `set_active()`. Slot 1 is the placeholder pistol, slot 2 is the knife and slot 3 is the dagger alternative; the HUD shows the current one, bottom right.

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
godot --headless --path . --fixed-fps 60 --script res://tools/spawn_test.gd
godot --headless --path . --fixed-fps 60 --script res://tools/scuttler_test.gd
godot --headless --path . --fixed-fps 60 --script res://tools/pickup_test.gd
```

To rebuild the mushroom pickup, run `godot --headless --path . --script res://tools/build_pickup.gd`. On a fresh checkout it first writes its textures; run `--import`, then run it again.

To rebuild the Scuttler after changing its bones, weights or clips, run `godot --headless --path . --script res://tools/build_scuttler.gd`.

To rebuild the zombie after changing bones, weights or animations in `tools/build_zombie.gd`, run `godot --headless --path . --script res://tools/build_zombie.gd`.

To regenerate the screenshots in `docs/previews/`, run:

```
godot --path . --script res://tools/capture_previews.gd
```

## Colours and materials

`core/palette.gd` holds the nine palette colours and is the single source of truth. The builder writes one shared `StandardMaterial3D` per surface type into `materials/`. Only lamps, light panels, screens and the fridge glass emit light; painted teal never does. The exceptions are the Scuttler's cap spots and the dropped mushrooms, which glow on purpose. The interiors are lit warm by amber lights, and the exterior is cool moonlight with amber lane lamps.

`export/shop_greybox.glb` is the same geometry for Blender or other tools. It contains no gameplay nodes or collision.

## Numbers

- About 12,500 triangles for the whole decorated site, with 18 lights. Shadows are only on the room and lane lights.
- Collision uses simple box shapes, not trimesh.

## Not done yet

- Deliveries, extra patty types, toppings, upgrades and traps are still to come (see the burger loop section). Zombies arrive on a steady 11 s clock rather than in escalating waves.
- The delivery door is a closed `StaticBody3D`, hinged at its west edge so it can be animated open later.
- The player is a plain capsule with a camera and an invisible placeholder pistol. The PSX arms pack hasn't been wired in. `Head/Camera3D` is where it goes; the near clip is already 0.01 to suit it.
- The upgraded "redneck fortress" exterior isn't built yet. The concept's neon, floodlights, sandbag walls, fire barrels, plated windows and spikes are a natural next tier.
- There's no monster truck at the hatch.
- The Shambler's rig is automatic and its animations are hand-keyed in code. They read well at game distance, but an animator pass in Blender would add polish, especially to the death and climb. Because the normal arm and the shirt are one continuous surface, lifting that arm high still stretches the armpit a little, so the clips keep it below about 65°.
- The previews were rendered with the Compatibility renderer under a virtual display. The project's default is Forward+, so lighting on your machine will look somewhat different (generally richer).


## Desktop performance limits

Ordinary play is capped at 60 FPS with VSync requested, dropping to 15 FPS when the application loses focus. Physics/gameplay continues at its existing rate. Headless test scenes lift the display cap so simulation tests stay fast. Knife poses are applied once per update; a redundant second AnimationPlayer evaluation was removed.

For a bounded rendered check, run `godot --path . --rendering-method gl_compatibility --script res://tools/performance_check.gd`. It caps itself at 30 FPS, profiles the shop, knife attacks and a 12-zombie/ooze stress case, then exits; a 15-second watchdog also closes it if a check stalls. Set `FPS_PROFILE_OUTPUT` to save JSON. Results and limits are described in `docs/handover/PERFORMANCE_CHECK.md`.

The reference knife grip now has continuous teal glove coverage and an 18-degree resting roll to show the curled fingers. The roll eases into the authored stab pose at contact and returns during recovery. The original hand-to-knife attachment and gameplay timing remain intact.
