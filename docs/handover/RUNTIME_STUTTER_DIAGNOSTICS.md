# Runtime stutter diagnostics

The owner reports that the display-pacing change did not resolve stutter, including
mouse/menu input. Clicking inside the window does not resolve it. Do not describe
8179007 as a confirmed fix for their issue. Native short tests still show about
165 FPS on the title, so a sample of the affected interactive session is needed.

An opt-in CanvasLayer autoload activates only with user argument
`-- --frame-diagnostics`. Ordinary launch and tests leave it inactive.
F3 toggles its non-interactive timing overlay. It continues sampling while paused.
Every five seconds it writes wall-clock FPS, p95/worst frame intervals, foreground
state, FPS cap, VSync mode, current scene, physics time and draw count to
`user://frame_diagnostics.jsonl`. The file is overwritten each diagnostic run;
read/copy the affected run before launching another diagnostic session. No settings
or game rules are changed, and OBS is left alone.

Local launcher: outputs/Diagnose_DriveThru.cmd (beside Play_DriveThru.cmd, outside
the project repository). It invokes the regular main scene with the extra user
argument, so saved settings and interactive focus handling are preserved. Do not
replace it with a --script wrapper, which bypasses some interactive behavior.

Verification: touched script parses, native opt-in logging captures two title
samples at ~165 FPS with p95 ~6.12 ms; overlay rendered and visually inspected.
The complete existing 24-suite regression runner is used. The owner test sample
is pending; no further performance fix is claimed in this diagnostic change.
