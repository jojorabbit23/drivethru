# Lightweight lighting pass

Retunes the existing lights rather than adding new lamps: neutral warm-white overheads, shorter room ranges, slightly lower flat ambient and moonlight. Existing warm task lighting remains. Main.tscn holds ambient/moon settings; tools/build_shop.gd authors room lights and regenerates the scene.

Balanced mode still enables only the nearest two room/yard shadow lights, tracked every half second. Omni shadow maps now explicitly use dual paraboloid (two views) rather than six cubemap faces. Slight shadow blur, distance fading at 18m and shadow fading at 12m bound distant cost. Existing 2048 atlas and two directional splits remain. No SSAO, GI, volumetric fog, screen reflections, extra lights or new effects. Full shadows stays an optional higher-cost setting.

Native Vulkan Mobile captures in docs/previews/lighting_{kitchen,service,fridge}.png position the actor in the photographed room before applying the shadow budget, so room shadows are actually enabled. Images visually inspected for surface detail, readable worktops and shelf shadows.

One before/after diagnostic run (30 FPS cap, RTX 3060 Ti) observed GPU render mean/p95 in milliseconds:

| Scene | Before | After |
|---|---:|---:|
| Pistol/shop | 4.00 / 10.33 | 2.53 / 3.39 |
| Knife/attacks | 3.33 / 4.91 | 2.40 / 3.24 |
| Sawn-off reload | 6.00 / 8.23 | 2.89 / 4.60 |
| 12 zombies/ooze | 5.99 / 8.89 | 2.81 / 3.70 |

These are short local observations, not an FPS guarantee or an isolated benchmark of each individual lighting change; cache state and normal scene variation can affect comparisons. Raw measurements are saved alongside this note. The frame cap masks any theoretical maximum-FPS increase. Physics stress remains separate from GPU lighting cost.

Validation: all 27 regression suites and validate pass, including the two-nearest-shadow cap and explicit dual-paraboloid mode check. Touched scripts parsed. Required kitchen/service/pistol/knife/shotgun renders and three room lighting captures inspected.
