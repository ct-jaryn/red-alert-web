class_name MapRenderer
extends Node2D

const MapData = preload("res://scripts/data/map_data.gd")
const SpriteUtilScript = preload("res://scripts/ui/sprite_util.gd")

const TERRAIN_DIR := "res://assets/sprites/terrain/elite_command_art_terrain/tileset-sliced"

# 地形基底贴图：从六边形瓦片中心裁剪方形区域（避开透明角）
static var _tile_tex_cache: Dictionary = {}

static func _get_terrain_tex(idx: int) -> Texture2D:
	if _tile_tex_cache.has(idx):
		return _tile_tex_cache[idx]
	var src = load("%s/%d.png" % [TERRAIN_DIR, idx]) as Texture2D
	if not src:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = src
	var w = src.get_width()
	var h = src.get_height()
	atlas.region = Rect2(w * 0.25, h * 0.25, w * 0.5, h * 0.5)
	_tile_tex_cache[idx] = atlas
	return atlas

# 完整六边形装饰素材（树丛/礁石等，带透明背景直接绘制）
static var _decor_tex_cache: Dictionary = {}

static func _get_decor_tex(idx: int) -> Texture2D:
	if _decor_tex_cache.has(idx):
		return _decor_tex_cache[idx]
	var tex = load("%s/%d.png" % [TERRAIN_DIR, idx]) as Texture2D
	_decor_tex_cache[idx] = tex
	return tex

var game_map: Array = []
var map_width: int = 0
var map_height: int = 0
var _last_camera_pos: Vector2 = Vector2.ZERO
var _last_zoom: Vector2 = Vector2.ONE

func setup_map(map: Array) -> void:
	if map.is_empty() or map[0].is_empty():
		game_map = []
		map_width = 0
		map_height = 0
		push_warning("MapRenderer.setup_map: 收到空地图")
		return
	game_map = map
	map_height = map.size()
	map_width = map[0].size()
	queue_redraw()

func _process(_delta: float) -> void:
	# 相机移动或缩放时重绘地图（视口裁剪需要）
	var camera = get_viewport().get_camera_2d()
	if camera:
		if camera.position.distance_to(_last_camera_pos) > 1.0 or camera.zoom != _last_zoom:
			_last_camera_pos = camera.position
			_last_zoom = camera.zoom
			queue_redraw()

func _draw() -> void:
	if game_map.is_empty():
		return
	var camera = get_viewport().get_camera_2d()
	if not camera:
		_draw_full_map()
		return
	# 缩得很远时跳过细节绘制，控制绘制量
	var detail: bool = camera.zoom.x >= 0.55
	var visible_rect = camera.get_visible_rect()
	var margin = MapData.TILE_SIZE * 2
	var start_x = maxi(0, int((visible_rect.position.x - margin) / MapData.TILE_SIZE))
	var start_y = maxi(0, int((visible_rect.position.y - margin) / MapData.TILE_SIZE))
	var end_x = mini(map_width, int((visible_rect.end.x + margin) / MapData.TILE_SIZE) + 1)
	var end_y = mini(map_height, int((visible_rect.end.y + margin) / MapData.TILE_SIZE) + 1)
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			_draw_tile(x, y, detail)
	_draw_map_border()

func _draw_full_map() -> void:
	for y in range(map_height):
		for x in range(map_width):
			_draw_tile(x, y, true)
	_draw_map_border()

func _draw_map_border() -> void:
	# 地图边界描边，让玩家看清可活动范围
	var bounds = Rect2(0, 0, map_width * MapData.TILE_SIZE, map_height * MapData.TILE_SIZE)
	draw_rect(bounds, Color(0.05, 0.05, 0.05, 0.9), false, 4.0)

## 每格确定性伪随机（0~1），用于稳定的色彩/细节变化
func _tile_rand(x: int, y: int, salt: int = 0) -> float:
	var h: int = x * 73856093 ^ y * 19349663 ^ salt * 83492791
	h = (h ^ (h >> 13)) * 1274126177
	return float(abs(h) % 1000) / 1000.0

func _terrain_at(x: int, y: int) -> int:
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return MapData.TerrainType.WATER
	return game_map[y][x]

func _draw_tile(x: int, y: int, detail: bool) -> void:
	var terrain = game_map[y][x]
	var color = MapData.get_terrain_color(terrain)
	# 确定性色彩抖动，打破大片纯色的单调感
	var v = _tile_rand(x, y) * 0.14 - 0.07
	if v > 0:
		color = color.lightened(v)
	else:
		color = color.darkened(-v)
	var rect = Rect2(
		x * MapData.TILE_SIZE,
		y * MapData.TILE_SIZE,
		MapData.TILE_SIZE,
		MapData.TILE_SIZE
	)
	# 深水判定：四邻均为水时加深，形成岸线层次
	var is_deep_water := false
	if terrain == MapData.TerrainType.WATER:
		if _terrain_at(x - 1, y) == MapData.TerrainType.WATER \
				and _terrain_at(x + 1, y) == MapData.TerrainType.WATER \
				and _terrain_at(x, y - 1) == MapData.TerrainType.WATER \
				and _terrain_at(x, y + 1) == MapData.TerrainType.WATER:
			is_deep_water = true
	# 基底：草/沙/水用 Elite Command 地形贴图，其余用纯色
	var mod_v = 0.93 + _tile_rand(x, y) * 0.14
	var base_mod = Color(mod_v, mod_v, mod_v)
	match terrain:
		MapData.TerrainType.GRASS, MapData.TerrainType.ORE:
			var t = _get_terrain_tex(0)
			if t:
				draw_texture_rect(t, rect, false, base_mod)
			else:
				draw_rect(rect, color)
		MapData.TerrainType.SAND:
			var t = _get_terrain_tex(4)
			if t:
				draw_texture_rect(t, rect, false, base_mod)
			else:
				draw_rect(rect, color)
		MapData.TerrainType.WATER:
			var t = _get_terrain_tex(7 if is_deep_water else 1)
			if t:
				var wmod = base_mod if not is_deep_water else Color(mod_v * 0.65, mod_v * 0.7, mod_v * 0.85)
				draw_texture_rect(t, rect, false, wmod)
			else:
				draw_rect(rect, color if not is_deep_water else color.darkened(0.25))
		MapData.TerrainType.BRIDGE:
			# 桥下先铺水面
			var t = _get_terrain_tex(1)
			if t:
				draw_texture_rect(t, rect, false, base_mod)
			else:
				draw_rect(rect, Color(0.1, 0.3, 0.7))
			var horizontal = _terrain_at(x - 1, y) in [MapData.TerrainType.ROAD, MapData.TerrainType.BRIDGE] \
					or _terrain_at(x + 1, y) in [MapData.TerrainType.ROAD, MapData.TerrainType.BRIDGE]
			var btex = SpriteUtilScript.get_indicator("bridge_h" if horizontal else "bridge_v")
			if btex:
				draw_texture_rect(btex, rect, false)
			else:
				draw_rect(rect.grow(-3), color)
		_:
			draw_rect(rect, color)
	if not detail:
		return
	# 与不同地形相邻处画暗色过渡边，柔化格子拼接感
	var edge_color = Color(0, 0, 0, 0.18)
	if _terrain_at(x, y - 1) != terrain:
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), edge_color, 2.0)
	if _terrain_at(x - 1, y) != terrain:
		draw_line(rect.position, rect.position + Vector2(0, rect.size.y), edge_color, 2.0)
	match terrain:
		MapData.TerrainType.ORE:
			# 矿石晶簇：数量/位置/大小每格不同
			var count = 2 + int(_tile_rand(x, y, 5) * 3.0)
			for i in range(count):
				var ox = 5.0 + _tile_rand(x, y, i * 2 + 1) * 22.0
				var oy = 5.0 + _tile_rand(x, y, i * 2 + 2) * 22.0
				var r = 1.5 + _tile_rand(x, y, i + 11) * 2.5
				var p = rect.position + Vector2(ox, oy)
				draw_circle(p + Vector2(1, 1), r, Color(0.45, 0.35, 0.05))
				draw_circle(p, r, Color(1, 0.82, 0.15))
		MapData.TerrainType.ROAD:
			draw_rect(rect.grow(-2), Color(0.3, 0.3, 0.3))
			# 道路中心线虚线
			if int(x + y) % 2 == 0:
				draw_rect(Rect2(rect.position + Vector2(13, 13), Vector2(6, 6)), Color(0.45, 0.42, 0.3, 0.5))
		MapData.TerrainType.WATER:
			# 浅水波纹 + 深水礁石装饰（素材 8）
			if is_deep_water and _tile_rand(x, y, 15) > 0.92:
				var reef = _get_decor_tex(8)
				if reef:
					draw_texture_rect(reef, rect.grow(-4), false, Color(1, 1, 1, 0.8))
			elif not is_deep_water:
				var wave_offset = sin(x * 0.5 + y * 0.3) * 2.0
				draw_line(
					rect.position + Vector2(4, rect.size.y / 2 + wave_offset),
					rect.position + Vector2(rect.size.x - 4, rect.size.y / 2 + wave_offset),
					Color(0.35, 0.55, 0.85, 0.5), 1.5
				)
		MapData.TerrainType.GRASS:
			# 树丛装饰（素材 3）+ 零星草丛
			var tr = _tile_rand(x, y, 3)
			if tr > 0.88:
				var tree = _get_decor_tex(3)
				if tree:
					draw_texture_rect(tree, rect.grow(-2), false)
			elif tr > 0.6:
				var gx = 6.0 + _tile_rand(x, y, 4) * 20.0
				var gy = 6.0 + _tile_rand(x, y, 6) * 20.0
				var gc = Color(0.16, 0.42, 0.13)
				draw_circle(rect.position + Vector2(gx, gy), 2.0, gc)
				draw_circle(rect.position + Vector2(gx + 4, gy + 2), 1.5, gc)
		MapData.TerrainType.ROCK:
			# 山丘装饰（素材 2）+ 碎石阴影
			if _tile_rand(x, y, 8) > 0.85:
				var hill = _get_decor_tex(2)
				if hill:
					draw_texture_rect(hill, rect.grow(-2), false, Color(0.8, 0.78, 0.75))
			elif _tile_rand(x, y, 8) > 0.4:
				var rx = 6.0 + _tile_rand(x, y, 9) * 18.0
				var ry = 6.0 + _tile_rand(x, y, 10) * 18.0
				draw_circle(rect.position + Vector2(rx + 1, ry + 1), 3.5, Color(0.3, 0.28, 0.25))
				draw_circle(rect.position + Vector2(rx, ry), 3.0, Color(0.55, 0.52, 0.47))
		MapData.TerrainType.SAND:
			# 沙地波纹
			if _tile_rand(x, y, 12) > 0.55:
				var sy = 8.0 + _tile_rand(x, y, 13) * 16.0
				draw_line(
					rect.position + Vector2(6, sy),
					rect.position + Vector2(rect.size.x - 6, sy + 2),
					Color(0.75, 0.68, 0.45, 0.6), 1.0
				)

func update_terrain_at(world_pos: Vector2) -> void:
	var tile = MapData.world_to_tile(world_pos)
	if tile.x >= 0 and tile.x < map_width and tile.y >= 0 and tile.y < map_height:
		queue_redraw()
