extends Node2D

## 战争迷雾：未探索全黑，已探索但无视野半暗，视野内清晰。
## 周期性按己方单位/建筑视野刷新，并隐藏视野外的敌方实体。

const MapData = preload("res://scripts/data/map_data.gd")
const UnitData = preload("res://scripts/data/unit_data.gd")

var _map_width: int = 0
var _map_height: int = 0
var _player_id: int = 0
var _explored: Array = []
var _visible_tiles: Array = []
var _refresh_timer: float = 0.0
var _last_camera_pos: Vector2 = Vector2.ZERO
var _last_zoom: Vector2 = Vector2.ONE

func _ready() -> void:
	add_to_group("fog_of_war")

func setup(width: int, height: int, p_id: int) -> void:
	_map_width = width
	_map_height = height
	_player_id = p_id
	_explored = []
	_visible_tiles = []
	for y in range(height):
		var row_e := []
		var row_v := []
		row_e.resize(width)
		row_e.fill(false)
		row_v.resize(width)
		row_v.fill(false)
		_explored.append(row_e)
		_visible_tiles.append(row_v)
	_refresh()

func _process(delta: float) -> void:
	if _map_width == 0:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0:
		_refresh_timer = 0.35
		_refresh()
	# 相机移动/缩放时重绘（视口裁剪需要）
	var camera = get_viewport().get_camera_2d()
	if camera:
		if camera.position.distance_to(_last_camera_pos) > 1.0 or camera.zoom != _last_zoom:
			_last_camera_pos = camera.position
			_last_zoom = camera.zoom
			queue_redraw()

func _refresh() -> void:
	for y in range(_map_height):
		var row = _visible_tiles[y]
		for x in range(_map_width):
			row[x] = false
	for node in UnitRegistry.get_units(_player_id) + UnitRegistry.get_buildings(_player_id):
		# 视野半径：优先取数据表 vision 字段，缺省按实体类型推断
		var radius: int = UnitData.get_unit_info(node.unit_id).get("vision", 0)
		if radius <= 0:
			if node is GameBuilding:
				radius = 7
			elif node.move_domain == "air":
				radius = 9
			else:
				radius = 6
		_mark_visible(MapData.world_to_tile(node.global_position), radius)
	_update_enemy_visibility()
	queue_redraw()

func _mark_visible(center: Vector2i, radius: int) -> void:
	var r2 = radius * radius
	for dy in range(-radius, radius + 1):
		var ty = center.y + dy
		if ty < 0 or ty >= _map_height:
			continue
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > r2:
				continue
			var tx = center.x + dx
			if tx < 0 or tx >= _map_width:
				continue
			_visible_tiles[ty][tx] = true
			_explored[ty][tx] = true

## 敌方单位仅视野内可见；敌方建筑探索过即保持可见
func _update_enemy_visibility() -> void:
	for node in UnitRegistry.get_units() + UnitRegistry.get_buildings():
		if node.player_id == _player_id:
			continue
		if node is GameBuilding:
			node.visible = is_explored(node.global_position)
		else:
			node.visible = is_visible_at(node.global_position)

func is_visible_at(world_pos: Vector2) -> bool:
	var tile = MapData.world_to_tile(world_pos)
	if tile.x < 0 or tile.x >= _map_width or tile.y < 0 or tile.y >= _map_height:
		return false
	return _visible_tiles[tile.y][tile.x]

func is_explored(world_pos: Vector2) -> bool:
	var tile = MapData.world_to_tile(world_pos)
	if tile.x < 0 or tile.x >= _map_width or tile.y < 0 or tile.y >= _map_height:
		return false
	return _explored[tile.y][tile.x]

## 小地图等外部绘制者只读探索网格（避免直接触碰私有字段）
func get_explored_grid() -> Array:
	return _explored

## 存档序列化：探索状态按行编码为 "01" 字符串
func get_explored_rows() -> Array:
	var rows := []
	for y in range(_map_height):
		var s := ""
		for x in range(_map_width):
			s += "1" if _explored[y][x] else "0"
		rows.append(s)
	return rows

func set_explored_rows(rows: Array) -> void:
	for y in range(mini(rows.size(), _map_height)):
		var s: String = str(rows[y])
		for x in range(mini(s.length(), _map_width)):
			if s[x] == "1":
				_explored[y][x] = true
	queue_redraw()

func _draw() -> void:
	if _map_width == 0:
		return
	var unexplored_color := Color(0.02, 0.02, 0.04, 1.0)
	var dim_color := Color(0.02, 0.02, 0.05, 0.45)
	var camera = get_viewport().get_camera_2d()
	var start_x := 0
	var start_y := 0
	var end_x := _map_width
	var end_y := _map_height
	if camera and camera.has_method("get_visible_rect"):
		var visible_rect = camera.get_visible_rect()
		var margin = MapData.TILE_SIZE * 2
		start_x = maxi(0, int((visible_rect.position.x - margin) / MapData.TILE_SIZE))
		start_y = maxi(0, int((visible_rect.position.y - margin) / MapData.TILE_SIZE))
		end_x = mini(_map_width, int((visible_rect.end.x + margin) / MapData.TILE_SIZE) + 1)
		end_y = mini(_map_height, int((visible_rect.end.y + margin) / MapData.TILE_SIZE) + 1)
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var rect = Rect2(x * MapData.TILE_SIZE, y * MapData.TILE_SIZE, MapData.TILE_SIZE, MapData.TILE_SIZE)
			if not _explored[y][x]:
				draw_rect(rect, unexplored_color)
			elif not _visible_tiles[y][x]:
				draw_rect(rect, dim_color)
