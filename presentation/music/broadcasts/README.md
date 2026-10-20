# One-time kitchen radio broadcasts

Broadcast 01: audio extracted from the owner's 2026-10-20 01-08-28.mp4.
The video is not included. source/broadcast_01_original.m4a is a lossless AAC
stream extraction (no re-encoding); original/extracted encoded audio SHA256:
39d0d695b59c712724c09ef60ebf5b0f7a58deaadcd85770d7bbd876dcc6b63b
The source folder is excluded from Godot import/export with .gdignore.

broadcast_01.ogg is the playback version, encoded Vorbis q6 from the same audio.
No pitch shift, distortion, trimming, mixing or voice effects were applied.

Order: Short Order Carnage > Locked Screen Door > Broadcast 01 > The Skillet Vigil.
Later music loops skip Broadcast 01. History is per new game/run, retained while
switching the radio off/on. Off pauses the current broadcast; on resumes it.

Add future audio paths to BROADCASTS in game/kitchen_radio.gd. The radio selects
one unplayed broadcast after the second music track on each playlist cycle.
Each path can play at most once per run. New runs reset broadcast history.

Verification: radio_test.gd covers insertion before song 3, off/on resume, three
later playlist cycles without repeats and history count. Native capture_radio.gd
-- --broadcast checks the actual broadcast source, toggle/resume, third-track
handoff, no repeat on the next cycle, and measured positional audio fade.
Measured Music-bus RMS: 0.04269 at 1 m, 0.000460 at 18 m.
