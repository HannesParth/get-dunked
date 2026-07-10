class_name CameraZoom
extends Camera2D


@export var _zoom_amount: float = 0.1
@export var _min_zoom: float = 0.6
@export var _max_zoom: float = 1.5


var local: bool = false
var _zoom_tween: Tween = null


func _input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	if !event.is_pressed():
		return
	
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	
	var factor: float = 0.0
	if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
		factor = mouse_button.factor if mouse_button.factor else 1.0
	elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		factor = -mouse_button.factor if mouse_button.factor else -1.0
	
	var delta: float = _zoom_amount * factor
	var value: float = clampf(zoom.x + delta, _min_zoom, _max_zoom)
	
	if _zoom_tween != null && _zoom_tween.is_valid():
		_zoom_tween.kill()
	
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, ^"zoom", Vector2(value, value), 0.2)
