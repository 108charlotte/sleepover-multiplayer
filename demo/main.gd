extends Control

func _enter_tree() -> void:
	for c in $VBoxContainer/Clients.get_children():
		# So each child gets its own separate MultiplayerAPI.
		get_tree().set_multiplayer(
				MultiplayerAPI.create_default_interface(),
				NodePath("%s/VBoxContainer/Clients/%s" % [get_path(), c.name])
			)
