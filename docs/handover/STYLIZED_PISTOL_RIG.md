# Stylized pistol rig

The owner's `stylized pistol 3d model.glb` was one textured mesh without animations. `tools/stylized_pistol_rig.gd` clips it into a stationary frame, moving slide, hinged hammer and removable magazine floor plate while preserving interpolated UVs/normals. The concealed magazine body, receiver and grip interior are added in charcoal. Source is retained at weapons/pistol/source/stylized_pistol.glb.

Build: run tools/build_pistol.gd. It retains the existing Cleatimus hand builder/socket fit and emits weapons/pistol/pistol_viewmodel.tscn for slot 1, plus standalone stylized_pistol_rig.tscn, stylized_*.res and stylized_albedo.png. Never edit these generated files directly. Existing original pistol source remains available.

Clips: RESET and idle seat all parts with the hammer cocked. Fire drops the hammer, cycles the slide, draws the hammer back and seats the slide over 0.22 seconds. Reload extracts the magazine, replaces it, then racks the slide; its 1.6-second authored clip is scaled to the existing 1.1-second gameplay reload. These are rigid mechanical node animations, not a deforming character skeleton.

The existing pistol damage, capacity, reserves, sound, purchase path and reload timing are retained. First-person reload raises/rolls the gun slightly and lowers/returns the support hand. Completion and holster cancellation restore the rig to RESET; cancelling never grants ammunition.

Findings: linear mechanical tracks avoid cubic interpolation pulling the slide forward during a long stationary magazine-exchange section. Source UVs supply the finish. The magazine body is new geometry because only its external base was present in the original closed mesh. Shared external material/meshes keep the assembled scene around 10 KB instead of embedding the texture in every component.

Verification: tools/stylized_pistol_test.gd checks hammer travel, fixed frame, slide return, magazine extraction/seating, absence of slide overshoot, textured parts, cancellation reset, and exact ammo transfer. Native tools/capture_stylized_pistol.gd captures ready, hammer-forward/back, magazine-out/seated poses; tools/capture_pistol_game.gd checks the actual hands and first-person composition. Required room/weapon captures and all regression suites also run before publication.
