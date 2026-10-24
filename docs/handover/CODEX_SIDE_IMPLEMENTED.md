# Codex side — original sawn-off, ambience and kitchen visuals

19 October 2026. This work targets the original Crop Duster: the two-shot break-action sawn-off in slot 3, sourced from Crop_Duster_Rigged_Textured.glb. No newer Claude-added shotgun was edited. No cooking/customer, economy or player inventory logic was changed.

## Sawn-off

The loading glove now turns fingers down and reaches over the open chambers. The fetch pose stays in view. The sleeve extends toward the lower-left screen edge during the raised reach, keeping the wrist attached without altering grip/finger geometry. Both shell insertions still occur at 1.9 / 2.4 seconds. Unfired shells, partial reloads, queued reload input and interrupted reload accounting retain their behavior.

The firing pose now adds 0.105 m of local pullback, a small lift and 0.18 radians of pitch at peak recoil, returning over roughly a quarter second. Hip/ADS input and gameplay aim remain camera-centered. Eight reused low-poly vapor puffs fade away after a shot; there is no unbounded particle spawning.

Pellet damage is 22 instead of 16 (+37.5%). Eight pellets, the 3.5-degree cone, falloff, 40 m reach, 0.42-second firing gate, magazine/reserve capacity and reload duration remain. A centered close-range test kills a full-health Shambler and Scuttler. This does not guarantee a kill from a glancing hit or at range.

The report has a fuller crack, low-frequency body and short tail. Three fixed shot voices let tails overlap; the mechanism has its own quieter player so opening the action does not cut a shot off. All respect Effects/Master settings and the limiter.

## Distant ambience

A quiet exterior drone and one distant-moaning voice use the Ambience bus. Moans alternate among exterior positions, every 12–20 seconds. This is separate from nearby enemy attack cues and does not change AI. Pause/background mute continue to apply.

The eleven longer WAV files are generated offline by `tools/build_presentation_audio.gd`; the sound library loads them instead of synthesizing their first playback during gameplay. Rebuild that tool and import after changing their synthesis code.

## Grinder and bin — ready for Claude integration

Both visuals are added by `presentation/kitchen/visuals.gd`, hosted under Player/Presentation/KitchenPresentation. They have no E-input handler and perform no inventory transaction.

- Grinder world position: (5.42, 0.95, -0.42), yaw PI. It sits on the kitchen sink/prep counter with its own receiving tray. Group: `mushroom_grinder`.
- Bin world position: (5.72, 0.0, -1.25). Group: `cold_burger_bin_visual`. It has player-clip collision; both kitchen doors and the breach window remain clear.
- Grinder call: `play_deposit(count: int = 1) -> bool`. It returns false for zero/negative counts or while busy. A valid request plays one bounded 1.95-second cosmetic cycle: input caps descend, the crank rotates, mince falls into the receiving tray, and a short grinding sound plays. It emits `visual_finished` and stops processing at completion. Count does not create stock or decide yield.
- Claude should call the grinder once after a successful deposit transaction. Resolve busy input at the station (disable/retry/queue there) so a rejected visual request never becomes a duplicate or lost inventory transaction. Do not count pellets to infer stock.
- Existing storage interaction is still in the storeroom. The new grinder is staged in the kitchen as a visual prop. Claude must choose whether the deposit interaction moves to the kitchen or how it connects; Codex has not moved or replaced it independently.
- **Integrated (Claude, 24 Oct 2026):** the storeroom bin stays; `game/grinder_station.gd` adds a second drop-off zone on the grinder (main.gd `grinder_station`). Busy policy: the grinder station refuses E while `busy` (prompt GRINDING...), so one deposit = one cycle; the storeroom bin always stores and plays the grinder only if free. Covered by `tools/grinder_test.gd`.
- Claude owns bin cold-only disposal, fridge storage, burger freshness, carrying upgrades and order quantities. Add its station area/prompt using the visual anchor; do not instantiate a second bin or grinder.

## Verification

All 84 owned scripts parse. All 15 suites pass: existing validation/movement/enemy/ooze/knife/spawn/pickup/cooking/pistol/shotgun/menu/presentation checks, plus the new kitchen visual test. The expanded shotgun test checks actual shell contact, above-chamber palm position, visibility across 69 reload samples, close-range results on both enemy types, and the fixed vapor pool/clearance. Visual tests cover empty/busy deposits, completion and node reuse.

Native captures cover both insertions, the fetch, firing/ADS/holster, grinder input/output placement and bin clearance. `docs/video/sawn_off_updated.mp4` is a short native recording with game audio. Required knife captures were also rendered and inspected. `sawn_off_performance.json` is the final bounded 30 FPS performance sample; it is not a sustained-60-FPS guarantee.

## Shared file boundaries

Changes are confined to the original `weapons/crop_duster/`, `presentation/`, relevant capture/build/tests and handover media. `game/`, `main.gd`, `player/player.gd`, `player/player.tscn`, the generated shop and other weapons are untouched. Existing scripts preloading presentation continue to work. Merge these files, retain Claude's gameplay changes, then run the complete suite against the combined result. The local playtest is the last integrated cooking baseline, not an assertion that unmerged Claude work is included.

Final isolated profile: p95 frame times 34.31–34.93 ms at the deliberate 30 FPS cap; worst sampled frame 41.98 ms. No other game renderer was running during this final sample.
