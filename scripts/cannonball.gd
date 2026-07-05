class_name Cannonball
extends RigidBody2D


@export var buoyancy_multiplier: float = 0.5
@export var collision_particles: GPUParticles2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	if !multiplayer.is_server():
		freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		freeze = true


func _on_body_entered(_body: Node2D) -> void:
	collision_particles.emitting = true
