extends TextureRect


@export var center_tween_duration: float = 0.2
@export var proj_ignore_speed_threshold: float = 15.0

@export var projectile_follow_area: Area2D
@export var pupil: Control


var max_distance: float = 3.0
var _center_tween: Tween = null


func _ready() -> void:
	max_distance = pupil.size.x * 0.2


func _physics_process(_delta: float) -> void:
	if !visible:
		return
	
	var bodies: Array[Node2D] = projectile_follow_area.get_overlapping_bodies()
	_filter_out_still_bodies(bodies)
	
	if bodies.is_empty():
		_look_at_pos(get_global_mouse_position())
		return
	
	var closest_pos: Vector2 = Vector2.INF
	var closest_distance: float = INF
	for body: Node2D in bodies:
		# Get closest one
		var distance: float = global_position.distance_to(body.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_pos = body.global_position
	
	# No body passed the speed filter, so there is no valid target
	# direction. Tween the pupil back to the center instead of
	# calling _look_at_position() with a non-finite position.
	if closest_distance == INF:
		_tween_pupil_to_center()
		return
	
	_look_at_pos(closest_pos)


func _filter_out_still_bodies(bodies: Array[Node2D]) -> void:
	for body: Node2D in bodies:
		if body is not RigidBody2D:
			bodies.erase(body)
		
		var velocity: Vector2 = (body as RigidBody2D).linear_velocity
		if velocity.length() < proj_ignore_speed_threshold:
			bodies.erase(body)


func _look_at_pos(target_global: Vector2, distance_multi: float = 1.0) -> void:
	_stop_center_tween()
	
	var center: Vector2 = global_position + size / 2
	var dir: Vector2 = center.direction_to(target_global)
	var target_offset: Vector2 = dir * max_distance * distance_multi
	
	pupil.global_position = center + target_offset - pupil.size / 2


func _tween_pupil_to_center() -> void:
	if _center_tween != null && _center_tween.is_valid():
		return
	
	var center: Vector2 = global_position + size / 2
	var target_pupil_position: Vector2 = center - pupil.size / 2
	
	_center_tween = create_tween()
	_center_tween.tween_property(
			pupil, "global_position", target_pupil_position,
			center_tween_duration
	)


func _stop_center_tween() -> void:
	if _center_tween != null && _center_tween.is_valid():
		_center_tween.kill()

	_center_tween = null
