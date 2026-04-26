extends Node

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print(get_children())
	await get_tree().process_frame
	print(get_children())
