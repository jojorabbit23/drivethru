# Credits

## Third-party assets

PSX FPS Arms Free by heyheythere - https://heyheythere.itch.io/psx-fps-arms-free - CC BY 4.0

First-person arms on every weapon: "Animated AKs-74u" by Vlasov Daniil (https://sketchfab.com/dan741vlasov) - https://sketchfab.com/3d-models/animated-aks-74u-34220aaa62e44b34b7d5ac30701f2b5f - CC BY 4.0. Modified for The Drive Thru: recoloured to the game palette, decimated (20,476 to 6,308 triangles), textures downscaled; the arms are re-posed in game by IK. The same file, gun included, is the purchasable SMG's viewmodel with its own animations (weapons/smg/). File: weapons/fps_arms/source/aks74u_hands.glb.

Handgun arms (pistol, Desert Eagle): "Pistol 43 Tactical | FPS Animations" by Vlasov Daniil (https://sketchfab.com/dan741vlasov) - https://sketchfab.com/3d-models/pistol-43-tactical-fps-animations-1a4c9d15818a4522aedbeb70919a17da - published as CC BY 4.0. Modified for The Drive Thru: recoloured to the game palette, Glock bind scale fixed, emissive sights removed, decimated (9,299 to 5,017 triangles); Glock not used in game. File: weapons/fps_arms/source/pistol43_hands.glb. Note: the arm textures in the download are named "BF3_Tex_…", which suggests they may originate from Battlefield 3; used at the owner's direction.

The source pack and its complete licence are kept in `addons/psx_fps_arms/`. Project adaptations: a palette atlas copy, orange sleeves, charcoal cuffs, teal fingerless gloves, dirty fingertips, left-wrist 4:20 watch, viewmodel materials and knife attachment. The original atlas and corrected knife rig remain unchanged.

## Project assets

- Survivor pump-shotgun skin, Lancer, armoured truck and pixel lettering sheet: supplied by the project owner. Pump hands also adapt PSX Firearms Free, credited below.

- Shambler zombie and survival knife models: supplied by the project owner (`enemies/shambler/source/`, `weapons/knife/source/`).
- Shop, textures, rig, animations, ooze and tools: made for this project.

- Cleatimus HD hand material atlas and roughness: supplied by the project owner; mapped onto the PSX arms, sleeves and watch. Source images and pack README retained under weapons/knife/textures/cleatimus_hd/.

PSX Firearms Free by heyheythere - https://heyheythere.itch.io/psx-firearms-free - CC BY 4.0

The supplied pack and full licence are retained in addons/psx_firearms/. Adaptations use its pistol/shotgun hands and animation hierarchy, remove its weapon geometry, apply the project HD glove/sleeve textures, and fit the project owner's custom pistol and Crop Duster. Crop Duster breech textures and 1024px game-view texture copies are derived from the owner-supplied model; its source remains intact. The custom pistol and synthetic audio are restored from the earlier project FPS prototype.

- Main menu lettering and zombie/burger intro clips: supplied by the project owner. Menu uses cropped atlas regions of the supplied overlay; video editing/alignment and final-frame hovering loop prepared for this project.

- Scuttler, mushroom pickup, armoured school bus and sculpted knife/dagger hand: owner-supplied models; latest source and build tools integrated from GitHub main fefcb797.

- Serving-room reference and material/poster/packaging atlas: supplied by the project owner, kept in art/serving_room/. UV cell extraction, room construction and integration prepared for this game.

- Serving_Room_Texture_Pack.zip: owner-supplied individual PNG textures; source README and native images retained in art/serving_room/pack/.

- Kitchen_Texture_Pack.zip and two kitchen references: supplied by the project owner, kept in art/kitchen/. All 16 base-colour textures are used directly; kitchen layout/material integration prepared for this game.

Current pistol integration: the original textured pistol mesh is fitted to the newer sculpt-derived hands and wrist sockets from OpenCode, using PSX FPS Arms Free animated pistol nodes. Source models and licences remain intact.

Kitchen radio music: Short Order Carnage, Locked Screen Door and The Skillet Vigil — tracks supplied by the project owner.

Rugged off-road customer truck: model supplied by the project owner (rugged off-road truck 3d model.glb). Cube driver and tracking behaviour created for this project.

Sawn-off blast: explosive_shotgun_ear_ringing.wav supplied by the project owner; opening impact deepened for the game.

Radio broadcast 01: audio from 2026-10-20 01-08-28.mp4 supplied by the project owner.

Health bottle: blue beer bottle 3d model.glb supplied by the project owner; source retained in pickups/health/source/.

Hollowhead: low-poly monster 3d model.glb and enemy profile supplied by the project owner. Static source retained in enemies/hollowhead/source/. Rig, retargeted project enemy animations, slam, clicking audio and behaviour prepared for this game.

Three framed room posters supplied by the project owner: Low-poly fungal apocalypse monster (kitchen), Retro low-poly fungal pin-up poster and Chapter 3: The Last Selection (service room). Original PNGs retained unchanged in art/posters/.

Morel drivers kitchen poster: owner-supplied artwork, lightly weathered with the built-in image generation tool (faded edges, paper grain, fold creases and restrained grease marks).

Fungal stock: owner-supplied carved wooden logs 3d model.glb, locally separated into six arrangements with original texture and UVs retained.

Decorative empty bottles: owner-supplied glass bottle.glb. Glass break sound synthesized locally.

Non-morel zombie drops: owner-supplied mushroom 3d model.glb, six intact components retaining supplied textures.

Owner-supplied stylized pistol model: supplied for The Drive Thru by the project owner; original retained in weapons/pistol/source/stylized_pistol.glb. Mechanical part rig and hidden magazine/receiver geometry added locally. Existing PSX FPS Arms Free credit remains applicable to the hand setup.

Owner-supplied mushroom-headed scientist model: original retained in enemies/scientist/source/scientist.glb. Local skeleton, skinning, retargeted infected clips, detachable-head setup and generated fungal sound effects added for The Drive Thru. Existing source animation credits remain applicable.

Garage motorcycle: owner-supplied "stylized motorcycle 3d model.glb", retained in props/motorcycle/source/motorcycle.glb; supplied colours preserved, optimized for the garage prop.

Sawn-off sound selections: owner-supplied shotgun_sound_04.wav (fire), shotgun_sound_13.wav (shell insertion), shotgun_sound_14.wav (cock/open action), extracted from the owner-provided Shotgun sound (sound effect pack) video. Original split WAVs retained unchanged.

Historical pistol audio alternatives: owner-selected gun_103.wav and gun_105.wav from the Gentler Cleanup sound pack (retained, currently inactive).
Desert Eagle slide and shot: extracted from owner-supplied videoplayback.mp4; source retained under weapons/desert_eagle/audio/source/.
