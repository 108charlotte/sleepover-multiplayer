extends Control

@onready var client: Node = $Client
@onready var host: LineEdit = $VBoxContainer/HBoxContainer2/Connect/Host
@onready var room: LineEdit = $VBoxContainer/HBoxContainer2/Connect/RoomSecret
@onready var mesh: CheckBox = $VBoxContainer/HBoxContainer2/Connect/Mesh

var current_lobby: String = ""

func _ready() -> void:
	host.text = "wss://godot-demo-projects-k0or.onrender.com/"
	client.lobby_joined.connect(_lobby_joined)
	client.lobby_sealed.connect(_lobby_sealed)
	client.connected.connect(_connected)
	client.disconnected.connect(_disconnected)

	multiplayer.connected_to_server.connect(_mp_server_connected)
	multiplayer.connection_failed.connect(_mp_server_disconnect)
	multiplayer.server_disconnected.connect(_mp_server_disconnect)
	multiplayer.peer_connected.connect(_mp_peer_connected)
	multiplayer.peer_disconnected.connect(_mp_peer_disconnected)
	
	$VBoxContainer/HBoxContainer2/Hosting/Stop.hide()
	$VBoxContainer/HBoxContainer2/Hosting/Seal.hide()
	
	$VBoxContainer/NumPlayers.hide()
	$VBoxContainer/HBoxContainer/LobbyCode.hide()
	$VBoxContainer/HBoxContainer/CopyCode.hide()

	mesh.button_pressed = false
	mesh.disabled = true
	
	room.text_changed.connect(_on_room_text_changed)


@rpc("any_peer", "call_local")
func ping(argument: float) -> void:
	_log("[Multiplayer] Ping from peer %d: arg: %f" % [multiplayer.get_remote_sender_id(), argument])


func _mp_server_connected() -> void:
	_log("[Multiplayer] Server connected (I am %d)" % client.rtc_mp.get_unique_id())


func _mp_server_disconnect() -> void:
	_log("[Multiplayer] Server disconnected (I am %d)" % client.rtc_mp.get_unique_id())
	_reset_ui()


func _mp_peer_connected(id: int) -> void:
	_log("[Multiplayer] Peer %d connected" % id)
	$VBoxContainer/NumPlayers.text = "# of players in room (includes you!): " + _get_num_players()
	$VBoxContainer/NumPlayers.show()
	$VBoxContainer/HBoxContainer/LobbyCode.text = "Lobby Code: " + current_lobby
	$VBoxContainer/HBoxContainer/LobbyCode.show()


func _mp_peer_disconnected(id: int) -> void:
	_log("[Multiplayer] Peer %d disconnected" % id)


func _get_num_players() -> String: 
	return str(multiplayer.get_peers().size() + 1)


func _connected(id: int, use_mesh: bool) -> void:
	_log("[Signaling] Server connected with ID: %d" % [id])
	$VBoxContainer/NumPlayers.text = "# of players in room (includes you!): " + _get_num_players()
	$VBoxContainer/NumPlayers.show()

	var is_host = client.rtc_mp.get_unique_id() == 1
	$VBoxContainer/HBoxContainer2/Hosting/Start.disabled = not is_host
	$VBoxContainer/HBoxContainer2/Hosting/Stop.disabled = not is_host
	$VBoxContainer/HBoxContainer2/Hosting/Seal.disabled = not is_host
	
	$VBoxContainer/HBoxContainer2/Hosting/Start.hide()
	
	if not is_host: 
		$VBoxContainer/HBoxContainer2/Hosting/Stop.hide()
		$VBoxContainer/HBoxContainer2/Hosting/Seal.hide()
	else: 
		$VBoxContainer/HBoxContainer2/Hosting/Stop.show()
		$VBoxContainer/HBoxContainer2/Hosting/Seal.show()
	print("updated visible buttons")


func _disconnected() -> void:
	_log("[Signaling] Server disconnected: %d - %s" % [client.code, client.reason])
	_reset_ui()


func _reset_ui() -> void:
	$VBoxContainer/HBoxContainer2.show()
	$MenuBackground.show()
	
	$VBoxContainer/HBoxContainer/LobbyCode.hide()
	$VBoxContainer/HBoxContainer/CopyCode.hide()
	$VBoxContainer/NumPlayers.hide()

	$VBoxContainer/HBoxContainer2/Hosting/Start.show()
	$VBoxContainer/HBoxContainer2/Hosting/Start.disabled = false
	$VBoxContainer/HBoxContainer2/Hosting/Stop.hide()
	$VBoxContainer/HBoxContainer2/Hosting/Seal.hide()

	room.text = ""


func _lobby_joined(lobby: String) -> void:
	_log("[Signaling] Joined lobby %s" % lobby)
	current_lobby = lobby
	$VBoxContainer/HBoxContainer/LobbyCode.text = "Lobby Code: " + current_lobby
	$VBoxContainer/HBoxContainer/LobbyCode.show()
	$VBoxContainer/HBoxContainer/CopyCode.show()


func _lobby_sealed() -> void:
	_log("[Signaling] Lobby has been sealed")
	$VBoxContainer/HBoxContainer2.hide()
	$MenuBackground.hide()
	$VBoxContainer/HBoxContainer/LobbyCode.hide()
	$VBoxContainer/HBoxContainer/CopyCode.hide()
	$VBoxContainer/NumPlayers.hide()
	%gridworld.show()
	%gridworld.setup_players()


func _log(msg: String) -> void:
	print(msg)


func _on_peers_pressed() -> void:
	_log(str(multiplayer.get_peers()))


func _on_ping_pressed() -> void:
	ping.rpc(randf())


func _on_seal_pressed() -> void:
	client.seal_lobby()


func _on_start_pressed() -> void:
	client.start(host.text, room.text, mesh.button_pressed)


func _on_stop_pressed() -> void:
	client.stop()


func _on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(current_lobby)
	$VBoxContainer/HBoxContainer/CopyCode.text = "Copied!"
	await get_tree().create_timer(2.0).timeout
	$VBoxContainer/HBoxContainer/CopyCode.text = "Copy"


func _on_room_text_changed(new_text: String) -> void:
	if new_text.is_empty():
		$VBoxContainer/HBoxContainer2/Hosting/Start.text = "Start new lobby"
	else:
		$VBoxContainer/HBoxContainer2/Hosting/Start.text = "Join lobby"
