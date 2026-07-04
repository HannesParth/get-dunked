extends Node2D
class_name Level


@export var display_name: String = "Untitled Level"


@export_group("Scene Refs")
@export var spawn_area: SpawnArea



# --- Public Helpers ---

func get_spawn_position() -> Vector2:
	return spawn_area.get_random_spawn_point()
