# The Drive Thru — greybox prototype

Godot 4.3+ project. Open `project.godot` and press **F5** to walk around the shop.

**Controls:** WASD move · Shift sprint · Space jump · LMB shoot (placeholder pistol) · hold E at a window to repair · Z spawn a zombie · R restart · L show/hide room labels · Esc free the mouse (click to recapture)

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
- The player is a plain capsule with a camera and an invisible placeholder pistol. The PSX arms pack hasn't been wired in. `Head/Camera3D` is where it goes; the near clip is already 0.01 to suit it.
- The upgraded "redneck fortress" exterior isn't built yet. The concept's neon, floodlights, sandbag walls, fire barrels, plated windows and spikes are a natural next tier.
- There's no monster truck at the hatch.
- The Shambler's rig is automatic and its animations are hand-keyed in code. They read well at game distance, but an animator pass in Blender would add polish, especially to the death and climb. Because the normal arm and the shirt are one continuous surface, lifting that arm high still stretches the armpit a little, so the clips keep it below about 65°.
- The previews were rendered with the Compatibility renderer under a virtual display. The project's default is Forward+, so lighting on your machine will look somewhat different (generally richer).
