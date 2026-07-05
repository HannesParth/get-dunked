class_name SpawnArea
extends Control


func get_random_spawn_point() -> Vector2:
	return _get_random_global_position_on_rect()


## Returns a random global position that lies within the
## Control node's rect, taking the node's rotation (and scale) into
## account, since get_global_transform() already includes both.
func _get_random_global_position_on_rect() -> Vector2:
	var random_local_position: Vector2 = Vector2(
			randf() * size.x,
			randf() * size.y
	)
	
	return get_global_transform() * random_local_position
