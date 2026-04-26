extends Camera2D

func _process(delta):
	var mouse = get_global_mouse_position()
	var center = get_viewport_rect().size / 2
	var target = Vector2(
		clamp(mouse.x, center.x - 100, center.x + 100),
		clamp(mouse.y, center.y - 100, center.y + 100)
	)
	position = lerp(position, target, 0.05)
