class_name CountdownLabel
extends Label


signal countdown_finished()


@onready var tween_node: TweenNode = $TweenNode
@onready var fade_out_tween: TweenNode = $FadeOutTween


var tween: Tween = null
var ignored_first: bool = false


func _ready() -> void:
	hide()
	
	await get_tree().create_timer(0.25).timeout
	tween_node.make_tween()
	tween = tween_node.get_tween()
	tween.finished.connect(countdown_finished.emit)
	tween.finished.connect(fade_out_tween.play)


# Called by GetDunkedLabel Tween
func start_countdown() -> void:
	text = str(3)
	tween_node.play()


func _count_down() -> void:
	if !ignored_first:
		ignored_first = true
		return
	
	var current: int = int(text)
	text = str(current - 1)
