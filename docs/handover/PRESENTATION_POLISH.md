# Presentation polish — 19 October 2026

This pass changes presentation and player comfort. The cooking, recipes, customer interactions, economy, station actions and weapon damage/ammunition behavior are unchanged. No files under `game/`, `main.gd`, or `player/player.gd` were edited. Claude can continue those gameplay systems independently.

## What changed

- Kitchen walls, checker floor, ceiling and steel use the serving-room texture pack. The orange splatter atlas is no longer used for those large surfaces. Existing kitchen prop textures and all station footprints remain. Added twelve small clock marks for a readable dial.
- Scuttler cap emission reduced from 1.8 to 1.0; its existing death fade and animation remain.
- Quiet procedural footsteps for tiles, rubber mats and outdoor ground; landing, damage, board removal/repair, pickup and weapon-switch feedback. Spatial enemy attack/death cues. Two local fridge hums and a quiet outdoor air loop. Sounds are synthesized locally, cached, and transient voices are capped at eight and freed on completion. These are stylized synthesized cues, not recorded voice performances.
- Separate Effects, Ambience, Cinematics and UI buses, master limiter, menu selection/confirmation sounds. Existing weapon and cooking sounds route to Effects without changing their source scripts.
- Esc opens a real pause menu. World physics and timers pause; Resume gives the click time to expire before recapturing the mouse. Losing focus pauses actual gameplay, mutes audio by default, and requires an explicit resume. Automated capture scripts do not auto-pause on focus loss.
- Shared settings from title and pause: five volume controls, mouse sensitivity, fullscreen, optional damage camera roll, and background mute. Presentation preferences persist to `user://presentation.cfg`; this does not implement run saves and Continue stays disabled. Tools/headless checks do not overwrite player preferences.
- Compact outlined controls strip; F1 opens a separate controls panel below the status and announcements.

## Files and integration

`presentation/preferences.gd`, `presentation/audio_library.gd`, `presentation/world_feedback.gd`, and `presentation/pause_menu.gd` are self-contained. The last two are children in `player/player.tscn`. `ui/menu/menu.gd` uses the same settings and UI sounds. Kitchen and Scuttler edits are in their builders, with generated scenes/materials rebuilt normally.

Do not replace `player/player.tscn` wholesale while integrating gameplay work: retain the Presentation and PauseMenu children/resources. Do not put recipe/customer state in presentation preferences. Existing E and station option handling are unchanged.

## Verification

All 78 owned scripts pass check-only parsing. All 14 suites pass: validate, movement, zombie, ooze, knife, knife viewmodel, spawn, Scuttler, pickup, cooking loop, pistol, Crop Duster, menu, and the new presentation test. The presentation test checks configuration idempotence, limits, focus mute, cached bounded sound data, settings serialization, actual paused movement and resume.

Native Compatibility captures: kitchen cooking/sink/prep, title settings, controls, pause/settings, NPCs, and all knife action poses. The native presentation capture checks the eight-voice limit and that finished sounds are released. See `tools/capture_polish.gd` and `tools/capture_kitchen.gd`.

`polish_performance.json` records a bounded 30 FPS test on the local RTX 3060 Ti: p95 frame times 34.46–36.40 ms, maximum stress frame 45.46 ms, reported video memory 101.6–104.0 MiB. This is a short presentation regression check, not a guarantee of sustained 60 FPS or performance on other hardware. Audio sample peaks and lifetime are checked; subjective loudness can be adjusted separately in Settings.

Headless Godot's known `Parameter "m" is null` messages are harmless. Sandboxed native captures cannot write the shader cache; the performance run used normal cache access. An early source-encoding issue was fixed, affected checks were rerun, and final captures use valid UTF-8 scripts.
