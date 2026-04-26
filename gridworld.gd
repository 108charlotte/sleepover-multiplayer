extends Node2D

const PlayerScene = preload("res://multiplayer_player.tscn")
const PlayerScript = preload("res://scripts/multiplayer/multiplayer_player.gd")

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


func clear_players() -> void:
	# Remove any player instances that were spawned from the PlayerScene/script.
	# This frees their Camera2D nodes as well.
	for child in get_children():
		if child is Node:
			var scr = null
			if child.has_method("get_script"):
				scr = child.get_script()
			if scr == PlayerScript:
				child.queue_free()
