# Desktop slowdown investigation

Godot 4.3 stable, Compatibility, 1280x720, NVIDIA RTX 3060 Ti. The reported game process was already closed; no leftover Godot instances were found. Its last runtime log contained no script errors, but the restricted launch could not create its shader cache.

## Changes

- Add an explicit 60 FPS display cap and request VSync. Previously, the project had no explicit maximum; actual load depended on driver/display settings. This was a likely contributor, not a measured uncapped-before/after root-cause proof.
- Limit rendering to 15 FPS when the application loses focus. Keep the existing physics/gameplay timing.
- Remove redundant `AnimationPlayer.advance(0)` after `seek(time, true)`, which already applies animation tracks. Visual/contact checks still pass.
- Keep headless simulations unrestricted so test commands do not wait on display pacing.
- Add `tools/performance_check.gd`: three short stages, capped at 30 FPS, automatic exit and a 15-second watchdog.

## Measurements

The capped rendered check closed normally. The native main-window focus handlers were exercised and confirmed 60 FPS focused / 15 background. The final check had normal access to Godot's local shader cache and logged no cache-write failure or script error. A captured knife frame was opened and inspected after the animation change.

| Stage | Mean frame ms | Frame p95 ms | Mean CPU render ms | Mean GPU render ms | Draw calls | Godot-tracked video MB |
|---|---:|---:|---:|---:|---:|---:|
| Shop / pistol | 33.38 | 34.68 | 1.53 | 1.36 | 640 | 24.48 |
| Knife idle / attacks | 33.35 | 34.61 | 1.45 | 2.25 | 650 | 24.48 |
| 12 zombies / ooze stress | 32.72 | 34.95 | 9.77 | 8.83 | 1369 | 26.90 |

These are a deliberately capped 30 FPS sample, not a maximum-FPS benchmark or a guarantee for every scene. The stress render-time query includes a one-off first-use spike (about 389 ms CPU / 177 ms GPU); its steady sample had p95 CPU-render 4.63 ms and GPU-render 8.18 ms. Cold shader/effect creation can still hitch. The frame timing sample begins after spawning/settling, so it does not claim to include the entire spawn/startup delay. Raw values are in `knife_performance.json`.

Ten headless create/free cycles found orphan-node counts `[0,0,0,0,0,0,0,0,0,0]`. Godot-tracked static allocation settled around 35,428,580 bytes after its initial load, with no continuing growth in the final cycles. These static/video counters are not total process working set or total system/GPU memory.

## Tests

Import and `--check-only` pass. Existing validate, movement, zombie, ooze and knife suites all end with `0 failure(s)` or `problems: 0`. The seven viewmodel checks pass. Knife damage, arcs, hit times, range, backstabs and weapon switching are unchanged.

One ooze run initially failed its directional majority check (9 droplets behind versus 10 in front). The effect randomizes its trajectories, making that one-shot assertion nondeterministic. The test now seeds the effect with 420; all assertions are retained, and three consecutive runs reproduce the same passing east/west counts. The gameplay effect is not reseeded or otherwise changed.

The game was closed after the bounded checks. No unrestricted render run was used to reproduce the slowdown.
