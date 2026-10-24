# Window entry damage

Climb and dive transitions previously cleared collision_layer as well as collision_mask. This removed the body from weapon ray queries during entry, while bone-attached head Areas remained hittable. Keep layer 8 enabled and suspend only movement collision (mask 0). Normal movement masks return at landing; death still clears damage collision.

Shambler, Hollowhead and Scientist share the climb implementation. Lancer and Scuttler have their own transitions and receive the same fix. Regression window_damage_test.gd exercises real entry transitions for all five types, body-only physics rays, the shared weapon ray, health loss and lethal damage before entry completes. Existing wall/board occlusion in Hitscan remains active.
