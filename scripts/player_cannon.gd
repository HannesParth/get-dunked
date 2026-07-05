class_name PlayerCannon
extends Node2D


@export var rotation_speed: float = 6.0
@export var block_input: bool = false

@export_group("Projectile Config")
# Proj power determines the distance of the targeted position in the direction
# the cannon is aiming
@export var start_proj_power: float = 100.0
@export var max_proj_power: float = 1000.0
@export var proj_power_increase: float = 500.0
@export var fire_cooldown: float = 1.5

@export_group("Trajectory Line Config")
@export var traj_line_points: int = 10
@export var traj_time_step: float = 0.1

@export_group("Scene Refs")
@export var proj_origin: Marker2D
@export var proj_prefab: PackedScene
@export var proj_holder: Node
@export var trajectory_line: Line2D
@export var cooldown_progress: ProgressBar


var local: bool = false

var is_aiming: bool = false
var current_proj_power: float = 0.0
var aim_direction: Vector2
var current_cooldown: float = 0.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _input(event: InputEvent) -> void:
	if !Level.is_gameplay_active || block_input:
		return
	if !local:
		return
	
	if event.is_action_pressed("fire"):
		is_aiming = true
		current_proj_power = start_proj_power
	
	elif event.is_action_released("fire"):
		is_aiming = false
		if current_cooldown <= 0.0:
			_shoot.rpc(proj_origin.global_position, aim_direction, current_proj_power)


@rpc("any_peer", "call_local", "reliable")
func _shoot(start_pos: Vector2, aim_dir: Vector2, power: float) -> void:
	var proj: RigidBody2D = proj_prefab.instantiate()
	proj.global_position = start_pos
	proj_holder.add_child(proj, true)
	proj.linear_velocity = aim_dir * power
	
	if local:
		current_cooldown = fire_cooldown


func _physics_process(delta: float) -> void:
	if !local && !Level.is_showcase_only:
		return
	
	if current_cooldown >= 0.0:
		current_cooldown -= delta
		cooldown_progress.value = (current_cooldown / fire_cooldown) * 100
	
	if !block_input:
		var angle: float = get_angle_to(get_global_mouse_position())
		rotation = rotate_toward(
				rotation, 
				rotation + angle, 
				rotation_speed * delta
		)
	
	var do_charge: bool = is_aiming && current_cooldown <= 0.0
	trajectory_line.visible = do_charge
	
	if !do_charge:
		return
	
	aim_direction = Vector2.from_angle(global_rotation)
	current_proj_power = clampf(
			current_proj_power + delta * proj_power_increase,
			start_proj_power,
			max_proj_power
	)
	
	_update_trajectory()



func _update_trajectory() -> void:
	trajectory_line.global_position = proj_origin.global_position
	trajectory_line.clear_points()
	trajectory_line.add_point(Vector2.ZERO)
	
	var current_pos: Vector2 = Vector2.ZERO
	var velocity: Vector2 = aim_direction * current_proj_power
	for i: int in traj_line_points:
		current_pos += velocity * traj_time_step
		trajectory_line.add_point(current_pos)
		velocity.y += gravity * traj_time_step
