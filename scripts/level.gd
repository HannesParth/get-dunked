extends Node2D
class_name Level


static var is_gameplay_active: bool = false
static var is_showcase_only: bool = false

@export var showcase_only: bool = false
@export var display_name: String = "Untitled Level"


@export_group("Scene Refs")
@export var spawn_area: SpawnArea

@export var _ui: LevelUI


func _ready() -> void:
	is_showcase_only = showcase_only
	if showcase_only:
		return
	
	_ui.countdown_finished.connect(
		func() -> void:
			is_gameplay_active = true
			print("Gameplay active!")
	)

# --- Public Helpers ---

func get_spawn_position() -> Vector2:
	return spawn_area.get_random_spawn_point()
