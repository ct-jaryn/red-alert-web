class_name MapRenderer
extends Node2D

const MapData = preload("res://scripts/data/map_data.gd")

var game_map: Array = []
var map_width: int = 0
var map_height: int = 0

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

func _draw() -> void:
	if game_map.is_empty():
		return
	var camera = get_viewport().get_camera_2d()
	if not camera:
		_draw_full_map()
		return
	var visible_rect = camera.get_visible_rect()
	var margin = MapData.TILE_SIZE * 2
	var start_x = maxi(0, int((visible_rect.position.x - margin) / MapData.TILE_SIZE))
	var start_y = maxi(0, int((visible_rect.position.y - margin) / MapData.TILE_SIZE))
	var end_x = mini(map_width, int((visible_rect.end.x + margin) / MapData.TILE_SIZE) + 1)
	var end_y = mini(map_height, int((visible_rect.end.y + margin) / MapData.TILE_SIZE) + 1)
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			_draw_tile(x, y)

func _draw_full_map() -> void:
	for y in range(map_height):
		for x in range(map_width):
			_draw_tile(x, y)

func _draw_tile(x: int, y: int) -> void:
	var terrain = game_map[y][x]
	var color = MapData.get_terrain_color(terrain)
	var rect = Rect2(
		x * MapData.TILE_SIZE,
		y * MapData.TILE_SIZE,
		MapData.TILE_SIZE,
		MapData.TILE_SIZE
	)
	draw_rect(rect, color)
	if terrain == MapData.TerrainType.ORE:
		var center = rect.position + rect.size / 2.0
		draw_circle(center, 4.0, Color(1, 0.85, 0))
		draw_circle(center + Vector2(3, -3), 3.0, Color(0.9, 0.75, 0))
	elif terrain == MapData.TerrainType.ROAD:
		draw_rect(rect.grow(-2), Color(0.3, 0.3, 0.3))
	elif terrain == MapData.TerrainType.WATER:
		var wave_offset = sin(x * 0.5 + y * 0.3) * 2.0
		draw_line(
			rect.position + Vector2(4, rect.size.y / 2 + wave_offset),
			rect.position + Vector2(rect.size.x - 4, rect.size.y / 2 + wave_offset),
			Color(0.15, 0.4, 0.8), 1.0
		)

func update_terrain_at(world_pos: Vector2) -> void:
	var tile = MapData.world_to_tile(world_pos)
	if tile.x >= 0 and tile.x < map_width and tile.y >= 0 and tile.y < map_height:
		queue_redraw()
