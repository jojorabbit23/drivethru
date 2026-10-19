# Gameplay audit — 19 October 2026

Baseline: a387fa2d46ec87de6a5044df2e1c77995d8956ab. Tested with official Godot 4.3 stable on Linux.

## Fixes

- A full enemy crowd used to decrement `_wave_left` even when `spawn_enemy` returned null. Pending enemies now wait for a later spawn tick. The cap and spawn interval remain unchanged. `tools/wave_capacity_test.gd` reproduced two failures before the fix and passes all four assertions afterwards, including spawning again when capacity is available.
- The pickup bob test sampled only one second of a ~2.86-second sine cycle with random phase, occasionally rejecting working motion. It now observes three seconds and requires at least 90% of the expected peak-to-peak excursion. Rotation is still measured over its original one-second interval. Five repeated pickup runs passed.

## Validation

Fresh import succeeded. All touched GDScript passed Godot 4.3 check-only parsing. Final full suite: validate, movement_test, zombie_test, ooze_test, knife_test, knife_viewmodel_test, spawn_test, scuttler_test, pickup_test, loop_test, lancer_test, and wave_capacity_test. Each returned exit 0 and reported zero failures/problems.

The documented headless dummy-renderer `Parameter "m" is null` messages remain; no GDScript runtime errors were reported by these tests.

## Limits

These are automated scenario checks, not proof of every possible playthrough or balanced long-term economy. Deliveries, traps and power-ups are not yet implemented on this baseline. README contains older superseded descriptions of some existing systems; use its burger-loop section and current scripts for current behaviour.

Rendering uses Mesa llvmpipe software graphics here, not the player's GPU. The stock 15-second performance watchdog expired after the initial shop scenario. Its hardware performance targets cannot be assessed on this environment. The committed watchdog has not been weakened. No audio device is available, so audible sound quality is unverified.

A temporary, uncommitted profiler copy with a 90-second watchdog completed all three rendered scenarios and exited 0. The captured knife/shop frame was visually inspected. Average draw calls were 637 (shop), 651 (knife), and 2,354 (12-zombie/ooze stress); reported primitives rose from ~46,828 to ~752,826. These are optimization leads, not a demonstrated target-PC frame-rate regression. Mean physics-process time stayed around 2.8–3.1 ms in those samples. Render/frame times from llvmpipe are unsuitable as player-GPU benchmarks. Run the original bounded profiler on target hardware before claiming 60 FPS.
