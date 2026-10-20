# Display pacing — 2026-10-20

The owner reported jank in both the title and gameplay through Play_DriveThru.cmd.
The canonical launcher and saved balanced shadow settings were correct. OBS was
open but the owner confirmed it was not recording; it was left alone.

The local monitor reports 165 Hz. The former 60 FPS software limiter, together
with VSync, gave menu frame intervals of 15.727–17.681 ms (5th–95th percentiles).
Removing the second limiter gave 5.363–6.789 ms in the same exploratory run.
A 55 FPS cap and disabling VSync did not improve the software pacing spread.

## Change

Foreground rendering now follows VSync (project max_fps=0, VSync still enabled).
Menu start, scene handoff and focus recovery use the project setting rather than
hardcoding 60. Background cap remains 15 FPS and background videos stay paused.
The 720p render/decode budget, balanced shadows and physics tick rate are retained.
The supplied movie itself remains 24 FPS; rendering it faster cannot create new
movie frames. Driver-forced disabled VSync can override this pacing policy.

## Native measurements, RTX 3060 Ti / 165 Hz

Normal shader-cache access, 1280x720 Compatibility renderer:

| Scenario | After frame p95 | After worst |
| --- | ---: | ---: |
| Menu intro | 6.113 ms | 6.141 ms |
| Waiting bun | 6.120 ms | 6.160 ms |
| Start cinematic | 6.127 ms | 6.141 ms |
| Pistol/shop | 6.096 ms | 12.121 ms |
| Knife/actions | 6.102 ms | 12.111 ms |
| Sawn-off reload | 6.100 ms | 11.605 ms |
| 12 zombies / ooze | 12.148 ms | 19.955 ms |

Before, the three menu stages had p95 around 17.5 ms. A separate pre-change
120 FPS gameplay profile showed render GPU means of 1.4–2.3 ms, so sustained GPU
exhaustion was not reproduced. The stress case still has isolated hitches; this
short check is not proof that every reported stutter is resolved.

Reproduce normal display pacing with FPS_PROFILE_VSYNC=1 and
res://tools/performance_check.gd; optional FPS_PROFILE_OUTPUT writes JSON.
menu_performance_check.gd checks all three video states and focus pause/resume;
it now has a watchdog so a failed assertion cannot leave a benchmark open.
All 24 suites, import and touched-script parse checks pass. Required room/weapon
captures were rendered and inspected; gameplay and assets were not changed.
