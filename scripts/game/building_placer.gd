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
	if info.is_empty():
		cancel_placement()
		return
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
	# 更新颜色 — 适配 ColorRect（无纹理）和 TextureRect（有纹理）
	var child0 = _ghost.get_child(0)
	if child0 is ColorRect:
		child0.color = _valid_color if valid else _invalid_color
	elif child0 is TextureRect:
		child0.modulate = Color(1, 1, 1, 0.6) if valid else Color(1, 0.3, 0.3, 0.6)
	# 更新边框颜色
	for child in _ghost.get_children():
		if child is ReferenceRect:
			child.border_color = Color(0, 1, 0, 0.6) if valid else Color(1, 0, 0, 0.6)
			break

func _snap_to_grid(pos: Vector2) -> Vector2:
	var info = UnitData.get_unit_info(current_building_id)
	var size_cells = info.get("size", Vector2i(1, 1))
	var snapped_x = snapped(pos.x, MapData.TILE_SIZE)
	var snapped_y = snapped(pos.y, MapData.TILE_SIZE)
	# 奇数尺寸建筑中心对齐到瓦片中心；偶数尺寸对齐到瓦片边界
	if size_cells.x % 2 == 1:
		snapped_x += MapData.TILE_SIZE / 2.0
	if size_cells.y % 2 == 1:
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
	# 遍历建筑覆盖的所有瓦片，确保全部可通过
	var min_tile_x := int(floor((pos.x - half_w) / MapData.TILE_SIZE))
	var max_tile_x := int(floor((pos.x + half_w - 0.001) / MapData.TILE_SIZE))
	var min_tile_y := int(floor((pos.y - half_h) / MapData.TILE_SIZE))
	var max_tile_y := int(floor((pos.y + half_h - 0.001) / MapData.TILE_SIZE))
	for tx in range(min_tile_x, max_tile_x + 1):
		for ty in range(min_tile_y, max_tile_y + 1):
			var check_pos := Vector2(
				tx * MapData.TILE_SIZE + MapData.TILE_SIZE / 2.0,
				ty * MapData.TILE_SIZE + MapData.TILE_SIZE / 2.0
			)
			if not MapData.is_passable(GameManager.get_terrain_at(check_pos)):
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
