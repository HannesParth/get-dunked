class_name Trail2D
extends Line2D


enum TrailDrawType {
	FRAME,
	DISTANCE,
}

@export var _target: Node2D
@export var _draw_type: TrailDrawType = TrailDrawType.FRAME

## Maximum length of the trail. Only relevant for DISTANCE draw type.
@export var _trail_length: float = 100.0

## Maximum number of points making up the trial. [br]
## Determines trail length for the FRAME draw type.
@export var _max_point_count: int = 30

## Minimum velocity to draw the trial, in pixels / sec. [br]
## Leave at 0 to have no minimum velocity.
@export var _min_velocity: float = 0.0

# TODO: implement
## Whether to stop trail drawing after the velocity dropped below the
## minimum velocity once, even if it increases afterwards again.
#@export var _stop_below_minimum_once: bool = false

@export var draw_trail: bool = true


var _current_velocity: float = 0.0
var _point_distance: float = 2.0
var _last_frame_global: Vector2 = Vector2.ZERO
var _travelled_since_last_point: float = 0.0


func _get_configuration_warnings() -> PackedStringArray:
	if _target == null || !is_instance_valid(_target):
		return ["No trail target assigned."]
	return []


func _ready() -> void:
	_last_frame_global = _target.global_position
	_point_distance = _trail_length / _max_point_count
	
	clear_points()
	top_level = true


func _physics_process(p_delta: float) -> void:
	if !is_node_ready() || !draw_trail:
		return
	
	var distance_this_frame: float = \
			_target.global_position.distance_to(_last_frame_global)
	_last_frame_global = _target.global_position
	
	_current_velocity = distance_this_frame / p_delta if p_delta > 0.0 else 0.0
	if _current_velocity < _min_velocity:
		return
	
	match _draw_type:
		TrailDrawType.FRAME:
			_draw_frame_based()
		TrailDrawType.DISTANCE:
			_draw_distance_based(distance_this_frame)


func _draw_frame_based() -> void:
	_add_trail_point()


func _draw_distance_based(p_distance_this_frame: float) -> void:
	_travelled_since_last_point += p_distance_this_frame
	if _travelled_since_last_point < _point_distance:
		return
	
	_travelled_since_last_point -= _point_distance
	_add_trail_point()


func _add_trail_point() -> void:
	add_point(_target.global_position)
	if points.size() > _max_point_count:
		remove_point(0)


func get_current_velocity() -> float:
	return _current_velocity
