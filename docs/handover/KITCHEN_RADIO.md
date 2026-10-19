# Kitchen radio — 20 October 2026

A low-poly, weathered teal radio with orange controls sits on its own small shelf
above the topping counter at (4.4, 1.045, -4.5). It adds no movement collider and keeps
prep, grill, ingredient and fridge interactions clear.

Playlist order: Short Order Carnage, Locked Screen Door, The Skillet Vigil, repeat.
The three supplied MP3 files are copied unchanged into presentation/music/.
Only the current MP3 is loaded by the radio. The player finished signal advances
and wraps the playlist; individual-file loop flags are disabled.

E pauses/resumes the current track, preserving playback position. An amber power
marker darkens while off. The interaction prompt names the current song. The audio
source is a genuine AudioStreamPlayer3D with inverse-distance attenuation,
unit_size 2.5 m and max_distance 22 m, not a global soundtrack. Distant playback
also loses treble. No per-frame radio polling, additional shadows or dynamic lights.

Music has a separate bus and saved Kitchen radio music volume slider, default 65%.
Source gain is -9 dB. Master volume, focus mute and pause behaviour remain in effect.

Verification: all 23 suites passed, including radio_test.gd (playlist order/wrap,
source configuration, off/on state, independent volume and background mute).
The native capture_radio.gd reaches the radio using the real interaction ray,
presses E twice, verifies playback position while off and measures actual Music
bus audio at listener distances 1 m and 18 m. Measured RMS was 0.06931 nearby and
0.000728 far away. The settings panel fits at 1280x720. Both captures were inspected,
as were kitchen, serving room, pistol, knife and shotgun renders. MP3 SHA256 hashes
match the owner's three source files. Every changed/new GDScript passes check-only.

Counter dressing update: tools/kitchen_room.gd now replaces the six yellow bun
placeholders below the radio with two stacks of three thin cheese squares and
three overlapping tomato slices. Tomatoes have a skin rim, flesh, four seed
chambers, pale pith and seeds. Their natural red follows the owner-provided tomato
reference; cheese uses the shared amber palette. Both trays are merged into
Props_Kitchen with no additional movement collision. Rebuild via build_shop.gd;
render/inspect with capture_kitchen_toppings.gd.
