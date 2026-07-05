class_name LobbyUI
extends CanvasLayer


signal relay_join_pressed(lobby: EzchaRelayLobby)
signal relay_resolve_code_pressed(join_code: String)
signal relay_host_pressed(
		server: EzchaRelayServer, 
		lobby_name: String, 
		visibility: EzchaRelayMultiplayerPeer.Visibility
)


signal enet_join_pressed(address: String, port: int)
signal enet_host_pressed(port: int)


static var is_authenticated: bool = false


@export_group("ENet Scene Refs")
@export var _enet_address_edit: LineEdit
@export var _enet_join_port_edit: SpinBox
@export var _enet_host_port_edit: SpinBox
@export var _enet_join_button: Button
@export var _enet_host_button: Button

@export_group("Relay Scene Refs")
@export var _relay_panel: TabContainer

@export_subgroup("Join from Code")
@export var _relay_join_code_edit: LineEdit
@export var _relay_resolve_join_code_button: Button

@export_subgroup("Host")
@export var _relay_host_name_edit: LineEdit
@export var _relay_host_server_dropdown: OptionButton
@export var _relay_host_visibility_dropdown: OptionButton
@export var _relay_auth_button: Button
@export var _relay_host_button: Button

@export_subgroup("Lobby List")
@export var _relay_find_lobby_list: ItemList
@export var _relay_find_refresh_button: Button
@export var _relay_find_join_button: Button


var server_list: Array[EzchaRelayServer] = []
var lobby_list: Array[EzchaRelayLobby] = []
var _is_requesting: bool = false


func _ready() -> void:
	_enet_join_button.pressed.connect(_on_enet_join_pressed)
	_enet_host_button.pressed.connect(_on_enet_host_pressed)
	
	_relay_resolve_join_code_button.pressed.connect(_on_relay_resolve_pressed)
	_relay_auth_button.pressed.connect(_on_relay_auth_pressed)
	_relay_host_button.pressed.connect(_on_relay_host_pressed)
	_relay_find_refresh_button.pressed.connect(_on_relay_refresh_pressed)
	_relay_find_join_button.pressed.connect(_on_relay_join_pressed)
	
	# Prepare relay UI if visible
	_relay_host_button.disabled = true
	if OS.has_feature("editor") || OS.has_feature("web"):
		_relay_auth_button.disabled = false
	else:
		_relay_auth_button.disabled = true
		_relay_auth_button.text = "Cannot authenticate!"
	
	if _relay_panel.visible:
		_populate_relay_servers()
		_load_lobby_list()


func _on_relay_panel_visibility_changed() -> void:
	if _relay_panel.visible && !_is_requesting:
		_populate_relay_servers()
		_load_lobby_list()


func _load_lobby_list(page: int = 1) -> void:
	# Request the lobby list API
	var game_id: String = Ezcha.get_game_id()
	var request: EzchaLobbyListResponse = Ezcha.relay.get_lobbies(game_id, page)
	_is_requesting = true
	
	# Wait for and check response
	await request.completed
	_is_requesting = false
	if (!request.is_successful()): return
	
	# Keep a reference
	lobby_list = request.lobbies
	
	# Populate item list
	_relay_find_lobby_list.clear()
	for relay_lobby: EzchaRelayLobby in lobby_list:
		_relay_find_lobby_list.add_item(relay_lobby.name)


func _populate_relay_servers() -> void:
	_is_requesting = true
	var relay_servers: Array[EzchaRelayServer] = await Ezcha.client.order_relay_servers()
	_is_requesting = false
	if (relay_servers.is_empty()): return
	
	# Keep a reference
	server_list = relay_servers
	
	# Populate option button
	_relay_host_server_dropdown.clear()
	for server: EzchaRelayServer in server_list:
		_relay_host_server_dropdown.add_item("(%s) %s" % [server.region, server.name])
	_relay_host_server_dropdown.select(0)
	
	_relay_host_visibility_dropdown.clear()
	for vis: String in EzchaRelayMultiplayerPeer.Visibility.keys():
		_relay_host_visibility_dropdown.add_item(vis)
	_relay_host_visibility_dropdown.select(0)


func _on_relay_refresh_pressed() -> void:
	_load_lobby_list()


func _on_relay_join_pressed() -> void:
	# Determine the selected lobby
	var selected_items: PackedInt32Array = _relay_find_lobby_list.get_selected_items()
	if (selected_items.is_empty()): return
	var selected_lobby: EzchaRelayLobby = lobby_list[selected_items[0]]
	
	# Try to connect
	relay_join_pressed.emit(selected_lobby)
	hide()


func _on_relay_resolve_pressed() -> void:
	# Get the player input
	var join_code: String = _relay_join_code_edit.text
	if (join_code.is_empty()): 
		return
	
	# Try to resolve and connect
	relay_resolve_code_pressed.emit(join_code)
	hide()


func _on_relay_host_pressed() -> void:
	# Get parameters
	var lobby_name: String = _relay_host_name_edit.text
	if lobby_name.is_empty():
		return
	
	var server_idx: int = _relay_host_server_dropdown.get_selected_id()
	if (server_idx < 0): 
		return
	
	var server: EzchaRelayServer = server_list[server_idx]
	var visibility_idx: int = _relay_host_visibility_dropdown.get_selected_id()
	
	# Start a new lobby
	relay_host_pressed.emit(server, lobby_name, visibility_idx)
	hide()


func _on_relay_auth_pressed() -> void:
	_relay_auth_button.disabled = true
	_relay_auth_button.text = "Authenticating..."
	is_authenticated = await Ezcha.client.authenticate()
	
	# Check if authentication was successful
	if is_authenticated || OS.is_debug_build():
		print("Authenticated!")
		_relay_auth_button.text = "Authenticated!"
		_relay_host_button.disabled = false
	else:
		_relay_auth_button.text = "Authentication failed!"
		_relay_host_button.disabled = true
		await get_tree().create_timer(2.5).timeout
		_relay_auth_button.disabled = false
		_relay_auth_button.text = "Authenticate"




func _on_enet_join_pressed() -> void:
	var address: String = _enet_address_edit.text
	var port: int = int(_enet_join_port_edit.value)
	enet_join_pressed.emit(address, port)


func _on_enet_host_pressed() -> void:
	var port: int = int(_enet_host_port_edit.value)
	enet_host_pressed.emit(port)
