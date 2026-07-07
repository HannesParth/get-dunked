extends Node2D


@export var water: DynamicWater2D
@export var position_marker: Sprite2D


func _input(event: InputEvent) -> void:
	if !event.is_action_pressed("fire"):
		return
	
	var pos: Vector2 = get_global_mouse_position()
	apply(pos)


func apply(pos: Vector2) -> void:
	# The position has to be above the waterline
	pos.y = water.global_position.y - (20 + water.wave_height * 2)
	position_marker.global_position = pos
	water.apply_force(pos, Vector2.DOWN * 200, 60)
