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
var _remaining_sprites: Array = []

# Role tracking
var player_roles: Dictionary = {}  # { peer_id: role } — server only
var my_role: String = ""

func setup_players() -> void:
	if multiplayer.is_server():
		_spawn_player(1)
		for id in multiplayer.get_peers():
			_spawn_player(id)
		_assign_roles()  # assign after all players spawned
	multiplayer.peer_connected.connect(_spawn_player)
	multiplayer.peer_disconnected.connect(_remove_player)

func _assign_roles() -> void:
	var all_peers = Array(multiplayer.get_peers())
	all_peers.append(1)
	all_peers.shuffle()

	var roles = {}
	roles[all_peers[0]] = "detective"
	if all_peers.size() > 1:
		roles[all_peers[1]] = "nightmare"
	for i in range(2, all_peers.size()):
		roles[all_peers[i]] = "dreamer"

	player_roles = roles
	print("Roles assigned: ", roles)

	# Send each player only their own role
	for peer_id in roles:
		_receive_role.rpc_id(peer_id, roles[peer_id])

@rpc("authority", "call_local", "reliable")
func _receive_role(role: String) -> void:
	my_role = role
	_show_role_popup(role)

func _show_role_popup(role: String) -> void:
	var popup = AcceptDialog.new()
	popup.title = "Your Role"
	match role:
		"detective":
			popup.dialog_text = "you are the detective."
		"nightmare":
			popup.dialog_text = "you are the nightmare."
		"dreamer":
			popup.dialog_text = "you are a dreamer."
	add_child(popup)
	popup.popup_centered()

func _spawn_player(id: int) -> void:
	if get_node_or_null(str(id)):
		return
	var player = PlayerScene.instantiate()
	player.name = str(id)
	add_child(player, true)
	player.set_multiplayer_authority(id)

func _remove_player(id: int) -> void:
	var player = get_node_or_null(str(id))
	if player:
		player.queue_free()
