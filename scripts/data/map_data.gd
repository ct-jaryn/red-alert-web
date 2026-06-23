class_name MapData
extends RefCounted

enum TerrainType { WATER, SAND, GRASS, ORE, ROCK, ROAD }

static var TILE_SIZE := 32

static func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / TILE_SIZE)), int(floor(world_pos.y / TILE_SIZE)))

static func get_player_tint(player_id: int, alpha: float = 0.3) -> Color:
	match player_id:
		0:
			return Color(0.2, 0.4, 1, alpha)
		1:
			return Color(1, 0.2, 0.2, alpha)
		_:
			return Color(0, 0, 0, 0)

static func generate_map(width: int, height: int, seed_val: int) -> Array:
	var map := []
	if width <= 0 or height <= 0:
		push_warning("MapData.generate_map: 非法的地图尺寸 %dx%d" % [width, height])
		return map
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	for y in range(height):
		var row := []
		for x in range(width):
			var noise_val = _simple_noise(x, y, rng)
			var terrain: int
			if noise_val < 0.2:
				terrain = TerrainType.WATER
			elif noise_val < 0.35:
				terrain = TerrainType.SAND
			elif noise_val < 0.7:
				terrain = TerrainType.GRASS
			elif noise_val < 0.8:
				terrain = TerrainType.ORE
			else:
				terrain = TerrainType.ROCK
			row.append(terrain)
		map.append(row)
	_add_roads(map, rng)
	_force_ore_near_spawns(map, rng)
	return map

static func _simple_noise(x: int, y: int, rng: RandomNumberGenerator) -> float:
	var val := 0.0
	val += sin(x * 0.1 + rng.randf() * 0.5) * 0.3
	val += cos(y * 0.08 + rng.randf() * 0.3) * 0.3
	val += sin((x + y) * 0.05) * 0.2
	val += rng.randf() * 0.2
	return clampf(val * 0.5 + 0.5, 0.0, 1.0)

static func _add_roads(map: Array, rng: RandomNumberGenerator) -> void:
	var height = map.size()
	var width = map[0].size()
	var mid_y: int = int(floor(height / 2.0))
	for x in range(width):
		if map[mid_y][x] != TerrainType.WATER:
			map[mid_y][x] = TerrainType.ROAD
	var mid_x: int = int(floor(width / 2.0))
	for y in range(height):
		if map[y][mid_x] != TerrainType.WATER:
			map[y][mid_x] = TerrainType.ROAD

static func _force_ore_near_spawns(map: Array, rng: RandomNumberGenerator) -> void:
	var height = map.size()
	var width = map[0].size()
	var spawn_candidates := [
		Vector2i(5, 5),
		Vector2i(width - 6, height - 6),
		Vector2i(5, height - 6),
		Vector2i(width - 6, 5),
	]
	for sp in spawn_candidates:
		var ore_count := 0
		for dx in range(-6, 7):
			for dy in range(-6, 7):
				var px = clampi(sp.x + dx, 0, width - 1)
				var py = clampi(sp.y + dy, 0, height - 1)
				if map[py][px] == TerrainType.ORE:
					ore_count += 1
		var needed = 8 - ore_count
		var max_attempts = 200
		while needed > 0 and max_attempts > 0:
			max_attempts -= 1
			var dx = rng.randi_range(-6, 6)
			var dy = rng.randi_range(-6, 6)
			var px = clampi(sp.x + dx, 0, width - 1)
			var py = clampi(sp.y + dy, 0, height - 1)
			if map[py][px] == TerrainType.GRASS:
				map[py][px] = TerrainType.ORE
				needed -= 1

static func get_terrain_color(terrain: int) -> Color:
	match terrain:
		TerrainType.WATER:
			return Color(0.1, 0.3, 0.7)
		TerrainType.SAND:
			return Color(0.85, 0.8, 0.55)
		TerrainType.GRASS:
			return Color(0.25, 0.55, 0.2)
		TerrainType.ORE:
			return Color(0.7, 0.6, 0.1)
		TerrainType.ROCK:
			return Color(0.45, 0.42, 0.38)
		TerrainType.ROAD:
			return Color(0.35, 0.35, 0.35)
		_:
			return Color(0.2, 0.2, 0.2)

static func is_passable(terrain: int) -> bool:
	match terrain:
		TerrainType.GRASS, TerrainType.SAND, TerrainType.ROAD, TerrainType.ORE:
			return true
		_:
			return false

static func get_move_cost(terrain: int) -> float:
	match terrain:
		TerrainType.ROAD:
			return 0.5
		TerrainType.SAND:
			return 1.5
		TerrainType.GRASS, TerrainType.ORE:
			return 1.0
		_:
			return INF

static func find_spawn_points(map: Array) -> Array:
	var height = map.size()
	if height == 0:
		return []
	var width = map[0].size()
	if width == 0:
		return []
	var candidates := [
		Vector2i(5, 5),
		Vector2i(width - 6, height - 6),
		Vector2i(5, height - 6),
		Vector2i(width - 6, 5),
	]
	var points := []
	for c in candidates:
		var found := false
		for radius in range(0, 10):
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					var px = clampi(c.x + dx, 0, width - 1)
					var py = clampi(c.y + dy, 0, height - 1)
					if is_passable(map[py][px]):
						points.append(Vector2i(px, py))
						found = true
						break
				if found:
					break
			if found:
				break
		if not found:
			points.append(Vector2i(clampi(c.x, 0, width - 1), clampi(c.y, 0, height - 1)))
	return points
