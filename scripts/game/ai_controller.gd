class_name AIController
extends Node

const MapData = preload("res://scripts/data/map_data.gd")
const UnitData = preload("res://scripts/data/unit_data.gd")

@export var player_id: int = 1
@export var difficulty: int = 1

var _decision_timer: float = 0.0
var _build_timer: float = 0.0
var _attack_timer: float = 0.0
var _attack_wave: int = 0
var _build_target_counts: Dictionary = {}
var _unit_order_index: int = 0

var _build_order := [
	"power_plant",
	"barracks",
	"ore_refinery",
	"power_plant",
	"war_factory",
	"power_plant",
	"radar",
	"turret_gun",
	"turret_gun",
	"power_plant",
	"airfield",
	"turret_missile",
	"power_plant",
]

var _unit_build_order := [
	"rifle_infantry",
	"rifle_infantry",
	"machine_gunner",
	"harvester",
	"light_tank",
	"apc",
	"medium_tank",
	"medium_tank",
	"grenadier",
	"rocket_soldier",
	"at_squad",
	"artillery",
	"fighter",
	"heavy_tank",
	"helicopter",
]

func _ready() -> void:
	difficulty = maxi(1, difficulty)
	for item_id in _build_order:
		_build_target_counts[item_id] = _build_target_counts.get(item_id, 0) + 1
	# 建筑生产完成后由本控制器选址落地
	GameManager.ai_building_ready.connect(_on_building_ready)

func _exit_tree() -> void:
	if GameManager.ai_building_ready.is_connected(_on_building_ready):
		GameManager.ai_building_ready.disconnect(_on_building_ready)

## AI 建筑选址：以建造厂为中心螺旋扫描合法位置，失败退款
func _on_building_ready(p_id: int, building_id: String) -> void:
	if p_id != player_id:
		return
	var info = UnitData.get_unit_info(building_id)
	if info.is_empty():
		return
	var base = UnitRegistry.find_building(player_id, "construction_yard")
	if base == null:
		# 没有建造厂，退还费用
		GameManager.add_credits(player_id, info.get("cost", 0))
		return
	var base_pos: Vector2 = base.global_position
	for radius in range(2, 10):
		for angle_step in range(0, 360, 30):
			var offset = Vector2.from_angle(deg_to_rad(angle_step)) * radius * MapData.TILE_SIZE
			var place_pos = base_pos + offset
			if GameManager.can_place_at(player_id, building_id, place_pos):
				GameManager.request_spawn_building(building_id, player_id, place_pos)
				return
	GameManager.add_credits(player_id, info.get("cost", 0))

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var p = GameManager.get_player(player_id)
	if not p or p.is_defeated:
		return
	_decision_timer -= delta
	if _decision_timer <= 0:
		_decision_timer = 1.5 / float(difficulty)
		_make_building_decisions()
	_build_timer -= delta
	if _build_timer <= 0:
		_build_timer = 2.0 / float(difficulty)
		_build_units()
	_attack_timer -= delta
	if _attack_timer <= 0:
		_attack_timer = 20.0 / float(difficulty)
		_order_attack_wave()

func _make_building_decisions() -> void:
	var p = GameManager.get_player(player_id)
	if not p:
		return
	if p.build_queue.size() > 1:
		return
	for item_id in _build_order:
		var built = p.built_buildings.get(item_id, 0)
		var queued = _count_in_queue(item_id, p)
		var target_count = _build_target_counts.get(item_id, 0)
		if built + queued >= target_count:
			continue
		if UnitData.can_build(item_id, p.built_buildings):
			var info = UnitData.get_unit_info(item_id)
			if p.credits >= info.get("cost", 0):
				GameManager.add_to_build_queue(player_id, item_id)
				break

func _count_in_queue(item_id: String, p) -> int:
	var count := 0
	for q in p.build_queue:
		if q == item_id:
			count += 1
	return count

func _build_units() -> void:
	var p = GameManager.get_player(player_id)
	if not p:
		return
	# 队列积压时不再入队，给建筑决策留出窗口，避免 AI 发展停滞
	if p.build_queue.size() >= 2:
		return
	# 收集当前可生产的单位集合
	var producible := {}
	for producer in UnitRegistry.get_buildings(player_id):
		for uid in UnitData.get_unit_info(producer.unit_id).get("produces", []):
			if UnitData.units.has(uid):
				producible[uid] = true
	if producible.is_empty():
		return
	# 轮转生产序列：从上次位置继续，保证兵种多样性
	for attempt in range(_unit_build_order.size()):
		var idx = (_unit_order_index + attempt) % _unit_build_order.size()
		var unit_id = _unit_build_order[idx]
		if not producible.has(unit_id):
			continue
		var unit_info = UnitData.get_unit_info(unit_id)
		if p.credits >= unit_info.get("cost", 0):
			GameManager.add_to_build_queue(player_id, unit_id)
			_unit_order_index = (idx + 1) % _unit_build_order.size()
			return

func _order_attack_wave() -> void:
	var my_units := []
	for u in UnitRegistry.get_units(player_id):
		if u.attack_damage > 0:
			my_units.append(u)
	var required = 3 + _attack_wave
	if my_units.size() < required:
		return
	# 优先查找敌方单位作为目标，其次找敌方建筑
	var enemy_target: Node2D = null
	var enemy_pos = Vector2.ZERO
	for b in UnitRegistry.get_buildings():
		if b.player_id != player_id:
			enemy_pos = b.global_position
			enemy_target = b
			break
	if enemy_pos == Vector2.ZERO:
		return
	_attack_wave += 1
	for u in my_units:
		if not is_instance_valid(u):
			continue
		# 让单位主动攻击目标，而不是单纯移动
		if enemy_target:
			u.attack_target(enemy_target)
		else:
			var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
			u.move_to(enemy_pos + offset)

func _get_base_position() -> Vector2:
	var base = UnitRegistry.find_building(player_id, "construction_yard")
	if base:
		return base.global_position
	return Vector2(MapData.TILE_SIZE * 10, MapData.TILE_SIZE * 10)

func _find_enemy_base() -> Vector2:
	for b in UnitRegistry.get_buildings():
		if b.player_id != player_id and b.unit_id == "construction_yard":
			return b.global_position
	return Vector2.ZERO
