extends Node

## 实体索引：单位/建筑分桶登记，为全局查询提供 O(n) 内的快速通道，
## 替代散落各处的 get_nodes_in_group 全树扫描。
## 所有权变更（建筑被占领）安全：查询时读取节点当前 player_id。

var _units: Dictionary = {}      # instance_id -> GameUnit
var _buildings: Dictionary = {}  # instance_id -> GameBuilding

func register(entity: Node2D) -> void:
	var id = entity.get_instance_id()
	var bucket := _buildings if entity.is_in_group("buildings") else _units
	if bucket.has(id):
		return
	bucket[id] = entity
	if not entity.tree_exiting.is_connected(_on_entity_exiting.bind(id)):
		entity.tree_exiting.connect(_on_entity_exiting.bind(id))

func _on_entity_exiting(id: int) -> void:
	_units.erase(id)
	_buildings.erase(id)

## 实体死亡时显式注销（queue_free 到 tree_exiting 有延迟，需立即移出索引）
func unregister(entity: Node2D) -> void:
	var id = entity.get_instance_id()
	_units.erase(id)
	_buildings.erase(id)

## player_id 为 -1 时返回全部
func get_units(player_id: int = -1) -> Array:
	return _collect(_units, player_id)

func get_buildings(player_id: int = -1) -> Array:
	return _collect(_buildings, player_id)

func _collect(bucket: Dictionary, player_id: int) -> Array:
	var result := []
	for e in bucket.values():
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		if player_id >= 0 and e.player_id != player_id:
			continue
		result.append(e)
	return result

## 查找某玩家指定类型的建筑（如矿厂/建造厂），可选按距离取最近
func find_building(player_id: int, unit_id: String, near_pos: Vector2 = Vector2.INF) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for b in _buildings.values():
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue
		if b.player_id != player_id or b.unit_id != unit_id:
			continue
		if near_pos == Vector2.INF:
			return b
		var d = b.global_position.distance_squared_to(near_pos)
		if d < best_dist:
			best_dist = d
			best = b
	return best

func get_units_in_radius(pos: Vector2, radius: float, exclude: Node2D = null) -> Array:
	var result := []
	for bucket in [_units, _buildings]:
		for entity in bucket.values():
			if not is_instance_valid(entity):
				continue
			if entity == exclude:
				continue
			if entity.global_position.distance_to(pos) <= radius:
				result.append(entity)
	return result

func get_nearest_enemy(pos: Vector2, player_id: int, radius: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := radius
	for bucket in [_units, _buildings]:
		for entity in bucket.values():
			if not is_instance_valid(entity):
				continue
			if entity.player_id == player_id:
				continue
			var dist = entity.global_position.distance_to(pos)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = entity
	return nearest
