extends CharacterBody2D
const GRID_SIZE = 128
const MOVE_SPEED = 0
const FOOTPRINT_EXPIRY = 30.0
const MAX_REVEAL_PRESSES = 5
const CHARACTER_DIR = "res://tiles/Characters/"

@onready var sprite = $Sprite2D
@onready var movement_shape = $MovementCollisionShape2D
@onready var action_shape = $Area2D
@export var player_id := 1:
	set(id):
		player_id = id
@export var sprite_path: String = "":
	set(val):
		sprite_path = val
		if val != "" and ResourceLoader.exists(val):
			var tex = load(val)
			if tex is Texture2D:
				sprite.texture = tex

var _target_position := Vector2.ZERO
var _last_direction := Vector2.DOWN
var _initial_camera_global_position := Vector2.ZERO
var _initial_camera_global_rotation := 0.0

enum Role { DETECTIVE, NIGHTMARE, DREAMER }
@export var role: int = Role.DREAMER
var flagged_players: Array = []
var is_frozen := false
var is_sleeping := false
var reveal_presses_remaining := MAX_REVEAL_PRESSES

var interaction_targets: Array = []

# Footprint map for the Nightmare role.
# Keyed by Vector2i grid position.
# Each value is a Dictionary:
#   "timestamp" : float  — when the nightmare last walked here (seconds)
#   "recent"    : bool   — true if walked here within the last 30 seconds
#   "visible"   : bool   — whether this footprint is currently visible
var footprint_map: Dictionary = {}


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
	if camera:
		_initial_camera_global_position = camera.global_position
		_initial_camera_global_rotation = camera.global_rotation
		if is_multiplayer_authority():
			if camera.has_method("make_current"):
				camera.make_current()
			elif camera.has_method("set_current"):
				camera.set_current(true)
		else:
			if camera.has_method("clear_current"):
				camera.clear_current()
			elif camera.has_method("set_current"):
				camera.set_current(false)

	# Only the authority picks and broadcasts the sprite
	if is_multiplayer_authority():
		var chosen = _pick_random_character()
		if chosen != "":
			assign_sprite.rpc(chosen)

func _pick_random_character() -> String:
	var dir = DirAccess.open(CHARACTER_DIR)
	if not dir:
		print("Could not open character directory: ", CHARACTER_DIR)
		return ""
	var files: Array = []
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		# Only grab image files, skip .import sidecar files
		if not file.ends_with(".import") and (file.ends_with(".png") or file.ends_with(".jpg") or file.ends_with(".webp")):
			files.append(CHARACTER_DIR + file)
		file = dir.get_next()
	dir.list_dir_end()
	if files.is_empty():
		print("No character images found in ", CHARACTER_DIR)
		return ""
	return files[randi() % files.size()]

# Called on all peers so everyone sees the same sprite for this player.
@rpc("call_local", "reliable")
func assign_sprite(path: String) -> void:
	sprite_path = path

@rpc("reliable")
func set_role(new_role: int):
	role = new_role
	print("player ", name, " role ", role)

# ─── Footprint map helpers ────────────────────────────────────────────────────

func _footprint_record(grid_pos: Vector2i) -> void:
	footprint_map[grid_pos] = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"recent": true,
		"visible": false
	}

func _footprint_update() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for pos in footprint_map.keys():
		var cell: Dictionary = footprint_map[pos]
		if cell["recent"] and (now - cell["timestamp"]) > FOOTPRINT_EXPIRY:
			cell["recent"] = false

func footprint_get(grid_pos: Vector2i) -> Dictionary:
	return footprint_map.get(grid_pos, {})

func _reveal_nightmare_tile(grid_pos: Vector2i) -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p.role == Role.NIGHTMARE:
			p.reveal_footprint_tile.rpc(grid_pos)
			return
	print("No nightmare player found to reveal tile on")

@rpc("call_local", "reliable")
func reveal_footprint_tile(grid_pos: Vector2i) -> void:
	if role != Role.NIGHTMARE:
		return
	if not footprint_map.has(grid_pos):
		footprint_map[grid_pos] = {
			"timestamp": 0.0,
			"recent": false,
			"visible": true
		}
	else:
		footprint_map[grid_pos]["visible"] = true

	var overlay = get_tree().get_first_node_in_group("footprint_overlay")
	if overlay:
		overlay.mark_tile_visible(grid_pos)

# ─── Input ────────────────────────────────────────────────────────────────────

func _on_action_collision_shape_entered(body) -> void:
	if body == self:
		return
	interaction_targets.append(body)

func _on_action_collision_shape_exited(body) -> void:
	interaction_targets.erase(body)

func _input(event):
	if not is_multiplayer_authority():
		return

	if event.is_action_pressed("ui_cancel") and is_sleeping:
		leave_bed.rpc()
		return

	if event.is_action_pressed("action") and is_sleeping and role == Role.DREAMER:
		if reveal_presses_remaining > 0:
			var grid_pos := Vector2i(position / GRID_SIZE)
			_reveal_nightmare_tile(grid_pos)
			reveal_presses_remaining -= 1
			print("Reveal presses remaining: ", reveal_presses_remaining)
		else:
			print("No reveal presses left this sleep session")
		return

	if event.is_action_pressed("action"):
		if interaction_targets.size() > 0:
			var target = interaction_targets[0]
			interaction_handling.rpc(target.get_path())

# ─── Process ──────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if role == Role.NIGHTMARE and is_multiplayer_authority():
		_footprint_update()

func _physics_process(_delta: float) -> void:
	if is_frozen or is_sleeping:
		return
	if not is_multiplayer_authority():
		position = position.move_toward(_target_position, GRID_SIZE)
		return
	_apply_movement_from_input()

# ─── Movement ─────────────────────────────────────────────────────────────────

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
	position = _target_position
	_update_sprite_direction()

	if role == Role.NIGHTMARE:
		var grid_pos := Vector2i(position / GRID_SIZE)
		_footprint_record(grid_pos)

# ─── Sprite direction ─────────────────────────────────────────────────────────

func _update_sprite_direction() -> void:
	if _last_direction == Vector2.LEFT:
		sprite.flip_h = true
	elif _last_direction == Vector2.RIGHT:
		sprite.flip_h = false

func _play_idle_animation() -> void:
	pass

# ─── Interactions ─────────────────────────────────────────────────────────────

@rpc("call_local")
func interaction_handling(target_path: NodePath):
	var target = get_node_or_null(target_path)
	if not target:
		return
	match role:
		Role.DETECTIVE:
			detective_interact(target)
		Role.NIGHTMARE:
			nightmare_interact(target)
		Role.DREAMER:
			dreamer_interact(target)

func detective_interact(target):
	if target.is_in_group("players"):
		if not flagged_players.has(target.name):
			flagged_players.append(target.name)
			print("Flagged: ", target.name)

func nightmare_interact(target):
	if target.is_in_group("players"):
		target.freeze.rpc()

func dreamer_interact(target):
	if is_sleeping:
		if target.is_in_group("Beds"):
			leave_bed.rpc()
	else:
		if target.is_in_group("Beds"):
			is_sleeping = true
			print("Player ", name, " went to sleep")
		elif target.is_in_group("players"):
			if target.is_sleeping:
				print("They are asleep")
			else:
				print("They are awake")

@rpc("call_local")
func freeze():
	is_frozen = true

@rpc("call_local")
func leave_bed():
	is_sleeping = false
	reveal_presses_remaining = MAX_REVEAL_PRESSES
	print("Player ", name, " woke up")

# ─── Cleanup ──────────────────────────────────────────────────────────────────

func _exit_tree() -> void:
	var camera = get_node_or_null("Camera2D")
	if camera:
		camera.global_position = _initial_camera_global_position
		camera.global_rotation = _initial_camera_global_rotation
		if camera.has_method("clear_current"):
			camera.clear_current()
		elif camera.has_method("set_current"):
			camera.set_current(false)
