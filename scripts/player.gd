class_name Player
extends RapierRigidBody2D


# All the possible states that the player can be in
enum State {
	IDLE = 0,
	MOVE = 1,
	HIT = 2
}


const PLAYER_COLORS: Array[Color] = [
	Color(0.922, 0.435, 0.322, 1.0),
	Color(0.313, 0.698, 0.368, 1.0),
	Color(0.896, 0.399, 0.667, 1.0),
	Color(0.623, 0.507, 0.974, 1.0),
	Color(0.35, 0.609, 0.938, 1.0),
	Color(0.247, 0.678, 0.655, 1.0),
	Color(0.652, 0.597, 0.467, 1.0),
	Color(0.843, 0.886, 0.122, 1.0)
]

@export_group("Config")

@export var _max_hp: int = 10

## The force applied to the body when moving left or right.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") 
var movement_force: float = 800.0

@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") 
var hit_force: float = 800.0

## Whether the horizontal speed should be clamped to maximum_speed.
@export var should_limit_speed: bool = true

## The maximum horizontal speed the body is allowed to reach.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") 
var maximum_speed: float = 400.0

@export_custom(PROPERTY_HINT_NONE, "suffix:ms")
var hit_cooldown_ms: int = 100


@export_group("Scene Refs")
@export var body_panel: Panel
@export var client_sync: MultiplayerSynchronizer
@export var server_sync: MultiplayerSynchronizer
@export var camera: Camera2D
@export var cannon: PlayerCannon


@export_group("Sync Refs")
@export var current_hp: int = 20

@export var color: int = 0: # Determines which color to display as
	set(value):
		color = clampi(value, 0, PLAYER_COLORS.size() - 1)
		# Update sprite to display as the new character
		var box: StyleBoxFlat = body_panel.get_theme_stylebox(&"panel")
		box.bg_color = PLAYER_COLORS[color]
		box.border_color = PLAYER_COLORS[color].darkened(0.2)

@export var state: State = State.IDLE : # The current state the player is in
	set(value):
		# Limit the value to the bounds of State
		state = clampi(value, 0, State.size() - 1) as State


var peer_id: int = 1 # The peer that controls this player
var local: bool = true # If this player belongs to the local peer
var _hit_time_ms: int = 0


func _enter_tree() -> void:
	# Set node authority
	# Name is set to peer id by lobby when spawning
	peer_id = int(name)
	client_sync.set_multiplayer_authority(peer_id)
	local = (peer_id == multiplayer.get_unique_id())
	
	cannon.local = local
	
	current_hp = _max_hp


func _ready() -> void:
	if local:
		# Activate the camera if local
		camera.make_current()


#region RPC 
@rpc("authority", "call_local", "reliable")
func teleport(new_pos: Vector2) -> void:
	freeze = true
	await get_tree().process_frame
	
	linear_velocity = Vector2.ZERO
	global_position = new_pos
	state = State.IDLE
	freeze = false
	print("Teleported to: ", new_pos)

#endregion


# --- Public Helpers ---

func hit_by(other: Node2D) -> void:
	if (state == State.HIT): return
	_hit_time_ms = Time.get_ticks_msec()
	state = State.HIT
	apply_central_impulse(
			global_position.direction_to(other.global_position) * hit_force
	)


func _physics_process(_delta: float) -> void:
	if !local:
		return
	
	var input_direction: float = Input.get_axis("move_left", "move_right")
	#apply_central_force(Vector2(input_direction * movement_force, 0))
	
	# State machine
	match(state):
		State.IDLE: _state_idle(input_direction)
		State.MOVE: _state_move(input_direction)
		State.HIT: _state_hit(input_direction)


func _integrate_forces(phys_state: PhysicsDirectBodyState2D) -> void:
	var velocity: Vector2 = phys_state.linear_velocity
	velocity.x = clampf(velocity.x, -maximum_speed, maximum_speed)
	phys_state.linear_velocity = velocity


# --- Internal Helpers ---

func _apply_movement_force(p_direction: float) -> void:
	if p_direction == 0.0:
		return
	
	var force: Vector2 = Vector2(p_direction * movement_force, 0)
	apply_central_force(force)


func _check_move(input_direction: float) -> bool:
	if !is_zero_approx(input_direction):
		state = State.MOVE
		return true
	return false


func _check_idle(input_direction: float) -> bool:
	if is_zero_approx(input_direction):
		state = State.IDLE
		return true
	return false


# --- States ---

func _state_idle(input_direction: float) -> void:
	if (_check_move(input_direction)): return
	_apply_movement_force(input_direction)


func _state_move(input_direction: float) -> void:
	if (_check_idle(input_direction)): return
	_apply_movement_force(input_direction)


func _state_hit(_input_direction: float) -> void:
	# Wait for cooldown
	var now_ms: int = Time.get_ticks_msec()
	if (now_ms - _hit_time_ms < hit_cooldown_ms): return
	state = State.IDLE
