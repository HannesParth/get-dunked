class_name WaterArea2D
extends Area2D

## Emitted when a body becomes 100% submerged (fully underwater).
signal body_fully_submerged(p_body: Node2D)

## Emitted when a body has left the water by at least
## [member exit_threshold] (e.g. 0.2 means: fires once 20% of the
## body's collision shape is above water).
signal body_partially_exited(p_body: Node2D, p_exited_ratio: float)


## Holds the per-body submersion state while a body stays in the water.
class TrackedBodyData:
	var submersion_ratio: float = 0.0
	var fully_submerged_emitted: bool = false
	var partial_exit_emitted: bool = false


@export var water_density: float = 2.0
@export var linear_damping_factor: float = 1.0
@export var angular_damping_factor: float = 0.5
@export var exit_threshold: float = 0.2

var _tracked_bodies: Dictionary[Node2D, TrackedBodyData] = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	linear_damp_space_override = Area2D.SPACE_OVERRIDE_COMBINE
	angular_damp_space_override = Area2D.SPACE_OVERRIDE_COMBINE


func _physics_process(_p_delta: float) -> void:
	var water_surface_y: float = _get_water_surface_y()
	var highest_submersion_ratio: float = 0.0

	for body: Node2D in _tracked_bodies.keys():
		if !is_instance_valid(body):
			_tracked_bodies.erase(body)
			continue

		var submersion_ratio: float = _update_body_buoyancy(
				(body as RigidBody2D), water_surface_y
		)
		highest_submersion_ratio = max(
				highest_submersion_ratio, submersion_ratio
		)

	_apply_water_damping(highest_submersion_ratio)


func _on_body_entered(p_body: Node2D) -> void:
	if !(p_body is RigidBody2D):
		return

	_tracked_bodies[p_body] = TrackedBodyData.new()


func _on_body_exited(p_body: Node2D) -> void:
	if _tracked_bodies.has(p_body):
		_tracked_bodies.erase(p_body)


func _update_body_buoyancy(
		p_body: RigidBody2D, p_water_surface_y: float
) -> float:
	var collision_node: Node2D = _get_first_collision_node(p_body)
	var corners: Array[Vector2] = _get_collision_node_corners(
			collision_node
	)

	if corners.size() < 4:
		return 0.0

	var body_extent: Vector2 = _get_vertical_extent_from_corners(
			corners
	)
	var body_top_y: float = body_extent.x
	var body_bottom_y: float = body_extent.y
	var body_height: float = body_bottom_y - body_top_y

	if body_height <= 0.0:
		return 0.0

	var submerged_height: float = body_bottom_y - max(
			body_top_y, p_water_surface_y
	)
	submerged_height = clamp(submerged_height, 0.0, body_height)
	var submersion_ratio: float = submerged_height / body_height

	var body_data: TrackedBodyData = _tracked_bodies[p_body]

	_apply_distributed_buoyancy_force(
			p_body, corners, p_water_surface_y
	)
	_check_submersion_signals(p_body, body_data, submersion_ratio)

	body_data.submersion_ratio = submersion_ratio

	return submersion_ratio


## Applies buoyancy as two separate side forces (left / right) instead
## of a single central force. A central force always passes through
## the center of mass and therefore can never create a torque, no
## matter how low the center of mass is placed. By applying the force
## at the left and right hull corners instead, a tilted hull (one
## side deeper than the other) automatically receives more force on
## its deeper side, which produces a self-righting torque.
func _apply_distributed_buoyancy_force(
		p_body: RigidBody2D,
		p_corners: Array[Vector2],
		p_water_surface_y: float
) -> void:
	if p_corners.size() < 4:
		return

	var default_gravity: float = ProjectSettings.get_setting(
			"physics/2d/default_gravity"
	) as float
	var left_corners: Array[Vector2] = [p_corners[0], p_corners[2]]
	var right_corners: Array[Vector2] = [p_corners[1], p_corners[3]]

	_apply_side_buoyancy_force(
			p_body, left_corners, p_water_surface_y, default_gravity
	)
	_apply_side_buoyancy_force(
			p_body, right_corners, p_water_surface_y, default_gravity
	)


## Applies buoyancy for one side (left or right) of the hull, using
## only that side's own top/bottom corners to determine how deep this
## specific side is submerged.
func _apply_side_buoyancy_force(
		p_body: RigidBody2D,
		p_side_corners: Array[Vector2],
		p_water_surface_y: float,
		p_default_gravity: float
) -> void:
	var side_extent: Vector2 = _get_vertical_extent_from_corners(
			p_side_corners
	)
	var side_top_y: float = side_extent.x
	var side_bottom_y: float = side_extent.y
	var side_height: float = side_bottom_y - side_top_y

	if side_height <= 0.0:
		return

	var submerged_height: float = side_bottom_y - max(
			side_top_y, p_water_surface_y
	)
	submerged_height = clamp(submerged_height, 0.0, side_height)
	var side_submersion_ratio: float = submerged_height / side_height

	if side_submersion_ratio <= 0.0:
		return

	# Each side contributes half of the total buoyancy force, so a
	# fully and evenly submerged hull produces the same total force
	# as before, just split across two application points.
	var force_magnitude: float = (
			p_default_gravity * p_body.mass * p_body.gravity_scale
			* water_density * side_submersion_ratio * 0.5
	)
	var side_position: Vector2 = (
			(p_side_corners[0] + p_side_corners[1]) * 0.5
	)
	# apply_force's position argument is the offset from the body's
	# origin, expressed in global (non-rotated) coordinates, so a
	# plain difference of two global positions is exactly right here.
	var position_offset: Vector2 = (
			side_position - p_body.global_position
	)
	
	var custom_multi: Variant = p_body.get(&"buoyancy_multiplier")
	if custom_multi != null:
		force_magnitude = force_magnitude * (custom_multi as float)
	
	p_body.apply_force(Vector2.UP * force_magnitude, position_offset)


## Sets the area's own damp values instead of touching a body's
## velocity directly, since the Godot documentation strongly advises
## against manually setting linear_velocity / angular_velocity on a
## RigidBody2D. Because linear_damp_space_override and
## angular_damp_space_override are set to Combine in _ready, this
## value adds on top of each body's own damp instead of replacing it.
## Damp is velocity lost per second, so linear_damping_factor and
## angular_damping_factor are already in the correct unit and only
## need to be scaled by the submersion ratio, no conversion needed.
func _apply_water_damping(p_highest_submersion_ratio: float) -> void:
	linear_damp = linear_damping_factor * p_highest_submersion_ratio
	angular_damp = (
			angular_damping_factor * p_highest_submersion_ratio
	)


func _check_submersion_signals(
		p_body: RigidBody2D,
		p_body_data: TrackedBodyData,
		p_current_ratio: float
) -> void:
	if p_current_ratio >= 1.0 && !p_body_data.fully_submerged_emitted:
		p_body_data.fully_submerged_emitted = true
		body_fully_submerged.emit(p_body)
		if p_body.has_method(&"submerged_fully"):
			p_body.call(&"submerged_fully")
	elif p_current_ratio < 1.0:
		p_body_data.fully_submerged_emitted = false

	var exited_ratio: float = 1.0 - p_current_ratio

	if (
			exited_ratio >= exit_threshold
			&& !p_body_data.partial_exit_emitted
	):
		p_body_data.partial_exit_emitted = true
		body_partially_exited.emit(p_body, exited_ratio)
	elif exited_ratio < exit_threshold:
		p_body_data.partial_exit_emitted = false


func _get_water_surface_y() -> float:
	var collision_node: Node2D = _get_first_collision_node(self)

	if collision_node == null:
		return global_position.y

	var corners: Array[Vector2] = _get_collision_node_corners(
			collision_node
	)

	if corners.size() < 4:
		return collision_node.global_position.y

	return _get_vertical_extent_from_corners(corners).x


## Finds the first child that is either a CollisionShape2D or a
## CollisionPolygon2D, so both node types can be treated uniformly
## by [method _get_collision_node_corners].
func _get_first_collision_node(p_node: Node) -> Node2D:
	for child: Node in p_node.get_children():
		if child is CollisionShape2D || child is CollisionPolygon2D:
			return child as Node2D

	return null


## Returns the four global-space corners (top_left, top_right,
## bottom_left, bottom_right) of a CollisionShape2D or
## CollisionPolygon2D, treating the shape like a rectangle.
func _get_collision_node_corners(
		p_collision_node: Node2D
) -> Array[Vector2]:
	if p_collision_node == null:
		return []

	if p_collision_node is CollisionShape2D:
		return _get_shape_corners(
				p_collision_node as CollisionShape2D
		)
	elif p_collision_node is CollisionPolygon2D:
		return _get_collision_polygon_corners(
				p_collision_node as CollisionPolygon2D
		)

	return []


func _get_shape_corners(
		p_collision_shape: CollisionShape2D
) -> Array[Vector2]:
	var shape: Shape2D = p_collision_shape.shape
	var shape_transform: Transform2D = (
			p_collision_shape.global_transform
	)

	if shape is RectangleShape2D:
		return _get_rectangle_corners(
				shape as RectangleShape2D, shape_transform
		)
	elif shape is CircleShape2D:
		return _get_circle_corners(
				shape as CircleShape2D, shape_transform
		)
	elif shape is CapsuleShape2D:
		return _get_capsule_corners(
				shape as CapsuleShape2D, shape_transform
		)

	return []


func _get_rectangle_corners(
		p_shape: RectangleShape2D, p_transform: Transform2D
) -> Array[Vector2]:
	var half_size: Vector2 = p_shape.size * 0.5
	var local_corners: Array[Vector2] = [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(-half_size.x, half_size.y),
		Vector2(half_size.x, half_size.y),
	]

	return _transform_corners(local_corners, p_transform)


func _get_circle_corners(
		p_shape: CircleShape2D, p_transform: Transform2D
) -> Array[Vector2]:
	var radius: float = p_shape.radius
	var local_corners: Array[Vector2] = [
		Vector2(-radius, -radius),
		Vector2(radius, -radius),
		Vector2(-radius, radius),
		Vector2(radius, radius),
	]

	return _transform_corners(local_corners, p_transform)


func _get_capsule_corners(
		p_shape: CapsuleShape2D, p_transform: Transform2D
) -> Array[Vector2]:
	var half_width: float = p_shape.radius
	var half_height: float = p_shape.height * 0.5 + p_shape.radius
	var local_corners: Array[Vector2] = [
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(-half_width, half_height),
		Vector2(half_width, half_height),
	]

	return _transform_corners(local_corners, p_transform)


func _get_collision_polygon_corners(
		p_collision_polygon: CollisionPolygon2D
) -> Array[Vector2]:
	var points: PackedVector2Array = p_collision_polygon.polygon

	if points.is_empty():
		return []

	var minimum_x: float = INF
	var maximum_x: float = -INF
	var minimum_y: float = INF
	var maximum_y: float = -INF

	for point: Vector2 in points:
		minimum_x = min(minimum_x, point.x)
		maximum_x = max(maximum_x, point.x)
		minimum_y = min(minimum_y, point.y)
		maximum_y = max(maximum_y, point.y)

	var local_corners: Array[Vector2] = [
		Vector2(minimum_x, minimum_y),
		Vector2(maximum_x, minimum_y),
		Vector2(minimum_x, maximum_y),
		Vector2(maximum_x, maximum_y),
	]
	var polygon_transform: Transform2D = (
			p_collision_polygon.global_transform
	)

	return _transform_corners(local_corners, polygon_transform)


## Transforms an array of local-space corners into global space using
## the given transform. Shared by all shape-specific corner getters.
func _transform_corners(
		p_local_corners: Array[Vector2], p_transform: Transform2D
) -> Array[Vector2]:
	var global_corners: Array[Vector2] = []

	for local_corner: Vector2 in p_local_corners:
		global_corners.append(p_transform * local_corner)

	return global_corners


## Computes the (top_y, bottom_y) vertical extent from an array of
## global-space corners.
func _get_vertical_extent_from_corners(
		p_corners: Array[Vector2]
) -> Vector2:
	var minimum_y: float = INF
	var maximum_y: float = -INF

	for corner: Vector2 in p_corners:
		minimum_y = min(minimum_y, corner.y)
		maximum_y = max(maximum_y, corner.y)

	return Vector2(minimum_y, maximum_y)
