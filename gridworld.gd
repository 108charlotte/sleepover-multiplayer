extends Node2D

var available_sprites = [
	"res://tiles/Characters/green_character.png",
	"res://tiles/Characters/purple_character.png",
	"res://tiles/Characters/red_character.png",
	"res://tiles/Characters/yellow_character.png",
	"res://tiles/Characters/blue_character.png"
]
const PlayerScene = preload("res://multiplayer_player.tscn")
const PlayerScript = preload("res://scripts/multiplayer/multiplayer_player.gd")
const TOTAL_SPRITES = 5
var _remaining_sprites: Array = []  # pool that shrinks as players join

func setup_players() -> void:
	_remaining_sprites = available_sprites.duplicate()  # reset pool each game
	_remaining_sprites.shuffle()  # random order, but still one-of-each

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

	if multiplayer.is_server():
		if _remaining_sprites.is_empty():
			# Fallback if more players than sprites
			player.sprite_path = available_sprites[id % available_sprites.size()]
		else:
			var chosen = _remaining_sprites.pop_back()
			player.sprite_path = chosen

func _remove_player(id: int) -> void:
	var player = get_node_or_null(str(id))
	if player:
		player.queue_free()

func clear_players() -> void:
	for child in get_children():
		child.queue_free()
	_remaining_sprites.clear()
