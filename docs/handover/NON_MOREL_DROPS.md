# Non-morel zombie drops

Owner source: pickups/mushroom/source/mushroom_pack.glb. The supplied pack contains nine designs arranged in three rows. All three left-column morels are excluded; the remaining six are used as two Common, two Blue and two Yellow drop variants.

Regenerate with tools/build_pickup_variants.gd. The builder welds coincident UV-seam vertices for topology analysis only, identifies nine complete connected mushrooms, and copies each selected component's original triangles, UVs and normals intact. No slicing across a cap or stem. Each mesh is centred for existing spin/bob behaviour, up to 0.34m tall and 0.48m wide. Six meshes share a 1024px texture material; runtime duplicates only the per-pickup material/halo.

mushroom_pickup.gd chooses one of two meshes for the existing kind. Source textures provide the category colours, without additional tinting. Yellow retains the legacy red identifier. Glow is restrained to keep texture details visible. Existing drop odds, mushroom value, cooking ingredients, flight, magnet collection, health-drop rules and no-shadow pickup policy are preserved.

Native preview: tools/capture_pickup_variants.gd creates actual randomized pickups, checks that both variants of each kind appear, and renders docs/previews/non_morel_pickups.png. All six models visually inspected against the source pack.

Validation: import and touched-script parse checks pass. All 27 regression suites plus validate pass, including a pickup suite rerun after tuning glow to remain visible throughout its pulse. Six runtime randomized models and required kitchen/service/pistol/knife/shotgun native Vulkan renders inspected.
