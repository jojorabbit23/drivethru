# Phone ticket: shares the customer order book and speech bubble without a vehicle.
# Riders can later listen to DeliveryStation.pickup_ready and use RiderStop.
extends "res://game/customer_car.gd"

func start() -> void:
	state="waiting"
	_add_bubble(Vector3(0,2.25,.25))
	_bubble.scale=Vector3.ONE*.70
	_bubble.show()

func _process(delta: float) -> void:
	if state!="waiting":
		queue_free()
		return
	if get_parent().get_parent().player.is_dead():return
	waited+=delta
	var viewer: Camera3D=get_viewport().get_camera_3d()
	if viewer:_bubble.global_basis=viewer.global_basis.scaled(Vector3.ONE*.70)
	var fraction: float=clampf(1.0-waited/patience,0.0,1.0)
	_bar.scale.x=maxf(.02,fraction)
	(_bar.material_override as StandardMaterial3D).albedo_color=P.AMBER_GLOW if fraction<.25 else P.ELECTRIC_TEAL
	if waited>=patience:leave(false)
