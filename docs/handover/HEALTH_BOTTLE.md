# Health bottle

Each zombie death independently rolls randf() < health_drop_chance (default 0.075, or 7.5%) once when death is reported. Success adds a bottle after the ordinary mushroom drop delay. The mushroom is always preserved, and all enemy types share this death path.

A landed bottle stays in place, spinning/bobbing with a +25 HP label. Look at it within the normal 2.3 m interaction reach and press E to immediately restore up to 25 HP. The existing station look-ray and HUD prompt are used; the bottle rechecks aim, range and world occlusion at use time. It cannot be used during its drop animation, through walls, by dead players, or when already taken. At full health it displays HEALTH FULL and remains available. Healing caps at max_health; the toast shows the actual amount gained.

Proximity, magnet movement and F2 auto-collect never consume or attract health bottles. Mushroom pickup behaviour is unchanged. Health bottles retain the separate health_pickups group and do not enter cooking inventory. Successful use clears focus before freeing the bottle, preventing a stale prompt reference.

Owner GLB source is preserved untouched. tools/build_health_bottle.gd produces the supplied blue bottle mesh; no extra lights or shadows are added.

Verification: tools/health_pickup_test.gd checks the 7.5% default, E input through the actual focus ray, 25 HP and capped healing, no full-health waste, no double-use/revival, no proximity/F2 collection, aim/range/wall rejection, all enemy death types, forced roll boundaries and preserved mushrooms. tools/capture_health_bottle.gd verifies the native E prompt, no proximity healing, 25 HP on E and immediate HUD update. Full regression suites and required native room/weapon renders also run before publication.
