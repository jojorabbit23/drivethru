extends SceneTree
const Car=preload("res://game/customer_car.gd")
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run() -> void:
	var main: Node3D=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	main.player.set_physics_process(false)
	main.hatch.auto=false
	main.hatch.next_vehicle="rugged_truck"
	main.hatch.next_order="brown"
	var car: Node3D=main.hatch.spawn_customer(2)
	car.set_process(false)
	check(Car.VEHICLES.size()==3 and Car.VEHICLES.has("rugged_truck"),"new truck is included alongside both previous customer vehicles")
	check(car.vehicle=="rugged_truck" and car._bus_wheels.size()==4,"truck has four separate rolling wheel meshes")
	for wheel: MeshInstance3D in car._bus_wheels:
		check(wheel.mesh.get_surface_count()==1 and wheel.mesh.surface_get_array_len(0)>0,"wheel mesh contains geometry")
	var driver: Node3D=car._body.get_node("CubeDriver")
	check(driver.head.get_node("BlackCube").mesh is BoxMesh and driver.eyes.size()==2,"driver is a cube with exactly two dots")
	check(driver.head.get_node("BlackCube").material_override.albedo_color==Color.BLACK,"cube is plain black")
	for eye: MeshInstance3D in driver.eyes:
		check(eye.material_override.albedo_color==Color.WHITE and eye.mesh is SphereMesh,"dot is plain white without iris or pupil")
	car._process(5.0)
	check(car.state=="waiting","truck drives in and waits for its order")
	var hatch_position: Vector3=car.to_global(Vector3(0,0,-car.CAB_FROM_CENTRE))
	check(absf(hatch_position.x-main.hatch.lane_stop.x)<0.01,"driver window aligns with serving hatch")
	main.player.camera.global_position=driver.global_position+Vector3(-0.7,0.02,2.0)
	for i in 90:driver._process(1.0/60.0)
	var left_rotation: float=driver.head.rotation.y
	var gaze: Vector3=-driver.head.global_basis.z.normalized()
	check(gaze.dot((main.player.camera.global_position-driver.global_position).normalized())>0.99,"dots face player to the left of the window")
	main.player.camera.global_position=driver.global_position+Vector3(0.7,0.02,2.0)
	for i in 90:driver._process(1.0/60.0)
	gaze=-driver.head.global_basis.z.normalized()
	check(absf(angle_difference(left_rotation,driver.head.rotation.y))>0.4 and gaze.dot((main.player.camera.global_position-driver.global_position).normalized())>0.99,"gaze follows player moving to the right")
	var wheels_before: float=car.wheel_angle()
	car._last_pos=car.position
	car.position.x+=0.5
	car._spin_wheels()
	check(not is_equal_approx(car.wheel_angle(),wheels_before),"wheels rotate with travelled distance")
	for i in 2:main.serving_tray.items[i]={"kind":"brown","quality":"perfect"}
	var cash: int=main.economy.cash
	check(main.hatch.collect_from_tray()==2 and main.economy.cash>cash,"truck buys requested tray burgers and pays normally")
	check(car.state=="leaving" and main.economy.served==1,"paid truck leaves after complete order")
	main.free()
	for i in 3:await process_frame
	print("%d failure(s)" % failures)
	quit(1 if failures else 0)
