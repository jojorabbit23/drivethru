extends CollisionObject3D
func take_prop_damage(amount: float) -> void:
 get_parent().take_prop_damage(amount)
