# Rare health bottle

Each zombie death independently rolls randf() < health_drop_chance (default 0.10)
once when the death is reported. A successful roll adds a bottle after the same
short drop delay as the mushroom; the ordinary mushroom is always preserved.
Shamblers, Scuttlers and Lancers all use this shared death path. It is a chance,
not a guaranteed drop every tenth kill.

Walking near a landed bottle collects it immediately for up to 50 HP. Health caps
at max_health; full-health players leave it available and dead players cannot be
revived. HUD health updates through the existing signal, +HP toast shows the actual
amount gained, and normal pickup feedback remains active. Nearby bottles follow
the same clear-line/window magnet rules as mushrooms; F2 auto-collect is respected.
Health bottles use a separate health_pickups group so cooking inventory and
mushroom accounting remain unchanged. There is no inventory item or drinking key.

Owner GLB source is preserved untouched. tools/build_health_bottle.gd produces a
0.38 m mesh (518 vertices) with the supplied blue texture reduced to 512 pixels
and mipmapped. Pickup spins/bobs and has a +50 HP label, without extra lights or
shadows. Use the Vulkan launcher confirmed smooth by the owner.

Verification: all 25 suites, import and touched-script checks. Health tests cover
exact/capped healing, no full-health waste, no double-use/revival, automatic
collection, all enemy death types, forced success/failure roll boundaries and
preserved mushrooms. Native Vulkan capture verifies automatic collection and
immediate HUD update. Bottle and required room/weapon renders were inspected.
