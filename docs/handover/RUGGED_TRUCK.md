# Rugged off-road customer — 20 October 2026

The supplied truck is added as rugged_truck, alongside school_bus and armored_truck.
Random selection gives each an equal share. Customer order/payment/patience and
arrival/departure logic are unchanged. Tests can force hatch.next_vehicle.

Runtime geometry is 9,332 triangles: 8,032 body plus four separately rolling tyre
meshes. One 2048 albedo and one material, using the existing builder. Length 5.6 m,
width 2.5 m, height 2.03 m. Rolling radius 0.47 m. Cab offset -0.20 m aligns the
actual driver-side window with the hatch rather than the car's bonnet.

The cube driver's centre is local (0.68,1.40,0.20) inside the open driver window.
The head is a 27 cm black cube with exactly two 4 cm white dots. A fixed black
rectangular torso (30 x 52 x 38 cm) sits beneath it in the chair, overlapping the
head slightly so turning never opens a floating gap. Only the head tracks. Unshaded materials
keep them plain black/white without adding lights or emission. The head smoothly
turns towards the player's camera, so the dots follow their movement; pitch is
limited to prevent tipping through the roof. Driver and dots cast no extra shadows.

Builder: tools/build_rugged_truck.gd. First run writes albedo, then --import and rerun.
Source provenance: vehicles/rugged_truck/SOURCE.md. Rebuild rather than edit generated
rugged_* resources. User GLB is retained unchanged.

Verification: rugged_truck_test.gd covers three-vehicle registration, all four tyre
meshes, black cube/two white dots, tracking to both sides, hatch alignment, wheel
rotation, arrival, automatic two-burger payment and departure. Native
capture_rugged_truck.gd renders the driver's left/right gaze, hatch view and whole
vehicle. Run it and inspect docs/previews/rugged_*.png before adjusting the fit.

Final verification: all 24 suites passed, including validate and both radio/truck
suites. All five new/changed scripts pass Godot 4.3 check-only. Driver gaze and
whole-truck captures were inspected, along with required kitchen, serving-room,
pistol, knife and pump captures. Source GLB SHA256 matches the supplied file.
