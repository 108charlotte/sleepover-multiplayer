extends CharacterBody2D
const GRID_SIZE = 128
const MOVE_SPEED = 0
@onready var animated_sprite = $AnimatedSprite2D
@export var player_id := 1:
	set(id):
		player_id = id
var _target_position := Vector2.ZERO
var _last_direction := Vector2.DOWN  # track for idle animation

func _enter_tree() -> void:
	player_id = int(name)
	set_multiplayer_authority(int(name))

func _ready() -> void:
	print("Player %s | my peer ID: %s | is authority: %s" % [
		name,
		multiplayer.get_unique_id(),
		is_multiplayer_authority()
	])
	var camera = get_node_or_null("Camera2D")
	print("Camera found: ", camera)
	if camera:
		camera.enabled = is_multiplayer_authority()

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		position = position.move_toward(_target_position, GRID_SIZE)  # smooth follow
		return
	_apply_movement_from_input()

func _apply_movement_from_input() -> void:
	var direction := Vector2.ZERO
	if Input.is_action_just_pressed("ui_left"):
		direction = Vector2.LEFT
	elif Input.is_action_just_pressed("ui_right"):
		direction = Vector2.RIGHT
	elif Input.is_action_just_pressed("ui_up"):
		direction = Vector2.UP
	elif Input.is_action_just_pressed("ui_down"):
		direction = Vector2.DOWN

	if direction != Vector2.ZERO:
		_move(direction)

func _move(direction: Vector2) -> void:
	var next_position = _target_position + direction * GRID_SIZE
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(position, next_position)
	query.exclude = [self]
	var result = space.intersect_ray(query)
	if result:
		return
	_last_direction = direction
	_target_position = next_position
	position = _target_position  # ← this was missing
	_play_walk_animation()
	_play_idle_animation()  # ← also add this back begins

func _play_walk_animation() -> void:
	if _last_direction == Vector2.LEFT:
		animated_sprite.play("walk_left")
	elif _last_direction == Vector2.RIGHT:
		animated_sprite.play("walk_right")
	elif _last_direction == Vector2.UP:
		animated_sprite.play("walk_up")
	elif _last_direction == Vector2.DOWN:
		animated_sprite.play("walk_down")

func _play_idle_animation() -> void:
	if _last_direction == Vector2.LEFT:
		animated_sprite.play("idle_left")
	elif _last_direction == Vector2.RIGHT:
		animated_sprite.play("idle_right")
	elif _last_direction == Vector2.UP:
		animated_sprite.play("idle_up")
	elif _last_direction == Vector2.DOWN:
		animated_sprite.play("idle_down")
