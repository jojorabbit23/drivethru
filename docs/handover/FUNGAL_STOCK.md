# Fungal stock props

Owner source: carved wooden logs 3d model.glb, retained in props/fungal_stock/source/fungal_cuts.glb. Six distinct arrangements in a 3-by-2 grid are separated by the empty gaps between them. No triangles are cut or removed: the builder checks that all 7,658 source triangles are retained exactly once. Source normals and UVs are preserved. Each part is bottom-centred and scaled to a maximum dimension of 0.30 m. A shared 1024px texture material limits memory overhead.

Regenerate the six meshes and material using tools/build_fungal_stock.gd, then tools/build_shop.gd. Placement lives in tools/shop_decor.gd: decorative stock replaces a few cartons on existing shelves and sits on top-tier cartons and pallet crates. Instances share mesh resources, cast no additional shadows, and have no scripts, lights or colliders. Original room textures and gameplay remain.

Native Vulkan opposite-wall previews: docs/previews/fungal_stock_{north,south,east,west}.png. Inspected shelf and crate placements.

Validation: six-part triangle accounting passes; all 27 regression suites pass in the combined stock/bottle update. Final native shelf/crate renders inspected.
