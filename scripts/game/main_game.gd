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
const SpriteUtilScript = preload("res://scripts/ui/sprite_util.gd")

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
var _selection_start: Vector2 = Vector2.ZERO
var _is_selecting: bool = false
var _unit_groups: Dictionary = {}

func _ready() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(function() {
				var c = document.getElementById('canvas');
				if (c) {
					c.focus();
					c.addEventListener('mousedown', function() { c.focus(); });
					c.addEventListener('touchstart', function() { c.focus(); });
				}
				document.addEventListener('contextmenu', function(e) { e.preventDefault(); });
				document.addEventListener('visibilitychange', function() {
					if (document.hidden && typeof Godot !== 'undefined') {
						document.title = '红色警戒 - 已暂停';
					}
				});
			})();
		""")
	_setup_nodes()
	_start_game()

func _setup_nodes() -> void:
	buildings_node = Node2D.new()
	buildings_node.name = "Buildings"
	add_child(buildings_node)
	units_node = Node2D.new()
	units_node.name = "Units"
	add_child(units_node)
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
	if not NetworkManager.in_match:
		ai_controller = AIControllerScript.new()
		ai_controller.name = "AIController"
		ai_controller.player_id = 1
		ai_controller.difficulty = GameManager.ai_difficulty
		add_child(ai_controller)

func _start_game() -> void:
	if not GameManager.pending_load.is_empty():
		_restore_from_save()
		return
	# 联机：双方用同一种子确定性生成地图；仅主机生成初始单位
	GameManager.start_game(2, NetworkManager.match_seed if NetworkManager.in_match else 0)
	map_renderer.setup_map(GameManager.game_map)
	hud.setup_minimap(GameManager.game_map)
	fog_of_war.setup(GameManager.map_width, GameManager.map_height, GameManager.local_player_id)
	# 地图外背景用暗色草地色，配合边界描边区分可活动范围
	RenderingServer.set_default_clear_color(MapData.get_terrain_color(MapData.TerrainType.GRASS).darkened(0.45))
	if not NetworkManager.is_client():
		_spawn_starting_units()
	var spawn_points = MapData.find_spawn_points(GameManager.game_map)
	var cam_idx = mini(GameManager.local_player_id, spawn_points.size() - 1)
	if spawn_points.size() > 0:
		var sp = spawn_points[cam_idx]
		var base_pos = Vector2(sp.x * MapData.TILE_SIZE, sp.y * MapData.TILE_SIZE)
		camera.position = base_pos
		camera._clamp_position()

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
		var unit_pos = _find_passable_pos(pos + Vector2(-60 + i * 30, 80))
		var rifle = _create_unit("rifle_infantry", p_id, unit_pos)
		if rifle:
			GameManager.register_unit(rifle)
	var harvester_pos = _find_passable_pos(pos + Vector2(0, 100))
	var harvester = _create_unit("harvester", p_id, harvester_pos)
	if harvester:
		GameManager.register_unit(harvester)
		if ref:
			harvester.set_harvest_target(ref)

## 从存档恢复对局：地图/玩家/实体/迷雾/镜头
func _restore_from_save() -> void:
	var data = GameManager.pending_load
	GameManager.pending_load = {}
	GameManager.restore_state(data)
	map_renderer.setup_map(GameManager.game_map)
	hud.setup_minimap(GameManager.game_map)
	fog_of_war.setup(GameManager.map_width, GameManager.map_height, 0)
	if data.has("fog"):
		fog_of_war.set_explored_rows(data["fog"])
	RenderingServer.set_default_clear_color(MapData.get_terrain_color(MapData.TerrainType.GRASS).darkened(0.45))
	var own_base_pos := Vector2.ZERO
	for e in data.get("entities", []):
		var pos = Vector2(float(e.get("x", 0)), float(e.get("y", 0)))
		var p_id = int(e.get("p", 0))
		var ent_id = str(e.get("id", ""))
		if str(e.get("kind", "")) == "b":
			var b = _create_building(ent_id, p_id, pos)
			if b:
				b.health = int(e.get("hp", b.max_health))
				GameManager.register_building(b)
				if p_id == 0 and ent_id == "construction_yard":
					own_base_pos = pos
		else:
			var u = _create_unit(ent_id, p_id, pos)
			if u:
				u.health = int(e.get("hp", u.max_health))
				u.ore_carried = int(e.get("ore", 0))
				GameManager.register_unit(u)
	# 采矿车重新绑定各自阵营最近的矿厂
	for u in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(u) and u.harvest_capacity > 0:
			var ref = GameManager._find_refinery(u.player_id)
			if ref:
				u.set_harvest_target(ref)
	if own_base_pos != Vector2.ZERO:
		camera.position = own_base_pos
		camera._clamp_position()

func _find_passable_pos(pos: Vector2) -> Vector2:
	var terrain = GameManager.get_terrain_at(pos)
	if MapData.is_passable(terrain):
		return pos
	# 螺旋搜索附近可通行位置
	for radius in range(1, 8):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var check_pos = pos + Vector2(dx * MapData.TILE_SIZE, dy * MapData.TILE_SIZE)
				if MapData.is_passable(GameManager.get_terrain_at(check_pos)):
					return check_pos
	return pos

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
	if NetworkManager.is_client():
		# 客户端：放置请求交由主机校验落地
		NetworkManager.send_place(building_id, pos)
	else:
		GameManager.confirm_building_placement(pos)
	var info = UnitData.get_unit_info(building_id)
	var bsize = info.get("size", Vector2i(1, 1))
	effects.create_build_effect(pos, Vector2(bsize.x * MapData.TILE_SIZE, bsize.y * MapData.TILE_SIZE))

func _on_building_ready_to_place(player_id: int, building_id: String) -> void:
	if player_id == 0:
		building_placer.start_placement(building_id, player_id)

func _on_placement_cancelled(building_id: String) -> void:
	if NetworkManager.is_client():
		NetworkManager.send_cancel_place(building_id)
		return
	if GameManager.pending_building_player < 0:
		return
	var info = UnitData.get_unit_info(building_id)
	if not info.is_empty():
		GameManager.add_credits(GameManager.pending_building_player, info.get("cost", 0))
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
			if building_placer.is_placing:
				building_placer.cancel_placement()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DELETE:
			_delete_selected()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			_handle_group_hotkey(event.keycode, event.ctrl_pressed)

func _handle_group_hotkey(keycode: Key, is_ctrl: bool) -> void:
	var group_num = keycode - KEY_1
	if is_ctrl:
		# Ctrl+数字：保存当前选中的单位到编队
		var valid_units := []
		for u in GameManager.selected_units:
			if is_instance_valid(u) and not u.is_queued_for_deletion():
				valid_units.append(u)
		if not valid_units.is_empty():
			_unit_groups[group_num] = valid_units
	elif _unit_groups.has(group_num):
		# 单独按数字：选中已保存的编队
		var valid_units := []
		for u in _unit_groups[group_num]:
			if is_instance_valid(u) and not u.is_queued_for_deletion():
				valid_units.append(u)
		_unit_groups[group_num] = valid_units
		GameManager.set_selection(valid_units)

func _on_selection_finished(rect: Rect2) -> void:
	if rect.size.x < 5 and rect.size.y < 5:
		_handle_click(rect.position)
		return
	var selected := []
	var lp = GameManager.local_player_id
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		if unit.player_id != lp:
			continue
		if rect.has_point(unit.global_position):
			selected.append(unit)
	if selected.is_empty():
		for building in get_tree().get_nodes_in_group("buildings"):
			if not is_instance_valid(building):
				continue
			if building.player_id != lp:
				continue
			if rect.has_point(building.global_position):
				selected.append(building)
	if not selected.is_empty():
		AudioManager.play_sfx("select")
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
		if clicked.player_id == GameManager.local_player_id:
			AudioManager.play_sfx("select")
			GameManager.set_selection([clicked])
		else:
			_attack_target(clicked)
			_spawn_command_marker("target", clicked.global_position)
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
		if entity.player_id == GameManager.local_player_id:
			continue
		# 建筑按实际占地矩形判定，点到哪里都能选中
		if entity.is_in_group("buildings"):
			var b_info = UnitData.get_unit_info(entity.unit_id)
			var bsize = b_info.get("size", Vector2i(1, 1))
			if abs(entity.global_position.x - pos.x) <= bsize.x * MapData.TILE_SIZE / 2.0 \
					and abs(entity.global_position.y - pos.y) <= bsize.y * MapData.TILE_SIZE / 2.0:
				target_enemy = entity
				break
		var dist = entity.global_position.distance_to(pos)
		if dist < best_dist:
			best_dist = dist
			target_enemy = entity
	# 联机客户端：指令发送给主机执行（本地镜像不模拟）
	if NetworkManager.is_client():
		var ids := []
		for u in GameManager.selected_units:
			if is_instance_valid(u) and u.has_meta("net_id") and u.is_in_group("units"):
				ids.append(u.get_meta("net_id"))
		if not ids.is_empty():
			if target_enemy and target_enemy.has_meta("net_id"):
				NetworkManager.send_attack(ids, target_enemy.get_meta("net_id"))
			else:
				NetworkManager.send_move(ids, pos)
	else:
		for i in range(GameManager.selected_units.size()):
			var unit = GameManager.selected_units[i]
			if not is_instance_valid(unit):
				continue
			if not unit.has_method("move_to"):
				continue
			if target_enemy and unit.has_method("attack_target"):
				unit.attack_target(target_enemy)
			else:
				var cols = ceili(sqrt(GameManager.selected_units.size()))
				var offset = Vector2(
					(i % cols - cols / 2.0) * 30,
					(i / cols - cols / 2.0) * 30
				)
				unit.move_to(pos + offset)
	# 命令反馈标记：攻击红框 / 移动绿框
	if target_enemy:
		_spawn_command_marker("target", target_enemy.global_position)
	else:
		_spawn_command_marker("friendly_target", pos)

func _spawn_command_marker(kind: String, pos: Vector2) -> void:
	var tex = SpriteUtilScript.get_indicator(kind)
	if not tex:
		return
	var marker := Sprite2D.new()
	marker.texture = tex
	marker.position = pos
	marker.z_index = 9
	var target_size := 40.0
	var tex_w = maxf(tex.get_width(), 1)
	marker.scale = Vector2.ONE * (target_size / tex_w)
	add_child(marker)
	var tween = marker.create_tween()
	tween.set_parallel(true)
	tween.tween_property(marker, "scale", marker.scale * 0.6, 0.5)
	tween.tween_property(marker, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(marker.queue_free)

func _attack_target(target: Node) -> void:
	if NetworkManager.is_client():
		var ids := []
		for u in GameManager.selected_units:
			if is_instance_valid(u) and u.has_meta("net_id") and u.is_in_group("units"):
				ids.append(u.get_meta("net_id"))
		if not ids.is_empty() and target.has_meta("net_id"):
			NetworkManager.send_attack(ids, target.get_meta("net_id"))
		return
	for unit in GameManager.selected_units:
		if is_instance_valid(unit) and unit.has_method("attack_target"):
			unit.attack_target(target)

func _delete_selected() -> void:
	for unit in GameManager.selected_units:
		if is_instance_valid(unit) and unit.has_method("die"):
			unit.die()
	GameManager.set_selection([])
