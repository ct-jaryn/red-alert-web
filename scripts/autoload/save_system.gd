extends Node

## 存档与自定义地图的序列化与文件 IO。
## 对局状态本身归 GameManager 所有，本模块只负责采集/落盘/读取。

const MapData = preload("res://scripts/data/map_data.gd")

const SAVE_PATH := "user://savegame.json"
const CUSTOM_MAP_PATH := "user://custom_map.json"
const SAVE_VERSION := 1

## 待恢复的存档数据（主场景启动时消费）
var pending_load: Dictionary = {}

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func has_custom_map() -> bool:
	return FileAccess.file_exists(CUSTOM_MAP_PATH)

## 地图二维数组 <-> 字符串行编码（每格一位数字）
static func encode_map_rows(map: Array) -> Array:
	var rows := []
	for row in map:
		var s := ""
		for t in row:
			s += str(t)
		rows.append(s)
	return rows

static func decode_map_rows(rows: Array) -> Array:
	var map := []
	for s in rows:
		var row := []
		for i in range(str(s).length()):
			row.append(int(str(s)[i]))
		map.append(row)
	return map

## 保存地图编辑器绘制的自定义地图
func save_custom_map(map: Array) -> bool:
	if map.is_empty():
		return false
	var f = FileAccess.open(CUSTOM_MAP_PATH, FileAccess.WRITE)
	if not f:
		return false
	f.store_string(JSON.stringify({"map": encode_map_rows(map)}))
	return true

## 读取自定义地图；不存在或无效时返回空数组
func load_custom_map() -> Array:
	if not has_custom_map():
		return []
	var f = FileAccess.open(CUSTOM_MAP_PATH, FileAccess.READ)
	if not f:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	return decode_map_rows(parsed.get("map", []))

## 保存当前对局：地图、玩家经济/队列、全部实体、迷雾探索状态（联机不支持）
func save_game() -> bool:
	if NetworkManager.in_match:
		return false
	if GameManager.current_state != GameManager.GameState.PLAYING \
			and GameManager.current_state != GameManager.GameState.PAUSED:
		return false
	var data := {}
	data["version"] = SAVE_VERSION
	data["map_seed"] = GameManager.map_seed
	data["map_width"] = GameManager.map_width
	data["map_height"] = GameManager.map_height
	data["ai_difficulty"] = GameManager.ai_difficulty
	data["map"] = encode_map_rows(GameManager.game_map)
	var players_data := []
	for p in GameManager.players:
		players_data.append({
			"id": p.id,
			"type": p.player_type,
			"credits": p.credits,
			"queue": p.build_queue,
			"current_item": p.current_build_item,
			"progress": p.build_progress,
			"faction": p.faction,
			"defeated": p.is_defeated,
		})
	data["players"] = players_data
	var ents := []
	for b in UnitRegistry.get_buildings():
		ents.append({"kind": "b", "id": b.unit_id, "p": b.player_id, "x": b.global_position.x, "y": b.global_position.y, "hp": b.health})
	for u in UnitRegistry.get_units():
		ents.append({"kind": "u", "id": u.unit_id, "p": u.player_id, "x": u.global_position.x, "y": u.global_position.y, "hp": u.health, "ore": u.ore_carried})
	data["entities"] = ents
	var fog = get_tree().get_first_node_in_group("fog_of_war")
	if fog and fog.has_method("get_explored_rows"):
		data["fog"] = fog.get_explored_rows()
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("SaveSystem.save_game: 无法写入存档文件")
		return false
	f.store_string(JSON.stringify(data))
	return true

## 读取存档到 pending_load，由主场景启动时恢复
func load_save() -> bool:
	if not has_save():
		return false
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveSystem.load_save: 存档格式无效")
		return false
	# 版本号缺省视为 1；高于当前版本的存档拒绝加载
	if int(parsed.get("version", 1)) > SAVE_VERSION:
		push_warning("SaveSystem.load_save: 存档版本过新，无法加载")
		return false
	pending_load = parsed
	return true
