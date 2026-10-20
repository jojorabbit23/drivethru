# Rugged off-road truck

Source: owner-supplied rugged off-road truck 3d model.glb, copied unchanged into
source/rugged_truck.glb. Original texture and geometry retained. The builder
normalizes it to 5.6 m long, faces it along local -Z and separates rolling tyres.

Generated rugged_* resources: tools/build_rugged_truck.gd, reusing
build_vehicles.gd. First run writes the 2048-pixel albedo; run --import and build
again. Never edit the generated scene/meshes/material directly.

Driver is attached by game/customer_car.gd only for this vehicle, using
 game/cube_driver.gd. Black and white are explicit owner-requested driver colours.
