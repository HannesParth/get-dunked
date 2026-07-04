class_name Cannonball
extends RigidBody2D


@export var collision_particles: GPUParticles2D


# To replace gravity
const PROJ_CONSTANT_FORCE: Vector2 = Vector2(0, 980) * 10
const PROJ_MASS_KG: float = 40.0


func _init() -> void:
	add_constant_central_force(PROJ_CONSTANT_FORCE)
	mass = PROJ_MASS_KG


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node2D) -> void:
	collision_particles.emitting = true
