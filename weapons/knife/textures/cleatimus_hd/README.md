# Cleatimus — detailed FPS hand textures

New material artwork with cracked teal glove leather, orange woven bomber fabric, dark ribbed cuffs, weathered skin, worn metal and a fixed 4:20 watch. Existing low-poly geometry stays unchanged.

## Contents
- hands_basecolor.png: 1774×887 atlas, same normalised 4×2 tile layout as our customised FPS pack.
- hands_roughness.png: authored grayscale roughness, with subtle variation inferred from base colour. This is an approximate artistic map, not measured or scanned PBR data.
- hands_hd.tres: Godot 4 material, linear filtering with mipmaps, vertex-colour shading and roughness map.
- tiles/: eight individual material tiles, exported for reuse.

## Use
Copy this folder into your Godot project, keeping the .tres beside its textures. Assign hands_hd.tres to the customised FPS arm meshes and watch components. They use DriveThru_Custom_FPS_Pack.zip's modified UV layout. There is no automatic modification of existing GLBs in this download.

This does not fit the original unmodified FPS pack or the full-body Cleatimus model without UV work. The skin tile supplies skin surface texture; fingernails and glove openings still depend on the mesh and its UV/material assignments. Fabric seams and padding shapes are not added by a texture.

The watch occupies the same final atlas tile and still reads 4:20, although the new artwork's border proportions differ slightly. Check watch placement and textured fingers in-engine. No in-engine test has been performed here. No normal map is supplied; fine surface texture comes from base colour and roughness. The generated texture includes some baked-looking shading, so it is an art-directed upgrade rather than a calibrated PBR scan.

The complete atlas also includes colours used by the matching pistol. Using this atlas on it will reuse the leather tile on teal frame regions; use a separate gun material if you want distinct polymer.

For low-end targets, make a smaller import variant if required, and profile memory. Texture detail increases without adding mesh triangles. Keep mipmaps enabled to reduce shimmer. Use nearest filtering only if you deliberately want the coarser pixel look.

Compatible mesh base credit: PSX FPS Arms Free by heyheythere — https://heyheythere.itch.io/psx-fps-arms-free — CC BY 4.0. Retain that credit with distributed meshes.
