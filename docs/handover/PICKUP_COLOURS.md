# Mushroom pickup colour correction

The source textures were being washed out by overlapping pickup lights and white emission. Rebuilt the six intact variants with an unshaded textured material, preserving their supplied colour/detail in bright rooms and dark lanes. Reduced additive rim strength, light radius/energy and collection flash. Category IDs, spawning, movement and collection are unchanged.

Verified the six-variant native Vulkan render and an actual kitchen render (`pickup_colours_kitchen.png`). Updated the pickup visual assertion to require readable texture shading and a restrained glow rather than the previous excessive light energy. Full test results are recorded in the commit/PR.

Rebuild assets with tools/build_pickup_variants.gd; reproduce kitchen preview with tools/capture_pickup_colours.gd.
