extends Node2D

var available_sprites = [
	"res://tiles/Characters/green_character.png",
	"res://tiles/Characters/purple_character.png",
	"res://tiles/Characters/red_character.png",
	"res://tiles/Characters/yellow_character.png",
	"res://tiles/Characters/blue_character.png",
	"res://tiles/Characters/green_hand.png",
	"res://tiles/Characters/purple_hand.png",
	"res://tiles/Characters/red_hand.png",
	"res://tiles/Characters/yellow_hand.png",
	"res://tiles/Characters/blue_hand.png"
]

const PlayerScene = preload("res://multiplayer_player.tscn")
const PlayerScript = preload("res://scripts/multiplayer/multiplayer_player.gd")
const TOTAL_SPRITES = 10
var _remaining_sprites: Array = []  # pool that shrinks as players join
func setup_players() -> void:
	if multiplayer.is_server():
		_spawn_player(1)
		for id in multiplayer.get_peers():
			_spawn_player(id)
	multiplayer.peer_connected.connect(_spawn_player)
	multiplayer.peer_disconnected.connect(_remove_player)

func _spawn_player(id: int) -> void:
	if get_node_or_null(str(id)):
		return
	var player = PlayerScene.instantiate()
	player.name = str(id)
	add_child(player, true)  # ← true = use readable names, spawner syncs this to clients
	player.set_multiplayer_authority(id)

func _remove_player(id: int) -> void:
	var player = get_node_or_null(str(id))
	if player:
		player.queue_free()
