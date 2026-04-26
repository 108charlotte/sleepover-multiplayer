extends Camera2D

func _process(delta):
	var mouse = get_global_mouse_position()
	var center = get_viewport_rect().size / 2
	var target = Vector2(
		clamp(mouse.x, center.x - 20, center.x + 20),
		clamp(mouse.y, center.y - 20, center.y + 20)
	)
	position = lerp(position, target, 0.05)
