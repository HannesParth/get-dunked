class_name Lobby
extends Node2D


# TODO:
# - clean up listing on ezcha
# - extract and clean up lobby and multiplayer code for template


## For ENet only
const DEFAULT_PORT: int = 47218


@export var player_prefab: PackedScene
@export var boat_prefab: PackedScene

@export var _player_spawner: MultiplayerSpawner
@export var _level_spawner: MultiplayerSpawner
@export var _level_holder: Node2D
@export var _player_holder: Node2D
@export var _boat_holder: Node2D
@export var _ui: LobbyUI


var max_players: int:
	get:
		if is_node_ready():
			return _player_spawner.spawn_limit
		else:
			return 8

var level: Level = null
var level_idx: int = -1

var available_player_colors: Array[int] = []


# --- Lifecycle ---

func _ready() -> void:
	# Listen to multiplayer signals
	# The following emit on both clients and servers
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	# The rest only emit for clients
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Listen for UI signals
	_ui.enet_host_pressed.connect(start_enet_server)
	_ui.enet_host_pressed.connect(func(_port: int) -> void: _ui.hide())
	_ui.enet_join_pressed.connect(start_enet_client)
	_ui.enet_join_pressed.connect(func(_a: String, _p: int) -> void: _ui.hide())
	
	_ui.relay_host_pressed.connect(start_relay_lobby)
	_ui.relay_join_pressed.connect(join_relay_lobby)
	_ui.relay_resolve_code_pressed.connect(resolve_relay_lobby)
	
	# Prepare available player color indices
	for idx: int in Player.PLAYER_COLORS.size():
		available_player_colors.append(idx)


# --- Network ---

func _start_server_common() -> void:
	load_level(0) # start the first level
	spawn_player(1) # server always has ID 1


func start_enet_server(port: int = DEFAULT_PORT) -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	peer.create_server(port, max_players)
	multiplayer.multiplayer_peer = peer
	_start_server_common()


func start_enet_client(address: String, port: int = DEFAULT_PORT) -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	multiplayer.multiplayer_peer = peer



func start_relay_lobby(
		server: EzchaRelayServer, 
		lobby_name: String, 
		visibility: EzchaRelayMultiplayerPeer.Visibility
) -> void:
	var peer: EzchaRelayMultiplayerPeer = EzchaRelayMultiplayerPeer.new()
	_setup_relay_signal_connections(peer)
	peer.create_lobby(server, lobby_name, max_players, 0, visibility)
	multiplayer.multiplayer_peer = peer


func join_relay_lobby(lobby: EzchaRelayLobby) -> void:
	var peer: EzchaRelayMultiplayerPeer = EzchaRelayMultiplayerPeer.new()
	_setup_relay_signal_connections(peer)
	peer.join_lobby(lobby)
	multiplayer.multiplayer_peer = peer


func resolve_relay_lobby(code: String) -> void:
	var peer: EzchaRelayMultiplayerPeer = EzchaRelayMultiplayerPeer.new()
	_setup_relay_signal_connections(peer)
	peer.resolve_lobby(code)
	multiplayer.multiplayer_peer = peer


# --- Ezcha Network Events ---

func _setup_relay_signal_connections(peer: EzchaRelayMultiplayerPeer) -> void:
	peer.lobby_connected.connect(_on_relay_lobby_connected)
	peer.lobby_created.connect(_on_relay_lobby_created)
	peer.lobby_joined.connect(_on_relay_lobby_joined)
	peer.user_connected.connect(_on_relay_user_connected)
	peer.user_disconnected.connect(_on_relay_user_disconnected)


func _on_relay_lobby_connected() -> void:
	push_warning("Lobby connected")


func _on_relay_lobby_created() -> void:
	push_warning("Lobby created")


func _on_relay_lobby_joined() -> void:
	push_warning("Lobby joined")


func _on_relay_user_connected(peer_id: int, _user: EzchaUser) -> void:
	push_warning("User connected: ", peer_id)
	# Handle player spawn if hosting
	if !multiplayer.is_server(): 
		return
	
	if peer_id == 1:
		_start_server_common()
		return
	
	spawn_player(peer_id)


func _on_relay_user_disconnected(peer_id: int, _user: EzchaUser) -> void:
	push_warning("User disconnected: ", peer_id)
	# Handle player removal if hosting
	if (!multiplayer.is_server()): 
		return
	remove_player(peer_id)


# --- Network Events ---

func _on_peer_connected(peer_id: int) -> void:
	push_warning("Peer connected: ", peer_id)
	if multiplayer.multiplayer_peer is EzchaRelayMultiplayerPeer:
		return
	
	# Handle player spawn if hosting
	if !multiplayer.is_server(): 
		return
	
	if peer_id == 1:
		_start_server_common()
		return
	
	spawn_player(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	push_warning("Peer disconnected: ", peer_id)
	if multiplayer.multiplayer_peer is EzchaRelayMultiplayerPeer:
		return
	
	# Handle player removal if hosting
	if (!multiplayer.is_server()): 
		return
	remove_player(peer_id)


func _on_connected_to_server() -> void:
	push_warning("Connected to server")

func _on_connection_failed() -> void:
	push_error("Connection failed")

func _on_server_disconnected() -> void:
	push_warning("Server disconnected")



# --- Level Management ---

func load_level(new_level_idx: int) -> void:
	# Get level path
	if new_level_idx < 0 || new_level_idx >= _level_spawner.get_spawnable_scene_count():
		push_error("Level index out of bounds")
		return
	var level_path: String = _level_spawner.get_spawnable_scene(new_level_idx)
	
	# Free previous level
	if level != null: 
		level.queue_free()
	for child: Node in _level_holder.get_children():
		child.queue_free()
	
	# Load new level
	var level_scn: PackedScene = load(level_path)
	level = level_scn.instantiate()
	level_idx = new_level_idx
	_level_holder.add_child.call_deferred(level, true)
	
	push_warning("Loaded level", level.display_name)
	
	# Listen to level events
	#level.goal_reached.connect(_on_goal_reached, ConnectFlags.CONNECT_ONE_SHOT)
	
	# Teleport players
	teleport_players(level.get_spawn_position())


func unload_level() -> void:
	if level != null: 
		push_warning("Unloading level ", level.display_name)
		level.queue_free()
	level = null
	level_idx = -1


func next_level() -> void:
	load_level(level_idx + 1)


func is_final_level() -> bool:
	return (level_idx == _level_spawner.get_spawnable_scene_count() - 1)



# --- Player Management ---

func get_player(peer_id: int) -> Player:
	for child: Node2D in _player_holder.get_children():
		if child is Player && (child as Player).peer_id == peer_id:
			return child
	return null


func get_players() -> Array[Player]:
	var players: Array[Player] = []
	for child: Node2D in _player_holder.get_children():
		if (child is Player):
			players.append(child)
	return players


func get_player_count() -> int:
	var count: int = 0
	for child: Node2D in _player_holder.get_children():
		if (child is Player):
			count += 1
	return count


func spawn_player(peer_id: int) -> void:
	push_warning("Spawning player: ", peer_id)
	# Prepare new player
	var player: Player = player_prefab.instantiate()
	player.name = str(peer_id)
	player.color = available_player_colors.pop_front()
	
	# Add player to level and teleport to spawn position
	_player_holder.add_child(player)
	if level == null:
		push_error("Level not set!")
		return
	
	var pos: Vector2 = level.get_spawn_position()
	player.teleport.rpc(pos)
	
	spawn_boat(peer_id, pos + Vector2.DOWN * 100)


func remove_player(peer_id: int) -> void:
	# Find player node
	var player: Player = get_player(peer_id)
	if (player == null): return
	
	# Return character back to available list
	available_player_colors.append(player.color)
	
	# Free player
	player.queue_free()


func teleport_players(new_pos: Vector2) -> void:
	for player: Player in get_players():
		player.teleport.rpc(new_pos)


# --- Boat Management ---

func spawn_boat(peer_id: int, global_pos: Vector2) -> void:
	var boat: Boat = boat_prefab.instantiate()
	boat.name = "%s_boat" % peer_id
	
	_boat_holder.add_child(boat)
	boat.teleport.rpc(global_pos)
