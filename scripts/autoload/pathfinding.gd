extends Node

## 全局寻路服务：维护陆地/水域两套 AStarGrid2D 网格。
## 地图生成或存档恢复后由 GameManager 调用 setup() 重建；
## 建筑增减时通过 set_building_tiles_solid 同步障碍。

const MapData = preload("res://scripts/data/map_data.gd")
const UnitData = preload("res://scripts/data/unit_data.gd")

var _astar: AStarGrid2D = null
var _water_astar: AStarGrid2D = null
var _game_map: Array = []
var _map_width: int = 0
var _map_height: int = 0

func setup(game_map: Array, width: int, height: int) -> void:
	_game_map = game_map
	_map_width = width
	_map_height = height
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, width, height)
	_astar.cell_size = Vector2(MapData.TILE_SIZE, MapData.TILE_SIZE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	# 水域寻路网格：仅水面可通行（桥梁阻断航道）
	_water_astar = AStarGrid2D.new()
	_water_astar.region = Rect2i(0, 0, width, height)
	_water_astar.cell_size = Vector2(MapData.TILE_SIZE, MapData.TILE_SIZE)
	_water_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_water_astar.update()
	for y in range(height):
		for x in range(width):
			var terrain = game_map[y][x]
			if not MapData.is_passable(terrain):
				_astar.set_point_solid(Vector2i(x, y), true)
			else:
				_astar.set_point_weight_scale(Vector2i(x, y), MapData.get_move_cost(terrain))
			if terrain != MapData.TerrainType.WATER:
				_water_astar.set_point_solid(Vector2i(x, y), true)

func _get_building_tiles(building: Node2D) -> Array:
	var info = UnitData.get_unit_info(building.unit_id)
	var bsize: Vector2i = info.get("size", Vector2i(1, 1))
	var half = Vector2(bsize.x, bsize.y) * MapData.TILE_SIZE / 2.0
	var top_left = MapData.world_to_tile(building.global_position - half + Vector2(1, 1))
	var tiles := []
	for dx in range(bsize.x):
		for dy in range(bsize.y):
			var t = top_left + Vector2i(dx, dy)
			if t.x >= 0 and t.x < _map_width and t.y >= 0 and t.y < _map_height:
				tiles.append(t)
	return tiles

func set_building_tiles_solid(building: Node2D, solid: bool) -> void:
	if _astar == null:
		return
	for t in _get_building_tiles(building):
		_astar.set_point_solid(t, solid)
		if _water_astar and _game_map[t.y][t.x] == MapData.TerrainType.WATER:
			_water_astar.set_point_solid(t, solid)

func _clamp_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(clampi(tile.x, 0, _map_width - 1), clampi(tile.y, 0, _map_height - 1))

func _find_open_tile_near(tile: Vector2i, grid: AStarGrid2D = null) -> Vector2i:
	if grid == null:
		grid = _astar
	if not grid.is_point_solid(tile):
		return tile
	for radius in range(1, 6):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var t = _clamp_tile(tile + Vector2i(dx, dy))
				if not grid.is_point_solid(t):
					return t
	return tile

## 网格 A* 寻路：返回世界坐标路径点（瓦片中心），终点可达时以精确目标点结尾。
## domain: "ground" 陆地 / "water" 水域；目标不可达时返回部分路径。
func find_path(from_world: Vector2, to_world: Vector2, domain: String = "ground") -> PackedVector2Array:
	var result := PackedVector2Array()
	var grid := _water_astar if domain == "water" else _astar
	if grid == null:
		result.append(to_world)
		return result
	var from_tile = _find_open_tile_near(_clamp_tile(MapData.world_to_tile(from_world)), grid)
	var to_tile = _clamp_tile(MapData.world_to_tile(to_world))
	if domain == "water":
		# 舰船目标点落在陆地时，改为寻路到最近水域
		to_tile = _find_open_tile_near(to_tile, grid)
	if from_tile == to_tile:
		result.append(to_world if domain != "water" else _tile_center(to_tile))
		return result
	var id_path = grid.get_id_path(from_tile, to_tile, true)
	for i in range(1, id_path.size()):
		var t: Vector2i = id_path[i]
		result.append(_tile_center(t))
	if result.is_empty():
		result.append(to_world)
	elif domain != "water" and id_path[id_path.size() - 1] == to_tile and not grid.is_point_solid(to_tile):
		result[result.size() - 1] = to_world
	return result

func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2((tile.x + 0.5) * MapData.TILE_SIZE, (tile.y + 0.5) * MapData.TILE_SIZE)

## 寻找最近的水域瓦片中心（造船厂集结点/舰船下水点用），大范围螺旋搜索
func find_nearest_water(world_pos: Vector2) -> Vector2:
	if _water_astar == null:
		return world_pos
	var tile = _clamp_tile(MapData.world_to_tile(world_pos))
	if not _water_astar.is_point_solid(tile):
		return _tile_center(tile)
	for radius in range(1, 40):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var t = _clamp_tile(tile + Vector2i(dx, dy))
				if not _water_astar.is_point_solid(t):
					return _tile_center(t)
	return world_pos
