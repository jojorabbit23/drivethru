# Menu and rendering performance pass

The owner reported severe lag even on the title screen in the Godot player.

Changes:

- Re-encode the same intro, waiting-bun and bus clips at 1280x720 (original 24 FPS
  pacing and audio retained), matching the game viewport. This decodes 56% fewer
  pixels per frame than 1920x1080. Combined clip size falls from about 10 MB to 5.6 MB.
- Run menu input/rendering at a 60 FPS target independently of the 24 FPS video.
  Pause video decoding while unfocused; resume it on return.
- Use viewport stretch so a larger/fullscreen window still renders at 1280x720.
  A native 1920x1080 window test verifies its actual viewport texture remains 720p.
- Balanced lighting defaults to the two nearest authored omni-light shadows and
  two sunlight cascades within 35 m. Update nearby-light selection twice per second.
  Lighting colours, energy, materials and gameplay remain unchanged. Full lighting
  shadows can be restored through title/pause settings. Positional atlas is 2048.
- Keep headless cooking alarm audio observable for the existing loop test; only
  synthetic pistol playback is skipped in headless mode.

Measurements on this machine, Godot 4.3 Compatibility, 1280x720, normal shader cache:

| Stage | CPU render mean before / after (ms) | Draw calls before / after |
| --- | --- | --- |
| Pistol / shop | 3.41 / 1.79 | 1047 / 700 |
| Knife | 3.28 / 1.73 | 1022 / 659 |
| Crop Duster reload | 4.38 / 1.89 | 1074 / 698 |
| 12 zombies / ooze | 8.21 / 3.39 | 1773 / 1035 |

The 120 FPS diagnostic cap (vsync disabled) exposes work hidden by the earlier
30 FPS profiling cap. Stress-stage p95 frame time improved from 16.89 to 12.09 ms.
Isolated worst-frame hitches remain (about 64 ms in the final stress run); this
does not prove every machine will maintain 60 FPS. The normal game stays capped
at 60 FPS, with 15 FPS while unfocused.

Native menu check exercised selection during intro, bun wait and bus playback:
p95 17.76-17.91 ms, worst 18.18 ms in the final check. Decode resolution and
background pause/resume were asserted. Fullscreen/window render budget was asserted.
All 21 suites pass (validate plus every tools/*test.gd), including the new shadow
budget regression. Room, pistol, pump, knife and menu captures were inspected.

Reproduce: tools/performance_check.gd with FPS_PROFILE_CAP=120 and
FPS_PROFILE_OUTPUT=<json path>; tools/menu_performance_check.gd with
MENU_PROFILE_OUTPUT=<json path>. FPS_PROFILE_NO_SHADOWS=1 is a diagnostic only,
not the shipped setting. Detailed baseline/final/menu values accompany this note.
