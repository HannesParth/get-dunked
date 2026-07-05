class_name Boat
extends RigidBody2D


func _ready() -> void:
	if !multiplayer.is_server():
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		freeze = true


@rpc("authority", "call_local", "reliable")
func teleport(new_pos: Vector2) -> void:
	freeze = true
	await get_tree().process_frame
	
	linear_velocity = Vector2.ZERO
	global_position = new_pos
	
	if multiplayer.is_server():
		freeze = false
