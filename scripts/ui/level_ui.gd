class_name LevelUI
extends CanvasLayer

signal countdown_finished()


@export var showcase_only: bool = false
@export var _player_label_theme: Theme

@export_group("Scene Refs")
@export var _to_dunk_tween: TweenNode
@export var _be_dunked_tween: TweenNode
@export var _countdown_label: CountdownLabel
@export var _lobby_panel: PanelContainer
@export var _player_list: VBoxContainer
@export var _wait_for_host_label: Label
@export var _host_start_game_button: Button


func _ready() -> void:
	if showcase_only:
		return
	
	_countdown_label.countdown_finished.connect(countdown_finished.emit)
	_host_start_game_button.pressed.connect(_on_host_start_game_pressed)
	
	if multiplayer.multiplayer_peer is not EzchaRelayMultiplayerPeer:
		# Call directly
		_on_host_start_game_pressed()
		return
	
	var peer: EzchaRelayMultiplayerPeer = multiplayer.multiplayer_peer
	peer.user_connected.connect(_update_player_list)
	peer.user_disconnected.connect(_update_player_list)
	_update_player_list()
	
	_lobby_panel.visible = multiplayer.is_server()
	_wait_for_host_label.visible = !multiplayer.is_server()
	_host_start_game_button.visible = multiplayer.is_server()


func _on_host_start_game_pressed() -> void:
	if !multiplayer.is_server():
		return
	
	_start_game_sequence.rpc()


@rpc("authority", "call_local", "reliable")
func _start_game_sequence() -> void:
	await get_tree().create_timer(0.25).timeout
	
	_lobby_panel.hide()
	_to_dunk_tween.play()
	_be_dunked_tween.play()


func _update_player_list() -> void:
	var peer: EzchaRelayMultiplayerPeer = multiplayer.multiplayer_peer
	
	for child: Node in _player_list.get_children():
		child.queue_free()
	
	for peer_id: int in peer.get_peers():
		var user: EzchaUser = peer.get_user(peer_id)
		
		var label: Label = Label.new()
		label.text = user.name
		label.theme = _player_label_theme
		_player_list.add_child(label)
