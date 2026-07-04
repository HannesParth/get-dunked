extends CanvasLayer

@export_file_path("*.tscn")
var _main_scene: String = "res://scenes/multiplayer/lobby.tscn"

@export var _auth_failed_msg: PanelContainer


func _ready() -> void:
	# Skip if running in debug or as headless
	if (DisplayServer.get_name() == "headless"):
		get_tree().change_scene_to_file.call_deferred(_main_scene)
		return
	
	# Ask the Ezcha website to authenticate us
	var authenticated: bool = await Ezcha.client.authenticate()
	
	# Check if authentication was successful
	if (authenticated || OS.is_debug_build()):
		print("Authenticated!")
		get_tree().change_scene_to_file.call_deferred(_main_scene)
	else:
		_auth_failed_msg.show()
