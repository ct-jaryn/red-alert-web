extends Node

## 全局对局状态：玩家经济/电力、建造队列、选择集、胜负判定。
## 实体生成通过信号请求（由主场景创建节点），寻路委托 Pathfinding，
## 存档 IO 委托 SaveSystem，AI 建筑选址归 AIController。

const MapData = preload("res://scripts/data/map_data.gd")
const UnitData = preload("res://scripts/data/unit_data.gd")

signal game_started
signal game_paused(is_paused: bool)
signal credits_changed(player_id: int, amount: int)
signal power_changed(player_id: int, current: int, max_power: int)
signal building_placed(building: Node)
signal building_destroyed(building: Node)
signal unit_created(unit: Node)
signal unit_destroyed(unit: Node)
signal build_queue_updated(player_id: int, queue: Array)
signal construction_complete(player_id: int, item_id: String)
signal selection_changed(selected: Array)
signal game_over(winner_id: int)
# 实体生成请求：由主场景订阅并实际实例化节点（单例不感知场景结构）
signal unit_spawn_requested(unit_id: String, player_id: int, pos: Vector2)
signal building_spawn_requested(building_id: String, player_id: int, pos: Vector2)
# 本地人类玩家的建筑就绪，等待手动放置（主场景启动放置模式）
signal building_ready_to_place(player_id: int, item_id: String)
# AI 玩家的建筑就绪，由 AIController 选址放置
signal ai_building_ready(player_id: int, item_id: String)

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }
enum PlayerType { HUMAN, AI }

var current_state: int = GameState.MENU
var map_seed: int = 0
var map_width: int = 80
var map_height: int = 60
var game_map: Array = []
# 本地玩家 ID：单机恒为 0；联机时主机=0、客户端=1
var local_player_id: int = 0
var _mp_menu_open: bool = false
# AI 难度：1=简单 2=普通 3=困难（主菜单选择，影响 AI 决策频率）
var ai_difficulty: int = 1
# 地图尺寸选项：0=小 1=中 2=大（主菜单选择，新游戏时应用）
var map_size_option: int = 1

const MAP_SIZE_PRESETS := [Vector2i(60, 45), Vector2i(80, 60), Vector2i(104, 78)]

class PlayerData:
	var id: int
	var player_type: int
	var credits: int = 5000
	var power_generated: int = 0
	var power_used: int = 0
	var built_buildings: Dictionary = {}  # {unit_id: count}
	var build_queue: Array = []
	var current_build_item: String = ""
	var build_progress: float = 0.0
	var faction: int = 0
	var is_defeated: bool = false

var players: Array[PlayerData] = []
var selected_units: Array = []
var pending_building_player: int = -1
var pending_building_id: String = ""
# 矿石瓦片索引：{Vector2i: true}，避免采矿车全图螺旋扫描
var _ore_tiles: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func reset() -> void:
	current_state = GameState.MENU
	players.clear()
	selected_units.clear()
	game_map.clear()
	_ore_tiles.clear()
	pending_building_id = ""
	pending_building_player = -1

func start_game(num_players: int = 2, seed_val: int = 0) -> void:
	if seed_val == 0:
		seed_val = randi()
	map_seed = seed_val
	players.clear()
	selected_units.clear()
	pending_building_id = ""
	pending_building_player = -1
	current_state = GameState.MENU
	for i in range(num_players):
		var p = PlayerData.new()
		p.id = i
		# 联机对战双方均为人类玩家
		if NetworkManager.in_match:
			p.player_type = PlayerType.HUMAN
		else:
			p.player_type = PlayerType.AI if i > 0 else PlayerType.HUMAN
		p.credits = 5000
		p.faction = 0 if i == 0 else 1
		players.append(p)
	if map_size_option == 3 and SaveSystem.has_custom_map():
		# 自定义地图开局：自动清理出生点并保证附近有矿
		game_map = SaveSystem.load_custom_map()
		map_height = game_map.size()
		map_width = game_map[0].size() if map_height > 0 else 0
		var rng = RandomNumberGenerator.new()
		rng.seed = map_seed
		MapData._clear_spawn_areas(game_map)
		MapData._force_ore_near_spawns(game_map, rng)
	else:
		var preset: Vector2i = MAP_SIZE_PRESETS[clampi(map_size_option, 0, MAP_SIZE_PRESETS.size() - 1)]
		map_width = preset.x
		map_height = preset.y
		game_map = MapData.generate_map(map_width, map_height, map_seed)
	Pathfinding.setup(game_map, map_width, map_height)
	_build_ore_index()
	current_state = GameState.PLAYING
	game_started.emit()

func toggle_pause() -> void:
	# 联机时不暂停模拟，仅切换菜单显示
	if NetworkManager.in_match:
		_mp_menu_open = not _mp_menu_open
		game_paused.emit(_mp_menu_open)
		return
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		game_paused.emit(true)
	elif current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		game_paused.emit(false)

func get_player(id: int) -> PlayerData:
	if id >= 0 and id < players.size():
		return players[id]
	return null

func add_credits(player_id: int, amount: int) -> void:
	var p = get_player(player_id)
	if p:
		p.credits += amount
		credits_changed.emit(player_id, p.credits)

func spend_credits(player_id: int, amount: int) -> bool:
	var p = get_player(player_id)
	if p and p.credits >= amount:
		p.credits -= amount
		credits_changed.emit(player_id, p.credits)
		return true
	return false

func update_power(player_id: int) -> void:
	var p = get_player(player_id)
	if not p:
		return
	p.power_generated = 0
	p.power_used = 0
	for b in UnitRegistry.get_buildings(player_id):
		var info = UnitData.get_unit_info(b.unit_id)
		var pw = info.get("power", 0)
		if pw > 0:
			p.power_generated += pw
		else:
			p.power_used += abs(pw)
	power_changed.emit(player_id, p.power_generated, p.power_used)

func has_power(player_id: int) -> bool:
	var p = get_player(player_id)
	if not p:
		return false
	return p.power_generated >= p.power_used

func register_building(building: Node) -> void:
	if not building is GameBuilding:
		return
	var p = get_player(building.player_id)
	if p:
		p.built_buildings[building.unit_id] = p.built_buildings.get(building.unit_id, 0) + 1
	Pathfinding.set_building_tiles_solid(building, true)
	NetworkManager.track_entity(building)
	update_power(building.player_id)
	building_placed.emit(building)

func unregister_building(building: Node) -> void:
	if not building is GameBuilding:
		return
	var p = get_player(building.player_id)
	if p:
		var count = p.built_buildings.get(building.unit_id, 0)
		if count <= 1:
			p.built_buildings.erase(building.unit_id)
		else:
			p.built_buildings[building.unit_id] = count - 1
	Pathfinding.set_building_tiles_solid(building, false)
	update_power(building.player_id)
	selected_units.erase(building)
	selection_changed.emit(selected_units)
	building_destroyed.emit(building)
	check_game_over()

func register_unit(unit: Node) -> void:
	NetworkManager.track_entity(unit)
	unit_created.emit(unit)

func unregister_unit(unit: Node) -> void:
	unit_destroyed.emit(unit)
	if unit in selected_units:
		selected_units.erase(unit)
		selection_changed.emit(selected_units)
	check_game_over()

func set_selection(units: Array) -> void:
	for u in selected_units:
		if is_instance_valid(u):
			u.set_selected(false)
	selected_units = units.duplicate()
	for u in selected_units:
		if is_instance_valid(u):
			u.set_selected(true)
	selection_changed.emit(selected_units)

func add_to_build_queue(player_id: int, item_id: String) -> void:
	var p = get_player(player_id)
	if not p:
		return
	var info = UnitData.get_unit_info(item_id)
	if info.is_empty():
		return
	if not UnitData.can_build(item_id, p.built_buildings):
		return
	if not spend_credits(player_id, info["cost"]):
		return
	p.build_queue.append(item_id)
	if p.current_build_item.is_empty():
		_start_next_build(player_id)
	build_queue_updated.emit(player_id, p.build_queue)

func _start_next_build(player_id: int) -> void:
	var p = get_player(player_id)
	if not p:
		return
	if p.build_queue.is_empty():
		p.current_build_item = ""
		p.build_progress = 0.0
		return
	p.current_build_item = p.build_queue[0]
	p.build_progress = 0.0

func _process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return
	if get_tree().paused:
		return
	# 联机客户端不跑本地模拟，建造进度由主机快照同步
	if NetworkManager.is_client():
		return
	for p in players:
		if p.current_build_item.is_empty():
			continue
		var info = UnitData.get_unit_info(p.current_build_item)
		if info.is_empty():
			continue
		var build_time = info.get("build_time", 5.0)
		if build_time <= 0:
			build_time = 0.1
		var speed_mult = 1.0
		if not has_power(p.id):
			speed_mult = 0.5
		p.build_progress += (delta / build_time) * speed_mult
		if p.build_progress >= 1.0:
			var overflow = p.build_progress - 1.0
			var completed_item = p.current_build_item
			p.build_queue.pop_front()
			_start_next_build(p.id)
			# 将多余进度应用到下一项
			if not p.current_build_item.is_empty():
				p.build_progress = overflow
			build_queue_updated.emit(p.id, p.build_queue)
			construction_complete.emit(p.id, completed_item)
			_spawn_completed_item(p.id, completed_item)

func _spawn_completed_item(player_id: int, item_id: String) -> void:
	var info = UnitData.get_unit_info(item_id)
	if info.is_empty():
		return
	if info.get("type", -1) == UnitData.UnitType.BUILDING:
		var p = get_player(player_id)
		if p and p.player_type == PlayerType.AI:
			ai_building_ready.emit(player_id, item_id)
		elif NetworkManager.is_remote_player(player_id):
			# 远端玩家的建筑就绪，通知其进入放置模式
			pending_building_player = player_id
			pending_building_id = item_id
			NetworkManager.notify_ready_to_place(item_id)
		else:
			pending_building_player = player_id
			pending_building_id = item_id
			building_ready_to_place.emit(player_id, item_id)
		return
	# 单位：找离基地最近的可生产建筑，从其集结点出兵
	var base = UnitRegistry.find_building(player_id, "construction_yard")
	var base_pos = base.global_position if base else Vector2.ZERO
	var best_building: Node = null
	var best_dist := INF
	for b in UnitRegistry.get_buildings(player_id):
		var b_info = UnitData.get_unit_info(b.unit_id)
		if item_id in b_info.get("produces", []):
			var d = b.global_position.distance_to(base_pos)
			if d < best_dist:
				best_dist = d
				best_building = b
	if best_building:
		unit_spawn_requested.emit(item_id, player_id, best_building.get_rally_point())
	else:
		# 生产建筑已毁，退还费用
		var refund = info.get("cost", 0)
		if refund > 0:
			add_credits(player_id, refund)

func check_game_over() -> void:
	if current_state == GameState.GAME_OVER:
		return
	# 联机客户端不做胜负判定，由主机同步结果
	if NetworkManager.is_client():
		return
	var alive_players := []
	for p in players:
		if not p.is_defeated:
			var has_buildings := false
			for b in UnitRegistry.get_buildings(p.id):
				if b.health > 0:
					has_buildings = true
					break
			if has_buildings:
				alive_players.append(p.id)
			else:
				p.is_defeated = true
	if alive_players.size() <= 1:
		var winner = alive_players[0] if alive_players.size() == 1 else -1
		current_state = GameState.GAME_OVER
		game_over.emit(winner)
		NetworkManager.on_host_game_over(winner)

func get_terrain_at(world_pos: Vector2) -> int:
	var tile = MapData.world_to_tile(world_pos)
	if tile.x < 0 or tile.x >= map_width or tile.y < 0 or tile.y >= map_height:
		return MapData.TerrainType.WATER
	return game_map[tile.y][tile.x]

func is_ore_at(world_pos: Vector2) -> bool:
	return get_terrain_at(world_pos) == MapData.TerrainType.ORE

func harvest_ore(world_pos: Vector2) -> bool:
	var tile = MapData.world_to_tile(world_pos)
	if tile.x >= 0 and tile.x < map_width and tile.y >= 0 and tile.y < map_height:
		if game_map[tile.y][tile.x] == MapData.TerrainType.ORE:
			apply_tile_change(tile.x, tile.y, MapData.TerrainType.GRASS)
			NetworkManager.report_tile_change(tile, MapData.TerrainType.GRASS)
			return true
	return false

## 修改地块并维护矿石索引（本地采集与联机同步共用入口）
func apply_tile_change(x: int, y: int, terrain: int) -> void:
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return
	game_map[y][x] = terrain
	var tile := Vector2i(x, y)
	if terrain == MapData.TerrainType.ORE:
		_ore_tiles[tile] = true
	else:
		_ore_tiles.erase(tile)

func _build_ore_index() -> void:
	_ore_tiles.clear()
	for y in range(map_height):
		for x in range(map_width):
			if game_map[y][x] == MapData.TerrainType.ORE:
				_ore_tiles[Vector2i(x, y)] = true

## 距 from_pos 最近的矿石瓦片中心；无矿时返回 Vector2.ZERO
func find_nearest_ore(from_pos: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_dist := INF
	for tile in _ore_tiles:
		var center = Vector2((tile.x + 0.5) * MapData.TILE_SIZE, (tile.y + 0.5) * MapData.TILE_SIZE)
		var d = center.distance_squared_to(from_pos)
		if d < best_dist:
			best_dist = d
			best = center
	return best

## 建筑放置合法性校验（人类放置预览、AI 选址、联机主机侧验证共用）：
## 地形匹配（水上建筑要求全水域）、不与现有建筑重叠、需邻接己方建筑
func can_place_at(player_id: int, building_id: String, pos: Vector2) -> bool:
	var info = UnitData.get_unit_info(building_id)
	if info.is_empty():
		return false
	var size: Vector2i = info.get("size", Vector2i(1, 1))
	var water_based: bool = info.get("water_based", false)
	var half_w = size.x * MapData.TILE_SIZE / 2.0
	var half_h = size.y * MapData.TILE_SIZE / 2.0
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
			var terrain = get_terrain_at(check_pos)
			if water_based:
				if terrain != MapData.TerrainType.WATER:
					return false
			elif not MapData.is_passable(terrain):
				return false
	var my_rect = Rect2(
		pos - Vector2(half_w, half_h),
		Vector2(size.x * MapData.TILE_SIZE, size.y * MapData.TILE_SIZE)
	)
	# 水上建筑离岸施工，邻接判定范围放宽到 3 格
	var adjacency_grow: float = MapData.TILE_SIZE * (3.0 if water_based else 0.5)
	var touches_existing := false
	for b in UnitRegistry.get_buildings():
		var b_info = UnitData.get_unit_info(b.unit_id)
		var b_size = b_info.get("size", Vector2i(1, 1))
		var b_half = Vector2(b_size.x, b_size.y) * MapData.TILE_SIZE / 2.0
		var b_rect = Rect2(b.global_position - b_half, b_half * 2.0)
		if b_rect.intersects(my_rect):
			return false
		if b.player_id == player_id:
			var expanded = b_rect.grow(adjacency_grow)
			if expanded.intersects(my_rect):
				touches_existing = true
	return touches_existing

func confirm_building_placement(pos: Vector2) -> void:
	if pending_building_id.is_empty() or pending_building_player < 0:
		return
	building_spawn_requested.emit(pending_building_id, pending_building_player, pos)
	pending_building_id = ""
	pending_building_player = -1

## 由 AIController 选址成功后调用，走与人类相同的生成通道
func request_spawn_building(building_id: String, player_id: int, pos: Vector2) -> void:
	building_spawn_requested.emit(building_id, player_id, pos)

## 按存档数据恢复全局状态（建筑计数由 register_building 重建）
func restore_state(data: Dictionary) -> void:
	map_seed = int(data.get("map_seed", 0))
	map_width = int(data.get("map_width", 80))
	map_height = int(data.get("map_height", 60))
	ai_difficulty = int(data.get("ai_difficulty", 1))
	players.clear()
	selected_units.clear()
	pending_building_id = ""
	pending_building_player = -1
	for pd in data.get("players", []):
		var p = PlayerData.new()
		p.id = int(pd.get("id", 0))
		p.player_type = int(pd.get("type", 0))
		p.credits = int(pd.get("credits", 0))
		for q in pd.get("queue", []):
			p.build_queue.append(str(q))
		p.current_build_item = str(pd.get("current_item", ""))
		p.build_progress = float(pd.get("progress", 0.0))
		p.faction = int(pd.get("faction", 0))
		p.is_defeated = bool(pd.get("defeated", false))
		players.append(p)
	game_map = SaveSystem.decode_map_rows(data.get("map", []))
	Pathfinding.setup(game_map, map_width, map_height)
	_build_ore_index()
	current_state = GameState.PLAYING
	game_started.emit()
