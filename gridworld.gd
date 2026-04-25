extends Node2D

const PlayerScene = preload("res://multiplayer_player.tscn")

func setup_players() -> void:
	if multiplayer.is_server():
		_spawn_player(1)
		for id in multiplayer.get_peers():
			_spawn_player(id)
	
	multiplayer.peer_connected.connect(_spawn_player)
	multiplayer.peer_disconnected.connect(_remove_player)

func _spawn_player(id: int) -> void:
	var player = PlayerScene.instantiate()
	player.name = str(id)
	add_child(player)
	player.set_multiplayer_authority(id)

func _remove_player(id: int) -> void:
	var player = get_node_or_null(str(id))
	if player:
		player.queue_free()
