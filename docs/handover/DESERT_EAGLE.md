# Two distinct pistols

The owner identified the gold stylized pistol as the Desert Eagle, requested higher damage and a shop purchase, and asked for the original teal pistol to return as the spawn weapon.

- Starter: TestGun, slot 1, original pistol_custom.glb geometry in the established Cleatimus hands, 34 damage, 12+36 rounds, original shot.wav.
- Desert Eagle: dynamically appended on purchase ($180), display name DESERT EAGLE, 60 damage, 7+21 rounds, 0.32 s fire interval, 1.4 s reload. Wheel to equip. Separate 14-round ammo packs cost $20. These are initial tuning values.
- Shop weapons page: starter ammo, sawn-off, pump, Eagle, Back. Numeric menu input supports 1–9 so key 5 reaches Back.
- New recording split: slide sample contains both opening/return clicks, plays when drawing (new rack clip) and at the actual reload rack. Shot sample is only firing audio. No global Sfx replacement.
- tools/build_pistol.gd now builds starter_pistol_viewmodel.tscn alongside the gold pistol_viewmodel.tscn; generated files remain builder-owned. Original pack gets an explicit RESET clip so cancelling reload restores the magazine/slide.

Tests cover initial loadout, insufficient funds, duplicate purchase, independent reserves, cooldown, reload timing/conservation, switching and menu key 5. Native check_eagle_audio.gd checks actual playback and captures the Effects bus to docs/previews/desert_eagle_audio.wav. capture_pistol_game.gd captures both guns and the shop.

Verification: import and all touched GDScript check-only passes; validator and all 33 suites pass. Native audio peaks: Eagle 0.8593, starter 0.2702 (unclipped). Native Vulkan captures reviewed for original starter idle/reload, Eagle idle/reload, expanded shop, and standard room/weapon captures.
