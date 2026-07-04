class_name PlayerCannon
extends Node2D


@export var rotation_speed: float = 6.0
@export var proj_speed: float = 600.0

@export var proj_origin: Marker2D
@export var proj_prefab: PackedScene
@export var proj_holder: Node
@export var trajectory_line: Line2D


var local: bool = false
var current_proj_velocity: Vector2


func _input(event: InputEvent) -> void:
	if !local:
		return
	
	if event is not InputEventMouseButton:
		return
	
	var mouse: InputEventMouseButton = event
	if mouse == null:
		return
	
	if !mouse.pressed:
		return
	
	if mouse.button_index == MOUSE_BUTTON_LEFT:
		_shoot.rpc(current_proj_velocity)


@rpc("any_peer", "call_local", "reliable")
func _shoot(velocity: Vector2) -> void:
	if is_nan(velocity.x):
		printerr("Nope")
		return
	
	var proj: RigidBody2D = proj_prefab.instantiate()
	proj.global_position = proj_origin.global_position
	proj.linear_velocity = velocity
	proj_holder.add_child(proj, true)


func _physics_process(delta: float) -> void:
	if !local:
		return
	
	var angle: float = get_angle_to(get_global_mouse_position())
	rotation = rotate_toward(
			rotation, 
			rotation + angle, 
			rotation_speed * delta
	)
	
	var target_local_pos: Vector2 = get_proj_target_local_pos()
	var velocity: Vector2 = BsVelocity2D.best_by_speed(
			proj_speed,
			target_local_pos,
			Vector2.ZERO,
			Cannonball.PROJ_CONSTANT_FORCE / Cannonball.PROJ_MASS_KG,
			Vector2.ZERO
	)
	if !is_nan(velocity.x):
		current_proj_velocity = velocity
	
	update_trajectory_line(
			proj_origin.global_position,
			current_proj_velocity,
			 Cannonball.PROJ_CONSTANT_FORCE / Cannonball.PROJ_MASS_KG,
			1.0,
			20
	)


## Builds a trajectory preview by sampling BsPosition2D.position() at
## evenly spaced points in time and assigning the result to a
## Line2D's points array. The Line2D's points are expected in its own
## local space, so each global sample point is converted accordingly.
func update_trajectory_line(
		p_start_position: Vector2,
		p_velocity: Vector2,
		p_acceleration: Vector2,
		p_duration: float,
		p_sample_count: int
) -> void:
	var trajectory_points: PackedVector2Array = PackedVector2Array()
	
	for sample_index: int in range(p_sample_count + 1):
		var elapsed_time: float = (
				p_duration * float(sample_index)
				/ float(p_sample_count)
		)
		var global_point: Vector2 = BsPosition2D.position(
				p_start_position,
				elapsed_time,
				p_velocity,
				p_acceleration
		)
	
		trajectory_points.append(trajectory_line.to_local(global_point))
	
	trajectory_line.points = trajectory_points


func get_proj_target_local_pos() -> Vector2:
	var dir: Vector2 = (proj_origin.global_position - global_position).normalized()
	var distance: float = proj_origin.global_position.distance_to(
			get_global_mouse_position()
	)
	distance = maxf(distance, 20.0)
	return dir * distance
