extends Node2D

const MapData = preload("res://scripts/data/map_data.gd")
const UnitData = preload("res://scripts/data/unit_data.gd")
const MapRendererScript = preload("res://scripts/game/map_renderer.gd")
const GameCameraScript = preload("res://scripts/game/game_camera.gd")
const SelectionBoxScript = preload("res://scripts/game/selection_box.gd")
const HUDScript = preload("res://scripts/ui/hud.gd")
const AIControllerScript = preload("res://scripts/game/ai_controller.gd")
const BuildingPlacerScript = preload("res://scripts/game/building_placer.gd")
const EffectsScript = preload("res://scripts/game/effects.gd")
const FogOfWarScript = preload("res://scripts/game/fog_of_war.gd")
const BuildingScene = preload("res://scenes/buildings/building.tscn")
const UnitScene = preload("res://scenes/units/unit.tscn")

var map_renderer: Node2D
var camera: Camera2D
var selection_box: Node2D
var hud: CanvasLayer
var ai_controller: Node
var building_placer: Node2D
var effects: Node2D
var fog_of_war: Node2D
var buildings_node: Node2D
var units_node: Node2D
var effects_node: Node2D
var _selection_start: Vector2 = Vector2.ZERO
var _is_selecting: bool = false
var _unit_groups: Dictionary = {}

func _ready() -> void:
	_setup_nodes()
	_start_game()

func _setup_nodes() -> void:
	buildings_node = Node2D.new()
	buildings_node.name = "Buildings"
	add_child(buildings_node)
	units_node = Node2D.new()
	units_node.name = "Units"
	add_child(units_node)
	effects_node = Node2D.new()
	effects_node.name = "EffectsContainer"
	add_child(effects_node)
	map_renderer = MapRendererScript.new()
	map_renderer.name = "MapRenderer"
	map_renderer.z_index = -10
	add_child(map_renderer)
	effects = EffectsScript.new()
	effects.name = "Effects"
	effects.z_index = 8
	add_child(effects)
	fog_of_war = FogOfWarScript.new()
	fog_of_war.name = "FogOfWar"
	fog_of_war.z_index = 6
	add_child(fog_of_war)
	camera = GameCameraScript.new()
	camera.name = "GameCamera"
	add_child(camera)
	camera.make_current()
	selection_box = SelectionBoxScript.new()
	selection_box.name = "SelectionBox"
	selection_box.z_index = 5
	add_child(selection_box)
	selection_box.selection_finished.connect(_on_selection_finished)
	building_placer = BuildingPlacerScript.new()
	building_placer.name = "BuildingPlacer"
	building_placer.z_index = 7
	add_child(building_placer)
	building_placer.building_placed.connect(_on_building_placed)
	building_placer.placement_cancelled.connect(_on_placement_cancelled)
	hud = HUDScript.new()
	hud.name = "HUD"
	add_child(hud)
	ai_controller = AIControllerScript.new()
	ai_controller.name = "AIController"
	ai_controller.player_id = 1
	ai_controller.difficulty = 1
	add_child(ai_controller)

func _start_game() -> void:
	GameManager.start_game(2)
	map_renderer.setup_map(GameManager.game_map)
	hud._minimap.setup_map(GameManager.game_map)
	fog_of_war.setup(GameManager.map_width, GameManager.map_height, 0)
	_spawn_starting_units()
	var spawn_points = MapData.find_spawn_points(GameManager.game_map)
	if spawn_points.size() > 0:
		var sp = spawn_points[0]
		camera.position = Vector2(sp.x * MapData.TILE_SIZE, sp.y * MapData.TILE_SIZE)

func _spawn_starting_units() -> void:
	var spawn_points = MapData.find_spawn_points(GameManager.game_map)
	for i in range(mini(spawn_points.size(), GameManager.players.size())):
		var sp = spawn_points[i]
		var world_pos = Vector2(sp.x * MapData.TILE_SIZE, sp.y * MapData.TILE_SIZE)
		_spawn_base(world_pos, i)

func _spawn_base(pos: Vector2, p_id: int) -> void:
	var cy = _create_building("construction_yard", p_id, pos)
	if cy:
		GameManager.register_building(cy)
	var pp = _create_building("power_plant", p_id, pos + Vector2(-120, 0))
	if pp:
		GameManager.register_building(pp)
	var bar = _create_building("barracks", p_id, pos + Vector2(0, -100))
	if bar:
		GameManager.register_building(bar)
	var ref = _create_building("ore_refinery", p_id, pos + Vector2(120, 0))
	if ref:
		GameManager.register_building(ref)
	for i in range(3):
		var rifle = _create_unit("rifle_infantry", p_id, pos + Vector2(-60 + i * 30, 80))
		if rifle:
			GameManager.register_unit(rifle)
	var harvester = _create_unit("harvester", p_id, pos + Vector2(0, 100))
	if harvester:
		GameManager.register_unit(harvester)
		if ref:
			harvester.set_harvest_target(ref)

func _create_building(building_id: String, p_id: int, pos: Vector2) -> Node:
	var building = BuildingScene.instantiate()
	building.unit_id = building_id
	building.player_id = p_id
	building.position = pos
	buildings_node.add_child(building)
	return building

func _create_unit(unit_id: String, p_id: int, pos: Vector2) -> Node:
	var unit = UnitScene.instantiate()
	unit.unit_id = unit_id
	unit.player_id = p_id
	unit.position = pos
	units_node.add_child(unit)
	return unit

func _on_building_placed(building_id: String, pos: Vector2) -> void:
	GameManager.confirm_building_placement(pos)
	var info = UnitData.get_unit_info(building_id)
	effects.create_build_effect(pos, Vector2(info["size"].x * MapData.TILE_SIZE, info["size"].y * MapData.TILE_SIZE))

func _on_building_ready_to_place(player_id: int, building_id: String) -> void:
	if player_id == 0:
		building_placer.start_placement(building_id, player_id)

func _on_placement_cancelled(building_id: String) -> void:
	var info = UnitData.get_unit_info(building_id)
	if not info.is_empty():
		GameManager.add_credits(0, info.get("cost", 0))
	GameManager.pending_building_id = ""
	GameManager.pending_building_player = -1

func _unhandled_input(event: InputEvent) -> void:
	if building_placer.is_placing:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				building_placer.try_place()
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				building_placer.cancel_placement()
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			building_placer.cancel_placement()
			get_viewport().set_input_as_handled()
			return
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_selection_start = get_global_mouse_position()
				selection_box.start(_selection_start)
				_is_selecting = true
			else:
				if _is_selecting:
					selection_box.finish()
					_is_selecting = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(get_global_mouse_position())
	elif event is InputEventMouseMotion and _is_selecting:
		selection_box.update(get_global_mouse_position())
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			GameManager.toggle_pause()
		elif event.keycode == KEY_DELETE:
			_delete_selected()
		elif event.ctrl_pressed:
			_handle_group_hotkey(event.keycode)

func _handle_group_hotkey(keycode: Key) -> void:
	if keycode >= KEY_1 and keycode <= KEY_9:
		var group_num = keycode - KEY_1
		if not GameManager.selected_units.is_empty():
			_unit_groups[group_num] = GameManager.selected_units.duplicate()
		elif _unit_groups.has(group_num):
			var valid_units := []
			for u in _unit_groups[group_num]:
				if is_instance_valid(u):
					valid_units.append(u)
			_unit_groups[group_num] = valid_units
			GameManager.set_selection(valid_units)

func _on_selection_finished(rect: Rect2) -> void:
	if rect.size.x < 5 and rect.size.y < 5:
		_handle_click(rect.position)
		return
	var selected := []
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if unit.player_id != 0:
			continue
		if rect.has_point(unit.global_position):
			selected.append(unit)
	if selected.is_empty():
		for building in get_tree().get_nodes_in_group("buildings"):
			if not is_instance_valid(building):
				continue
			if building.player_id != 0:
				continue
			if rect.has_point(building.global_position):
				selected.append(building)
	GameManager.set_selection(selected)

func _handle_click(pos: Vector2) -> void:
	var clicked: Node = null
	var best_dist := 999.0
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var dist = unit.global_position.distance_to(pos)
		if dist < 30.0 and dist < best_dist:
			best_dist = dist
			clicked = unit
	if not clicked:
		for building in get_tree().get_nodes_in_group("buildings"):
			if not is_instance_valid(building):
				continue
			var info = UnitData.get_unit_info(building.unit_id)
			var bsize = info.get("size", Vector2i(1, 1))
			var half_w = bsize.x * MapData.TILE_SIZE / 2.0
			var half_h = bsize.y * MapData.TILE_SIZE / 2.0
			if abs(building.global_position.x - pos.x) <= half_w and abs(building.global_position.y - pos.y) <= half_h:
				clicked = building
				break
	if clicked:
		if clicked.player_id == 0:
			GameManager.set_selection([clicked])
		else:
			_attack_target(clicked)
	else:
		GameManager.set_selection([])

func _handle_right_click(pos: Vector2) -> void:
	if GameManager.selected_units.is_empty():
		return
	var has_units := false
	for u in GameManager.selected_units:
		if is_instance_valid(u) and u.has_method("move_to"):
			has_units = true
			break
	if not has_units:
		return
	var target_enemy: Node = null
	var best_dist := 60.0
	for entity in get_tree().get_nodes_in_group("entities"):
		if not is_instance_valid(entity):
			continue
		if entity.player_id == 0:
			continue
		var dist = entity.global_position.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			target_enemy = entity
	for i in range(GameManager.selected_units.size()):
		var unit = GameManager.selected_units[i]
		if not is_instance_valid(unit):
			continue
		if not unit.has_method("move_to"):
			continue
		if target_enemy and unit.has_method("attack_target"):
			unit.attack_target(target_enemy)
		else:
			var offset = Vector2(
				(i % 3 - 1) * 30,
				(i / 3 - 1) * 30
			)
			unit.move_to(pos + offset)

func _attack_target(target: Node) -> void:
	for unit in GameManager.selected_units:
		if is_instance_valid(unit) and unit.has_method("attack_target"):
			unit.attack_target(target)

func _delete_selected() -> void:
	for unit in GameManager.selected_units:
		if is_instance_valid(unit) and unit.has_method("die"):
			unit.die()
	GameManager.set_selection([])
