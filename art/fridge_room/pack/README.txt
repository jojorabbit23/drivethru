FRIDGE ROOM TEXTURE PACK v1
10 original procedural materials, 1024x1024 PNG, repeating UVs. Inspired by the approved concept; not extracted textures from the image.

Each folder: albedo (sRGB), normal_gl (OpenGL tangent-space), roughness (linear), metallic (linear). Grayscale roughness/metallic are separate maps.

Godot: StandardMaterial3D, albedo_texture, normal_enabled=true and normal_texture, roughness_texture with channel RED, metallic_texture with channel RED. Set scalar metallic=1 for metallic maps to take effect. Enable texture repeat. Use linear filtering with mipmaps; reduce normal scale to 0.3-0.6 for the low-poly style.

Wall tile repeat contains 4x4 tiles; floor 8x8. Start with 1 texture repeat per 2 metres for walls, 2 metres for floor. Teal door and orange pipes use painted materials. Use cream above navy wall skirting, with a narrow strip of orange ceramic (pipe material can substitute). Wood grain runs horizontally; rotate UVs for vertical planks.

Fungal material is a surface base for existing zombie-part meshes; this pack contains no models or UV unwraps. Hook rails, crates, labels, door hardware and limbs still need geometry. Directional grime, labels and frosting should be separate decals. Do not bake lighting into these textures.

All materials use periodic analytic detail. No directional lighting or perspective is baked in. Natural variation at the repeat seam is expected between adjacent pixels.
