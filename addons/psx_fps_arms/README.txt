Version 1.0.2

Kitchen knife from fp_arms_free_v7 and the flashlight from fp_arms_flashlight (held as PSX Melee Weapons
holds it, no forearm past the hand) are selected automatically. Pistol and unarmed use the 1.0.1 sampler rig.
corrected-v7/ (the kitchen knife; its flashlight clips are superseded) and corrected-flashlight/ hold the
corrected GLB/FBX/OBJ/Blend. Original Unity package/raw formats remain 1.0.1.

PSX FPS Arms Free
=================

A pair of rigged PS1-style first-person arms with 27 animations: bare-handed, and with a pistol,
a kitchen knife and a flashlight, with the pistol's magazine and ammo, a steel target and a
training dummy. Taken from PSX FPS Arms (210 animations, a set for each of 35 weapons):
https://heyheythere.itch.io/psx-fps-arms
Low-poly, one 512x512 point-filtered texture atlas, the shading baked into vertex colours,
real-world scale (1 unit = 1 metre), 30 frames a second.

What's in the zip
-----------------
glb/        one file per prop, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per prop, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per prop, still (any 3D app)
textures/   atlas.png, the one texture every prop uses
icons/      an inventory icon per prop, 256x256 PNG with transparency
props.json  every prop: title, group, size, triangles, parts and animations, the arms' sets
blender/    every prop in one .blend, the atlas packed in
addons/     the Godot addon, psx_fps_arms/: this folder is a Godot 4.3+ project that opens on
            its gallery (.gdignore keeps Godot out of the other folders)

The arms
--------
fp_arms_free is one mesh skinned to one skeleton, its origin the eye (look down -Y, +Z up in Blender;
rotate its Godot scene 180 degrees around Y under your camera to face -Z). Its bones are root, and on each
side lowerarm_, hand_ and the fingers' index_01_ to pinky_03_ and thumb_01_ to thumb_03_ (_r, _l),
and weapon_r in the right hand: a weapon goes on it as it is, its origin in its grip and its
front the way the model faces, as every PSX Firearms and PSX Melee Weapons prop is made.

Its clips are in sets, each named for what it holds: unarmed_ (idle, draw, holster, punch_r,
punch_l, interact, pickup, throw, push, inspect), pistol_ (idle, draw, holster, fire, reload,
inspect), kitchen_knife_ (idle, draw, holster, stab, inspect) and flashlight_ (idle, draw,
holster, swing, switch, inspect). In props.json, fp_arms_free's "arms" has:
  bone            the bone a weapon goes on, weapon_r
  sets            per set: its "clips", and its "plays": an arms clip -> [the weapon's own clip,
                  from, to], to play on the weapon beside it, the clip's span (0 to 1) set to
                  the arms' (the pistol's slide kicks as the hand does)

Godot 4.3 and later
-------------------
For first-person models, set the camera near clip to 0.01 m and disable the held model colliders.

Copy addons/psx_fps_arms/ into your project's addons/ folder. Each prop is a scene in props/.
fp_arms_free contains a Skeleton3D and an AnimationPlayer: put it under your camera, a BoneAttachment3D
on weapon_r with the weapon under it. Cancel the imported bone rest axes on the weapon,
then play the set:

    arms.rotation_degrees.y = 180.0
    var skeleton = arms.find_child("Skeleton3D", true, false) as Skeleton3D
    pistol.transform = Transform3D(
        skeleton.get_bone_global_rest(skeleton.find_bone("weapon_r")).basis.inverse(), Vector3.ZERO)
    arms.get_node("AnimationPlayer").play("pistol_fire")
    pistol.get_node("AnimationPlayer").play("fire")      # its "plays"

demo/gallery.tscn shows every prop: drag to turn, arrows to browse, G for the range: WASD and the
mouse, left click to fire, swing or punch, right click to aim or use, R to reload, I to inspect,
the wheel or 1-9 to change sets, Esc to leave. demo/gallery.gd is how it equips, plays and fires
them (_socket and _follow). The props use one material, props.tres: the atlas times the vertex
colours, lit. For the full PS1 look (vertex snap, affine textures, 240p, dither), our PSX Look
shaders turn them over in one line: https://heyheythere.itch.io/psx-look

PSX FPS Arms uses the same addon folder: it installs over this one.

Other engines and apps
----------------------
Use fbx/ (the arms as a skinned mesh with its takes), glb/ or obj/ with textures/atlas.png. Set
the texture's filtering to nearest/point and turn off mipmaps for the crisp PS1 texels, and
multiply it by the vertex colours (the baked shading) in your material.

License: CC BY 4.0, see LICENSE.txt. Made by heyheythere: https://heyheythere.itch.io
