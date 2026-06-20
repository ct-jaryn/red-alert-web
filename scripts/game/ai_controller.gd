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
]

var _unit_build_order := [
	"rifle_infantry",
	"rifle_infantry",
	"rifle_infantry",
	"harvester",
	"light_tank",
	"medium_tank",
	"medium_tank",
	"rifle_infantry",
	"rocket_soldier",
	"heavy_tank",
]

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
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
		if item_id not in p.built_buildings and UnitData.can_build(item_id, p.built_buildings):
			var info = UnitData.get_unit_info(item_id)
			if p.credits >= info.get("cost", 0):
				GameManager.add_to_build_queue(player_id, item_id)
				break

func _build_units() -> void:
	var p = GameManager.get_player(player_id)
	if not p:
		return
	var producers = get_tree().get_nodes_in_group("buildings")
	for producer in producers:
		if not is_instance_valid(producer):
			continue
		if producer.player_id != player_id:
			continue
		var info = UnitData.get_unit_info(producer.unit_id)
		var can_produce = info.get("produces", [])
		if can_produce.is_empty():
			continue
		for unit_id in _unit_build_order:
			if unit_id in can_produce:
				var unit_info = UnitData.get_unit_info(unit_id)
				if p.credits >= unit_info.get("cost", 0):
					GameManager.add_to_build_queue(player_id, unit_id)
				break

func _order_attack_wave() -> void:
	var units = get_tree().get_nodes_in_group("units")
	var my_units := []
	for u in units:
		if is_instance_valid(u) and u.player_id == player_id and "attack_damage" in u:
			if u.attack_damage > 0:
				my_units.append(u)
	_attack_wave += 1
	var required = 3 + _attack_wave
	if my_units.size() < required:
		return
	var enemy_pos = _find_enemy_base()
	if enemy_pos == Vector2.ZERO:
		return
	for u in my_units:
		if is_instance_valid(u) and u.has_method("move_to"):
			var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
			u.move_to(enemy_pos + offset)

func _get_base_position() -> Vector2:
	var buildings = get_tree().get_nodes_in_group("buildings")
	for b in buildings:
		if is_instance_valid(b) and b.player_id == player_id and b.unit_id == "construction_yard":
			return b.global_position
	return Vector2(MapData.TILE_SIZE * 10, MapData.TILE_SIZE * 10)

func _find_enemy_base() -> Vector2:
	var buildings = get_tree().get_nodes_in_group("buildings")
	for b in buildings:
		if is_instance_valid(b) and b.player_id != player_id and b.unit_id == "construction_yard":
			return b.global_position
	return Vector2.ZERO
