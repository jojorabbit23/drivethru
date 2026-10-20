# Owner room posters

- First supplied image: kitchen_misery_sermon.png, mounted beside the kitchen's
  rear doorway and clear of the ingredient rack. Original 1079:1457 proportions.
- Second: service_yeasty_pinup.png, on the service-room back wall beside the office
  door. Original 2:3 proportions.
- Third: service_last_selection.png, beside the pin-up. Original square proportions.

All source PNGs are byte-for-byte copies of the owner files. Dark thin frames,
normal room lighting, nearest/mipmapped texture sampling. Existing wall posters,
recipes, doors, stations and collision are preserved; no extra lights or colliders.

Builder sources: tools/kitchen_room.gd and tools/serving_room.gd. Rebuild with
res://tools/build_shop.gd, not by editing generated scenes/materials. Regenerated
shop scene, material files and export GLB included. Original art is in art/posters/.

All 26 suites, import and touched-script parsing pass. Native Vulkan close-ups of
both rooms checked for readable lettering, correct aspect, no clipping/overlap.
Required room and weapon captures rendered and inspected. Restart the existing
Try_DriveThru_Vulkan.cmd launcher to load this version.
