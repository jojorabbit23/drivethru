# Fridge room reskin

The supplied Fridge_Room_Texture_Pack is used for cream upper wall tiles, navy skirting, orange trim, shelving, cartons, timber crates, fungal stock and the hinged teal delivery door. Roughness, metallic and low-strength normal maps are wired into the new materials. Existing ceiling texture is retained from the kitchen finishes.

The supplied floor_charcoal/albedo.png is truncated and fails both Godot and Pillow decoding. Its original bytes are retained as albedo.png.source, excluded from import; the room instead uses the existing concrete albedo darkened to charcoal with the pack's floor normal/roughness/metallic maps.

Build via tools/build_shop.gd. Room finish and hanging-stock geometry live in tools/fridge_room.gd. Existing shelf and pallet footprints, collision, storage station, delivery-door hinge and interaction remain. Hanging stock is decorative low-poly geometry, not additional enemies or pickups. No new lights, particles or runtime processing were added. The supplied pack has textures only, not the detailed skull and limb meshes shown in the concept.

Four opposite-wall renders: tools/capture_fridge_room.gd, output docs/previews/fridge_room_{north,south,east,west}.png. Captured and visually inspected using Vulkan Mobile.

Validation: import, parse checks for all four touched scripts, validate and all 26 regression suites pass. Lancer suite rerun after the builder completed (initial run overlapped regeneration); rerun reports 0 failures. Required kitchen, service room, pistol, knife and shotgun Vulkan captures rendered and inspected.
