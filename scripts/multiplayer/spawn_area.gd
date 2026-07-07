class_name SpawnArea
extends Control


const MAX_SPAWN_POINT_ATTEMPTS: int = 30


@export var _taken_pos_safety_margin: float = 80.0


var _taken_positions: Array[Vector2] = []


func get_random_spawn_point() -> Vector2:
	var random_position: Vector2 = _get_random_global_position_on_rect()
	var attempt_count: int = 0

	while (
			_is_position_taken(random_position) 
			&& attempt_count < MAX_SPAWN_POINT_ATTEMPTS
	):
		random_position = _get_random_global_position_on_rect()
		attempt_count += 1

	_taken_positions.append(random_position)

	return random_position


## Returns a random global position that lies within the
## Control node's rect, taking the node's rotation (and scale) into
## account, since get_global_transform() already includes both.
func _get_random_global_position_on_rect() -> Vector2:
	var random_local_position: Vector2 = Vector2(
			randf() * size.x,
			randf() * size.y
	)
	
	return get_global_transform() * random_local_position


## Checks whether the given position is closer than the safety margin
## to any position that has already been taken.
func _is_position_taken(p_position: Vector2) -> bool:
	for taken_position: Vector2 in _taken_positions:
		if p_position.distance_to(taken_position) < _taken_pos_safety_margin:
			return true

	return false
