# Camera pacing and startup — 2026-10-20

Owner session evidence (saved outside the repository in work/owner_stutter_gameplay.jsonl):
normal gameplay rendered about 165 FPS, p95 ~6.5 ms, while reporting visible jank.
Scene entry stalled 2379 ms; occasional paused/menu stalls also occur. The title
sample began at 60 Hz, then gameplay reached 165 FPS. Neither sustained GPU
exhaustion nor background throttling explains these samples.

## First-person motion

The body and camera bob previously advanced together on 60 Hz physics ticks.
Rendering that transform at 165 Hz repeated the view between ticks. player.gd now
interpolates camera translation (body position and local bob) with the engine's
physics interpolation fraction. Live mouse aim/rotation and collision/game rules
remain at their original timing. The visual position trails by at most one physics
tick; this is deliberate interpolation, not a higher physics rate. External
teleports and corrections over 0.5 m snap; headless simulations keep their original
camera behavior. Death keeps the existing head-drop tween.

Native tools/camera_pacing_check.gd compares the old path (render processing off)
against interpolation at 165 FPS, holding the same walking input:

| 90 rendered frames | Before | After |
| --- | ---: | ---: |
| Repeated body positions | 57 | 57 |
| Repeated camera positions | 57 | 0 |
| Maximum camera/body X offset | 0.014 m | 0.077 m |

The native test also checks that teleports do not create a camera sweep.

## Startup

The menu requests the game PackedScene on a loader thread during the intro rather
than synchronously reading it at the end of the bus cinematic. Scene activation
waits for a completed resource; it never calls load_threaded_get on an unfinished
request. Headless menu tests retain their synchronous scene handoff. A normal
native check measured 2186 ms background loading and 516 ms remaining activation;
activation still does work on the main thread, so this does not eliminate every
startup hitch. This is not a directly controlled before/after loading benchmark.

## Verification and limits

Touched scripts parse; import succeeds. All 24 existing regression suites pass.
Native camera pacing and threaded menu handoff checks pass. Required kitchen,
serving room, pistol, knife and pump images were rendered and visually inspected.
The owner still needs to assess the result in their normal play session. The
24 FPS intro sources and isolated menu/pause stalls are not claimed resolved.
The opt-in F3/log diagnostics from PR #13 remain available.
