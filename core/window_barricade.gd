# Boarded breach window. Attached to each ShopGreybox/Windows/Window_* node by
# the builder. Zombies rip boards off from outside; the player repairs them
# from inside. Local +Z points out of the building.
extends Node3D

signal board_removed(index: int)
signal board_restored(index: int)
signal breached

const BOARD_LAYER := 2
const DEBRIS_LIFETIME := 8.0

var boards: Array[StaticBody3D] = []

func _ready() -> void:
	add_to_group("windows")
	for b in $Boards.get_children():
		boards.append(b)

func boards_left() -> int:
	var n := 0
	for b in boards:
		if b.collision_layer != 0:
			n += 1
	return n

func is_breached() -> bool:
	return boards_left() == 0

func breach_point() -> Vector3:
	return ($Breach_Point as Node3D).global_position

func repair_point() -> Vector3:
	return ($Repair_Point as Node3D).global_position

func lane_spawn() -> Vector3:
	return ($Lane_Spawn as Node3D).global_position

func outward() -> Vector3:
	return global_basis.z

# Zombies pull boards top-down; the board tumbles out into the lane.
func rip_board() -> bool:
	for i in range(boards.size() - 1, -1, -1):
		var b := boards[i]
		if b.collision_layer == 0:
			continue
		b.collision_layer = 0
		b.visible = false
		_spawn_debris(b)
		board_removed.emit(i)
		if is_breached():
			breached.emit()
		return true
	return false

# Player repairs bottom-up.
func repair_board() -> bool:
	for i in boards.size():
		var b := boards[i]
		if b.collision_layer != 0:
			continue
		b.collision_layer = BOARD_LAYER
		b.visible = true
		var mesh := b.get_node("Mesh") as Node3D
		mesh.scale = Vector3(1, 1, 1) * 0.6
		create_tween().tween_property(mesh, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		board_restored.emit(i)
		return true
	return false

func _spawn_debris(board: StaticBody3D) -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = 1
	rb.mass = 3.0
	var mi := (board.get_node("Mesh") as MeshInstance3D).duplicate() as MeshInstance3D
	mi.visible = true
	rb.add_child(mi)
	var cs := (board.get_node("Shape") as CollisionShape3D).duplicate() as CollisionShape3D
	rb.add_child(cs)
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(rb)
	rb.global_transform = board.global_transform
	var out := outward()
	rb.linear_velocity = out * randf_range(2.0, 3.2) + Vector3.UP * randf_range(1.0, 2.0)
	rb.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-8, 8))
	get_tree().create_timer(DEBRIS_LIFETIME).timeout.connect(rb.queue_free)
