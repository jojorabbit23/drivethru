# Reuses the vehicle mesh/texture/wheel pipeline without rebuilding the older cars.
extends "res://tools/build_vehicles.gd"
func _initialize() -> void:
	var waiting: bool=build({"name":"RuggedTruck","src":"res://vehicles/rugged_truck/source/rugged_truck.glb","dir":"res://vehicles/rugged_truck/","prefix":"rugged","length":5.6,"axle_y":0.082,"front_z":0.307,"rear_z":-0.285,"r":0.094,"r_up":0.080,"in":0.135,"top":0.160})
	if waiting:print("Run --import, then build_rugged_truck.gd again")
	quit()
