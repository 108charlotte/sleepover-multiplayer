extends CharacterBody2D
const GRID_SIZE = 128
const MOVE_SPEED = 0
@onready var animated_sprite = $AnimatedSprite2D
@onready var movement_shape = $MovementCollisionShape2D
@onready var action_shape = $ActionCollisionShape2D
@export var player_id := 1:
	set(id):
		player_id = id
@export var sprite_index: int = 0:
	set(val):
		sprite_index = val
		_update_sprite_visuals()
@export var sprite_path: String = "":
	set(val):
		sprite_path = val
		$Sprite2D.texture =tex


var _target_position := Vector2.ZERO
var _last_direction := Vector2.DOWN  # track for idle animation
var _initial_camera_global_position := Vector2.ZERO
var _initial_camera_global_rotation := 0.0

enum Role { DETECTIVE, NIGHTMARE, DREAMER }
@export var role: int = Role.DREAMER 		#fahh
var flagged_players: Array = []
var is_frozen := false
var interaction_targets: Array = []


func _enter_tree() -> void:
	player_id = int(name)
	set_multiplayer_authority(int(name))

func _ready() -> void:
	add_to_group("players")
	
	print("Player %s | my peer ID: %s | is authority: %s" % [
		name,
		multiplayer.get_unique_id(),
		is_multiplayer_authority()
	])
	var camera = get_node_or_null("Camera2D")
	print("Camera found: ", camera)
	if camera:
		# store the camera's initial global transform so we can reset it on disconnect
		_initial_camera_global_position = camera.global_position
		_initial_camera_global_rotation = camera.global_rotation
		# Use Camera2D methods where available to control which camera is active.
		# Different engine versions expose different APIs; prefer method calls.
		if is_multiplayer_authority():
			if camera.has_method("make_current"):
				camera.make_current()
			elif camera.has_method("set_current"):
				camera.set_current(true)
		else:
			# Ensure the camera isn't left processing nor marked current
			if camera.has_method("clear_current"):
				camera.clear_current()
			elif camera.has_method("set_current"):
				camera.set_current(false)
			camera.set_process(false)

@rpc("reliable")
func set_role(new_role: int):
	role = new_role
	print("player ", name, "role ", role)

func _update_sprite_visuals():
	if not is_inside_tree(): await ready
	var path = ""
func _on_action_collision_shape_entered(body) -> void:
	if body == self:
		return
	interaction_targets.append(body)
func _on_action_collision_shape_exited(body) -> void:
	interaction_targets.erase(body)

func _input(event):
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("action"):
		if interactions_target.size() > 0:
			var target = interaction_targets[0]
			handle_interaction.rpc(target)

func _physics_process(delta: float) -> void:
	if is_frozen:
		return
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

@rpc("call_local")
func interaction_handling(target):
	match role:
		Role.DETECTIVE:
			detective_interact(target)
		Role.NIGHTMARE:
			nightmare_interact(target)
		Role.DREAMER:
			dreamer_interact(target)

func detective_interact(target):
	
func nightmare_interact(target):
	
func dreamer_interact(target):
	
func _exit_tree() -> void:
	# When this player node leaves the scene tree (player disconnected),
	# hard reset the camera to its initial global transform and disable it.
	var camera = get_node_or_null("Camera2D")
	if camera:
		# restore the camera to the recorded initial world position/rotation
		camera.global_position = _initial_camera_global_position
		camera.global_rotation = _initial_camera_global_rotation
		# disable the camera so it no longer becomes the current view
		if camera.has_method("clear_current"):
			camera.clear_current()
		elif camera.has_method("set_current"):
			camera.set_current(false)
		# stop processing to be extra-safe and hide follow behavior
		camera.set_process(false)
