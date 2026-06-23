extends Node

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

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }
enum PlayerType { HUMAN, AI }

var current_state: int = GameState.MENU
var map_seed: int = 0
var map_width: int = 80
var map_height: int = 60
var game_map: Array = []

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func reset() -> void:
	current_state = GameState.MENU
	players.clear()
	selected_units.clear()
	game_map.clear()
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
		p.player_type = PlayerType.AI if i > 0 else PlayerType.HUMAN
		p.credits = 5000
		p.faction = 0 if i == 0 else 1
		players.append(p)
	game_map = MapData.generate_map(map_width, map_height, map_seed)
	current_state = GameState.PLAYING
	game_started.emit()

func toggle_pause() -> void:
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
	var tree = get_tree()
	if tree:
		for node in tree.get_nodes_in_group("buildings"):
			if not is_instance_valid(node):
				continue
			if not ("player_id" in node) or node.player_id != player_id:
				continue
			if not ("unit_id" in node):
				continue
			var info = UnitData.get_unit_info(node.unit_id)
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
	if not ("player_id" in building) or not ("unit_id" in building):
		return
	var p = get_player(building.player_id)
	if p:
		p.built_buildings[building.unit_id] = p.built_buildings.get(building.unit_id, 0) + 1
	update_power(building.player_id)
	building_placed.emit(building)

func unregister_building(building: Node) -> void:
	if not ("player_id" in building) or not ("unit_id" in building):
		return
	var p = get_player(building.player_id)
	if p:
		var count = p.built_buildings.get(building.unit_id, 0)
		if count <= 1:
			p.built_buildings.erase(building.unit_id)
		else:
			p.built_buildings[building.unit_id] = count - 1
	update_power(building.player_id)
	selected_units.erase(building)
	selection_changed.emit(selected_units)
	building_destroyed.emit(building)
	check_game_over()

func register_unit(unit: Node) -> void:
	unit_created.emit(unit)

func unregister_unit(unit: Node) -> void:
	unit_destroyed.emit(unit)
	if unit in selected_units:
		selected_units.erase(unit)
		selection_changed.emit(selected_units)
	check_game_over()

func set_selection(units: Array) -> void:
	for u in selected_units:
		if is_instance_valid(u) and u.has_method("set_selected"):
			u.set_selected(false)
	selected_units = units.duplicate()
	for u in selected_units:
		if is_instance_valid(u) and u.has_method("set_selected"):
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
			construction_complete.emit(p.id, completed_item)
			_spawn_completed_item(p.id, completed_item)

func _spawn_completed_item(player_id: int, item_id: String) -> void:
	var info = UnitData.get_unit_info(item_id)
	if info.is_empty():
		return
	if info.get("type", -1) == UnitData.UnitType.BUILDING:
		var p = get_player(player_id)
		if p and p.player_type == PlayerType.AI:
			_ai_place_building(player_id, item_id)
		else:
			pending_building_player = player_id
			pending_building_id = item_id
			var main = get_tree().current_scene
			if main and main.has_method("_on_building_ready_to_place"):
				main._on_building_ready_to_place(player_id, item_id)
		return
	var base_pos = Vector2.ZERO
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and b.player_id == player_id and b.unit_id == "construction_yard":
			base_pos = b.global_position
			break
	var buildings = get_tree().get_nodes_in_group("buildings")
	var best_building: Node = null
	var best_dist := 999999.0
	for b in buildings:
		if not is_instance_valid(b):
			continue
		if b.player_id != player_id:
			continue
		var b_info = UnitData.get_unit_info(b.unit_id)
		if item_id in b_info.get("produces", []):
			var d = b.global_position.distance_to(base_pos)
			if d < best_dist:
				best_dist = d
				best_building = b
	if best_building:
		var rally = best_building.global_position + Vector2(0, 60)
		if best_building.has_method("get_rally_point"):
			rally = best_building.get_rally_point()
		var main = get_tree().current_scene
		if main and main.has_method("_create_unit"):
			var unit = main._create_unit(item_id, player_id, rally)
			if unit:
				register_unit(unit)
				if unit.has_method("set_harvest_target") and item_id == "harvester":
					var ref = _find_refinery(player_id)
					if ref:
						unit.set_harvest_target(ref)
	else:
		# 生产建筑已毁，退还费用
		var refund = info.get("cost", 0)
		if refund > 0:
			add_credits(player_id, refund)

func _find_refinery(player_id: int) -> Node:
	var buildings = get_tree().get_nodes_in_group("buildings")
	for b in buildings:
		if is_instance_valid(b) and b.player_id == player_id and b.unit_id == "ore_refinery":
			return b
	return null

func check_game_over() -> void:
	if current_state == GameState.GAME_OVER:
		return
	var tree = get_tree()
	if not tree:
		return
	var alive_players := []
	for p in players:
		if not p.is_defeated:
			var has_buildings := false
			for node in tree.get_nodes_in_group("buildings"):
				if is_instance_valid(node) and node.player_id == p.id:
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
			game_map[tile.y][tile.x] = MapData.TerrainType.GRASS
			return true
	return false

func confirm_building_placement(pos: Vector2) -> void:
	if pending_building_id.is_empty() or pending_building_player < 0:
		return
	var main = get_tree().current_scene
	if main and main.has_method("_create_building"):
		var building = main._create_building(pending_building_id, pending_building_player, pos)
		if building:
			register_building(building)
	pending_building_id = ""
	pending_building_player = -1



func _ai_place_building(player_id: int, building_id: String) -> bool:
	var info = UnitData.get_unit_info(building_id)
	if info.is_empty():
		return false
	var size = info.get("size", Vector2i(1, 1))
	var base_pos := Vector2(-1.0, -1.0)
	for b in get_tree().get_nodes_in_group("buildings"):
		if is_instance_valid(b) and b.player_id == player_id and b.unit_id == "construction_yard":
			base_pos = b.global_position
			break
	if base_pos.x < 0:
		# 没有建造厂，退还费用
		add_credits(player_id, info.get("cost", 0))
		return false
	var best_pos = Vector2.ZERO
	var found = false
	for radius in range(2, 10):
		for angle_step in range(0, 360, 30):
			var offset = Vector2.from_angle(deg_to_rad(angle_step)) * radius * MapData.TILE_SIZE
			var place_pos = base_pos + offset
			if _ai_can_place_at(player_id, place_pos, size):
				best_pos = place_pos
				found = true
				break
		if found:
			break
	if not found:
		add_credits(player_id, info.get("cost", 0))
		return false
	var main = get_tree().current_scene
	if main and main.has_method("_create_building"):
		var building = main._create_building(building_id, player_id, best_pos)
		if building:
			register_building(building)
			return true
	add_credits(player_id, info.get("cost", 0))
	return false

func _ai_can_place_at(player_id: int, pos: Vector2, size: Vector2i) -> bool:
	var half_w = size.x * MapData.TILE_SIZE / 2.0
	var half_h = size.y * MapData.TILE_SIZE / 2.0
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
			if not MapData.is_passable(get_terrain_at(check_pos)):
				return false
	var my_rect = Rect2(
		pos - Vector2(half_w, half_h),
		Vector2(size.x * MapData.TILE_SIZE, size.y * MapData.TILE_SIZE)
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
		if b.player_id == player_id:
			var expanded = b_rect.grow(MapData.TILE_SIZE * 0.5)
			if expanded.intersects(my_rect):
				touches_existing = true
	return touches_existing
