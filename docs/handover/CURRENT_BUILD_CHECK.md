# Combined game check — 19 October 2026

Current project: drivethru_knife/ (the folder name is historical). Play_DriveThru.cmd now opens this combined Godot 4.3 build, rather than the older separate FPS checkout. The previous launcher is retained as Play_Previous_FPS.cmd. All three weapons share one player/controller and renderer.

## Findings and fixes

- The knife checkout still had an invisible placeholder pistol, while the custom pistol lived in the earlier FPS project. Restored that custom model to slot 1 with the supplied PSX Firearms pistol hands, moving slide/magazine, finite ammo, reload, aim, inspect and draw/holster. Added a magazine body to its previous baseplate-only reload prop.
- Pistol player input respects the draw, fire and reload gates. Its original low-level shoot() scripted API and damage/hitscan behaviour remain available to the existing zombie/ooze tests. Magazine transfer occurs at 1.45 s of a 2.1 s reload. Reload cancellation before insertion preserves both ammo counts; after insertion it retains the seated ammo. Empty pistols lock the slide back.
- Crop Duster is slot 3. Its own mechanical reload is retained; the new pack's shotgun hand hierarchy is adapted to its fore-end and chambers. A procedural left-hand route follows the animated shell positions. Draw/fire/inspect use native pack clips; holster reverses draw. No pump cycle is added to a break-action weapon. Reload seats shells at 1.9/2.4 s and closes at 3.4 s. Full, partial, interrupted and low-reserve reloads are checked.
- R now reloads firearms instead of restarting the live game. It still restarts after death. HUD shows weapon/ammunition and documents 1/2/3, LMB, RMB, R and F. The existing movement, repair, spawning and knife systems are retained.
- All firearm viewmodels use the existing world renderer/depth approach, with no extra full-screen viewport, colliders or world shadow casting. Source pack weapon meshes are removed; only the custom pistol and Crop Duster are shown.
- The source Crop Duster embeds 4K maps. Generated game-view albedo/ORM copies are 1024px, leaving its original GLB untouched. Measured video memory fell from about 174 MB to 54 MB in the same bounded check (about 120 MB saved). Shell visibility now uses an existing shader uniform instead of creating a separate discard shader during reload; the measured reload frame-time spike disappeared in the subsequent run.

## Verification

Godot 4.3 import, check-only for edited/new GDScript, validate, movement, zombie, ooze, unchanged knife tests and knife-viewmodel tests passed. Dedicated firearm tests passed: pistol 19 checks; Crop Duster 18 checks. These cover action gates, ammunition accounting, interruptions, empty behaviour, solid cover/pellet hits, death, colliders and shadows. Existing zombie tests retain one-headshot/three-body-shot pistol behaviour.

Rendered and inspected pistol idle, aim, draw, fire, reload, inspect and empty poses; Crop Duster poses across its reload; and fresh knife captures/audit. docs/video/loadout_check.mp4 is a 16-second silent rendered demonstration of the three-weapon loadout; decoded pistol and shotgun frames were inspected as well. Capture/film tools pace themselves to avoid an uncapped offline render workload.

The bounded Compatibility performance check profiles pistol/shop, knife attacks, Crop Duster reload and 12 zombies/ooze at a deliberate 30 FPS cap. It also verifies 60 focused / 15 background FPS limits. With normal shader-cache access, the repeat run had frame-time p95 around 35 ms across stages, and a stress maximum of about 41 ms. Typical rendering CPU/GPU times were a few milliseconds. Video memory was approximately 52–54 MB; these are video-memory measurements, not total process RAM. Raw repeat results are in loadout_performance.json.

The restricted tool run could not write Godot's normal shader cache and showed first-use stress/compilation hitches. A cache-enabled first run and a fresh repeated launch were checked separately; the repeat was substantially smoother. This bounded 30 FPS test is not a claim of sustained uncapped/60 FPS performance on every machine.

## Remaining scope

These are adaptations of low-poly source hands with keyed rigid hand/forearm movement, not newly sculpted finger-by-finger animations. Reload poses were sampled and rendered, rather than proven free of every possible continuous mesh intersection. Reserve ammunition is finite; pickups/resupply are future gameplay work. The new static dagger-hand GLB from the separate Claude handoff is not integrated here.
