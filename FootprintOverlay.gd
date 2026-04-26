# FootprintOverlay.gd
# Attach this to a Node2D in your main scene.
# Add it to the "footprint_overlay" group in the Godot editor
# (Node panel → Groups → add "footprint_overlay").
# It should sit above your TileMap in the scene tree so it renders on top.

extends Node2D

# Colour of the revealed tile overlay
const OVERLAY_COLOR := Color(0.6, 0.2, 1.0, 0.45)  # purple, semi-transparent
const GRID_SIZE := 128

# Set of Vector2i positions that are currently visible
var _visible_tiles: Array[Vector2i] = []


func _ready() -> void:
	add_to_group("footprint_overlay")


# Called by player.gd's reveal_footprint_tile RPC on every peer.
func mark_tile_visible(grid_pos: Vector2i) -> void:
	if not _visible_tiles.has(grid_pos):
		_visible_tiles.append(grid_pos)
	queue_redraw()


# Called externally if you ever need to hide a tile again.
func unmark_tile_visible(grid_pos: Vector2i) -> void:
	_visible_tiles.erase(grid_pos)
	queue_redraw()


# Clears all visible tiles (e.g. at round end).
func clear_all() -> void:
	_visible_tiles.clear()
	queue_redraw()


func _draw() -> void:
	for grid_pos in _visible_tiles:
		var world_pos := Vector2(grid_pos) * GRID_SIZE
		draw_rect(Rect2(world_pos, Vector2(GRID_SIZE, GRID_SIZE)), OVERLAY_COLOR)
