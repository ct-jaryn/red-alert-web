class_name BuildingPlacer
extends Node2D

const MapData = preload("res://scripts/data/map_data.gd")
const UnitData = preload("res://scripts/data/unit_data.gd")
const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const SpriteUtilScript = preload("res://scripts/ui/sprite_util.gd")

signal building_placed(building_id: String, pos: Vector2)
signal placement_cancelled(building_id: String)

var is_placing: bool = false
var current_building_id: String = ""
var _ghost: Node2D
var _player_id: int = 0
var _valid_color := Color(0, 1, 0, 0.3)
var _invalid_color := Color(1, 0, 0, 0.3)

func start_placement(building_id: String, player_id: int) -> void:
	cancel_placement()
	current_building_id = building_id
	_player_id = player_id
	is_placing = true
	_create_ghost()

func cancel_placement() -> void:
	if is_placing and not current_building_id.is_empty():
		placement_cancelled.emit(current_building_id)
	is_placing = false
	current_building_id = ""
	if _ghost:
		_ghost.queue_free()
		_ghost = null

func _create_ghost() -> void:
	_ghost = Node2D.new()
	add_child(_ghost)
	var info = UnitData.get_unit_info(current_building_id)
	var size_cells = info.get("size", Vector2i(1, 1))
	var w = size_cells.x * MapData.TILE_SIZE
	var h = size_cells.y * MapData.TILE_SIZE
	var tex = SpriteUtilScript.get_texture(current_building_id)
	if tex:
		var tex_rect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(w, h)
		tex_rect.size = Vector2(w, h)
		tex_rect.position = -Vector2(w, h) / 2.0
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.texture = tex
		tex_rect.modulate = Color(1, 1, 1, 0.6)
		_ghost.add_child(tex_rect)
	else:
		var rect = ColorRect.new()
		rect.size = Vector2(w, h)
		rect.position = -Vector2(w, h) / 2.0
		rect.color = _valid_color
		_ghost.add_child(rect)
	var border = ReferenceRect.new()
	border.size = Vector2(w, h)
	border.position = -Vector2(w, h) / 2.0
	border.border_color = Color(0, 1, 0, 0.6)
	border.border_width = 2.0
	border.editor_only = false
	_ghost.add_child(border)
	var label = Label.new()
	label.text = info.get("name", current_building_id)
	label.position = -Vector2(w, h) / 2.0 + Vector2(4, 4)
	label.add_theme_font_override("font", FontUtilScript.get_font())
	label.add_theme_font_size_override("font_size", 10)
	_ghost.add_child(label)

func _process(_delta: float) -> void:
	if not is_placing or not _ghost:
		return
	_ghost.global_position = _snap_to_grid(get_global_mouse_position())
	var valid = _can_place_at(_ghost.global_position)
	var rect = _ghost.get_child(0) as ColorRect
	if rect:
		rect.color = _valid_color if valid else _invalid_color
	var border = _ghost.get_child(1) as ReferenceRect
	if border:
		border.border_color = Color(0, 1, 0, 0.6) if valid else Color(1, 0, 0, 0.6)

func _snap_to_grid(pos: Vector2) -> Vector2:
	var info = UnitData.get_unit_info(current_building_id)
	var size_cells = info.get("size", Vector2i(1, 1))
	var snapped_x = snapped(pos.x, MapData.TILE_SIZE)
	var snapped_y = snapped(pos.y, MapData.TILE_SIZE)
	if size_cells.x % 2 == 0:
		snapped_x += MapData.TILE_SIZE / 2.0
	if size_cells.y % 2 == 0:
		snapped_y += MapData.TILE_SIZE / 2.0
	return Vector2(snapped_x, snapped_y)

func try_place() -> bool:
	if not is_placing:
		return false
	var pos = _snap_to_grid(get_global_mouse_position())
	if not _can_place_at(pos):
		return false
	building_placed.emit(current_building_id, pos)
	is_placing = false
	current_building_id = ""
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	return true

func _can_place_at(pos: Vector2) -> bool:
	var info = UnitData.get_unit_info(current_building_id)
	var size_cells = info.get("size", Vector2i(1, 1))
	var half_w = size_cells.x * MapData.TILE_SIZE / 2.0
	var half_h = size_cells.y * MapData.TILE_SIZE / 2.0
	var corners = [
		pos + Vector2(-half_w, -half_h),
		pos + Vector2(half_w, -half_h),
		pos + Vector2(-half_w, half_h),
		pos + Vector2(half_w, half_h),
	]
	for corner in corners:
		var terrain = GameManager.get_terrain_at(corner)
		if not MapData.is_passable(terrain):
			return false
	var my_rect = Rect2(
		pos - Vector2(half_w, half_h),
		Vector2(size_cells.x * MapData.TILE_SIZE, size_cells.y * MapData.TILE_SIZE)
	)
	var buildings = get_tree().get_nodes_in_group("buildings")
	var touches_existing := false
	for b in buildings:
		if not is_instance_valid(b):
			continue
		var b_info = UnitData.get_unit_info(b.unit_id)
		var b_size = b_info.get("size", Vector2i(1, 1))
		var b_half_w = b_size.x * MapData.TILE_SIZE / 2.0
		var b_half_h = b_size.y * MapData.TILE_SIZE / 2.0
		var b_rect = Rect2(
			b.global_position - Vector2(b_half_w, b_half_h),
			Vector2(b_size.x * MapData.TILE_SIZE, b_size.y * MapData.TILE_SIZE)
		)
		if b_rect.intersects(my_rect):
			return false
		if b.player_id == _player_id:
			var expanded = b_rect.grow(MapData.TILE_SIZE * 0.5)
			if expanded.intersects(my_rect):
				touches_existing = true
	return touches_existing
