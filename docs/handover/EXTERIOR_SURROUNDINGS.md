# Exterior surroundings

Owner references: first image establishes a roadside shop in a pine valley, subsequent north/east/south/west images are concept guidance. Original playable building, customer road, zombie approach lanes, garage and navigation remain in place.

## Implementation

- tools/build_exterior.gd deterministically builds levels/exterior/generated/surroundings.tscn. Rebuild headlessly with Godot 4.3; never hand-edit the scene.
- Near: 359 simple three-tier pines, 69 faceted boulders, 44 mushroom props in clusters and five box-built abandoned cars. Four shared authoring meshes are repeated and baked into one static surface per category, preserving batching without runtime work.
- Middle: orange-canopy petrol station with two teal pumps, small kiosk, two corrugated sheds, water tower with cross-braces and low-detail roadside poles/wires. All merged into one surface; FUEL is one additional label draw.
- Far: three rings of flat opaque forest silhouettes and continuous mountain ridge cards. No alpha textures or overdraw-heavy transparent billboards. Blue slate haze and a warm dusk sky give depth using the existing palette.
- Eight mesh batches plus the fuel label. No added lights, scripts, collision objects, animation or per-frame processing. All scenery and the sign cast no shadows. Terrain skirt reuses the existing ground texture with world triplanar mapping.
- Keep-clear envelope covers x -20..20, z -16..20 with additional prop-radius margins. The full customer road has a separate clear corridor. New scenery is outside these routes.
- main.tscn instances the separate scene and uses a dusk sky, lower-density blue haze and the existing single directional light. Kitchen/serving practical lights and shadow budgets remain unchanged.

## Validation

Import, check-only for touched scripts, validator and all 34 suites passed. exterior_test checks the static batch count, collision/light absence, shadow policy, placement envelopes, bounded population and all distance layers. Existing movement, spawning, garage and window-damage suites pass.

Native Vulkan capture_exterior.gd renders overhead, all four directions, kitchen window and hatch views; images reviewed. Standard indoor/weapon captures also rendered for lighting QA. benchmark_exterior.gd compares the same native 1280x720 view with scenery hidden/visible, uncapped and vsync off, after 60 warmup frames, recording 120 frame intervals. It is a short local rendering check, not a guarantee for all wave loads or other hardware. Final measurements are recorded below.

Final RTX 3060 Ti / mobile renderer sample: hidden median 0.820 ms / p95 0.927 ms / 399 draws; visible median 0.857 ms / p95 1.188 ms / 408 draws. No added shadow passes.
