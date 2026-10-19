# Crop Duster follow-up: bulk and animation polish

The shotgun's sleeves/cuffs are now 40% wider across their section while preserving forearm length and animation-node transforms. Glove geometry adds up to 8 mm of outward padding around palms/knuckles; vertices in the inner 25 mm grip radius are preserved. This changes meshes in tools/build_crop_duster.gd rather than scaling hand nodes, so the weapon, attachments and ammunition keep their existing scale. Equal-position UV seam vertices receive equal offsets to avoid cracks. Other weapons are unchanged.

The supplied gloved hands 3d model.glb was rendered and inspected as a proportion reference. It contains two open hands in a single static mesh, without a skeleton or animations. The active shotgun retains the licensed animated hand meshes with the broader proportions; the new reference mesh has not been substituted or presented as rigged.

The gun is also fitted a little higher/forward within its native attachment to centre the stock grip in the right palm; its 0.65 scale is unchanged.

Animation corrections:
- A palm-local grip anchor follows the fore-end and each shell as the action rotates; the sleeve is directed toward the lower-left entry instead of simply inheriting the complete barrel tilt.
- Reload input during shot recovery is queued. Elapsed recovery time is excluded from the reload clock, preventing a skipped opening segment.
- A partial reload leaves an unfired shell seated and visits only chambers planned for fresh ammunition. Limited reserve skips the unavailable insertion. Existing 1.9/2.4 s transfers and 3.4 s reload duration remain intact.
- Mid-reload holstering freezes the current hand/mechanical pose and lowers the entire viewmodel. It no longer resets an open action to closed while still visible.
- The muzzle light follows whichever barrel fired.

Verification: all required import/game suites plus pistol/knife viewmodel checks pass. The Crop Duster suite now has 27 passing checks, including queued recovery timing, preserving an unfired shell, both palm-to-shell contacts and interrupted holster continuity. New/edited GDScript passes check-only.

Fresh Compatibility captures and the 9.5-second paced shotgun film were rendered and inspected. crop_bulk_comparison.png compares the previous geometry with the thicker version. docs/video/crop_duster.mp4 is the current detailed shotgun demonstration; the earlier combined loadout video predates this polish. Visual checks are sampled rather than a proof of every continuous mesh intersection.
