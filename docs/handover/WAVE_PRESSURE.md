# Job B: wave pressure

Branch `qol-waves`, based on main c61673d. Orders, economy and customer scripts
are intentionally untouched. Job A can add its nodes at the end of `_ready()`;
Job B adds only BreachAlert there. Public hook: `main.is_rush_wave(n: int) -> bool`.
It is false for zero/negative waves, true for positive multiples of five.

## Tuning

- Waves 1–4 keep the original running enemy rotation and all introduction gates.
- Wave 7 onwards: +4 percentage points health and +2 points movement speed per
  wave, capped at +60% health / +25% speed. Wave 15 is +36% / +18%.
- Apply only to wave spawns before enemy `_ready()`, so health and navigation
  avoidance initialize correctly. Debug/manual spawns and source scenes stay base.
- From wave 7/10/13 replace approximately 25%/50%/75% of remaining Shambler
  slots with rotating Scuttlers, Scientists and Lancers. Existing specialist slots
  and Hollowheads remain. Disabled types and their introduction gates are respected.
  These are deterministic long-run shares, not quotas for each short wave.
- Wave sizes, 12-enemy live cap, cap retry and grouped window distribution remain.
- Dinner rush waves 5/10/15…: intervals are 80% of normal (25% higher arrival
  rate), `DINNER RUSH` banner, +10 seconds recovery after clearing. No extra bodies.
  Orders can use the hook independently; Job B does not create cars.

## Breach cues

`game/breach_alert.gd` observes live enemies at 10 Hz. All five enemy types share
BREACH state 1. First entry into a boarded window attack outside the camera
frustum creates an amber directional edge label for 3 seconds and a quiet, short
synthesized cue on Effects. Continuous attacks do not replay it; re-entries at the
same window have a 6-second cooldown. Multiple simultaneous windows share one
sound. Closed garage windows are excluded by the existing windows group gating.
The observer tracks only live enemies; there are no extra lights, shadow casters,
particles, per-enemy audio nodes or assets. The sound is generated once per scene.

## Verification and limits

`wave_flow_test.gd` exercises early rotation, stepped composition, caps, real
spawned health/speed for all five enemies, rush hook, pacing, cap retry and the
existing drive-thru checks. `breach_alert_test.gd` checks visibility, direction,
cooldown and cleanup. Native `capture_breach_alert.gd` shows the banner and pip.

Run `wave_flow_sim.gd -- 15 12`. It now fails if a wave never clears, spawn count
is wrong, enemies remain alive after the simulated kill, or the run times out.
Its invulnerable player applies lethal damage at age 12 seconds: this validates
wave lifecycle and damageability, **not human combat difficulty or cooking
throughput**. Job A + Job B need the agreed combined balance pass afterward.

Verified 26 October 2026: import, explicit check-only on all seven changed/new
scripts, validator + 44 test suites passed. Final `15 12` simulation:
15/15 waves, 300/300 spawns, max alive 4, no cap delays, 0 stuck, all enemies
cleared at 2082 simulated seconds. Native Vulkan mobile kitchen, serving room,
pistol, knife, pump and breach renders passed and were visually inspected.
Preview: `docs/previews/wave_breach_alert.png`.
