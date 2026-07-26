extends CharacterBody2D

const MapData = preload("res://scripts/data/map_data.gd")
const UnitData = preload("res://scripts/data/unit_data.gd")
const ProjectileScript = preload("res://scripts/game/projectile.gd")
const SpriteUtilScript = preload("res://scripts/ui/sprite_util.gd")

var unit_id: String = ""
var player_id: int = 0
var move_domain: String = "ground"

var health: int = 100
var max_health: int = 100
var is_selected: bool = false
var armor: int = 0
var speed: float = 60.0
var attack_damage: int = 10
var attack_range: float = 120.0
var attack_cooldown: float = 0.5
var _attack_timer: float = 0.0
var _current_target: Node2D = null
var _move_target: Vector2 = Vector2.ZERO
var _is_moving: bool = false
var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _repath_timer: float = 0.0
var _idle_scan_timer: float = 0.0
var harvest_capacity: int = 0
var harvest_rate: float = 2.0
var _harvest_timer: float = 0.0
var ore_carried: int = 0
var _home_refinery: Node = null
var _sprite_rect: TextureRect
var _facing: float = 0.0
var _frames: Array = []
var _frame_index: int = 0
var _anim_timer: float = 0.0
var _health_bar: ProgressBar
var _selection_ring: Node2D
var _health_fill: StyleBoxFlat

enum UnitState { IDLE, MOVING, ATTACKING, HARVESTING, RETURNING_ORE }
var current_state: int = UnitState.IDLE

func _ready() -> void:
	add_to_group("units")
	add_to_group("entities")
	UnitRegistry.register(self)
	# 单位间互穿（只与建筑碰撞），避免报团卡死
	collision_layer = 1
	collision_mask = 2
	var info = UnitData.get_unit_info(unit_id)
	if not info.is_empty():
		max_health = info.get("health", 100)
		health = max_health
		armor = info.get("armor", 0)
		speed = info.get("speed", 60.0)
		attack_damage = info.get("attack_damage", 0)
		attack_range = info.get("attack_range", 0.0)
		attack_cooldown = info.get("attack_cooldown", 0.5)
		harvest_capacity = info.get("harvest_capacity", 0)
		harvest_rate = info.get("harvest_rate", 2.0)
		move_domain = info.get("domain", "ground")
	if move_domain == "air":
		# 空中单位无碰撞、绘制在顶层
		collision_layer = 0
		collision_mask = 0
		z_index = 5
	_setup_health_bar()
	_setup_unit_visuals()
	_move_target = global_position

func _setup_health_bar() -> void:
	_health_bar = ProgressBar.new()
	_health_bar.size = Vector2(40, 4)
	_health_bar.position = Vector2(-20, -30)
	_health_bar.max_value = 1.0
	_health_bar.value = 1.0
	_health_bar.show_percentage = false
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2)
	_health_bar.add_theme_stylebox_override("background", bg_style)
	_health_fill = StyleBoxFlat.new()
	_health_fill.bg_color = Color(0, 1, 0)
	_health_bar.add_theme_stylebox_override("fill", _health_fill)
	add_child(_health_bar)
	_health_bar.visible = false

func _setup_unit_visuals() -> void:
	var is_infantry = UnitData.get_unit_info(unit_id).get("type", 0) == UnitData.UnitType.INFANTRY
	var sz = Vector2(24, 24) if is_infantry else Vector2(34, 30)
	if unit_id == "heavy_tank":
		# 重型坦克用同款坦克精灵放大渲染
		sz = Vector2(42, 36)
	elif move_domain == "air":
		sz = Vector2(38, 32)
	elif unit_id == "battleship":
		sz = Vector2(46, 34)
	elif move_domain == "water":
		sz = Vector2(40, 30)
	# 按阵营配色取双帧动画；无映射时回退到静态单图
	_frames = SpriteUtilScript.get_unit_frames(unit_id, player_id)
	var tex: Texture2D = null
	if not _frames.is_empty():
		tex = _frames[0]
	else:
		tex = SpriteUtilScript.get_texture(unit_id)
	_sprite_rect = TextureRect.new()
	_sprite_rect.custom_minimum_size = sz
	_sprite_rect.size = sz
	_sprite_rect.position = -sz / 2.0
	_sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if tex:
		_sprite_rect.texture = tex
	add_child(_sprite_rect)
	_selection_ring = Node2D.new()
	_selection_ring.visible = false
	add_child(_selection_ring)
	var sel_tex = SpriteUtilScript.get_indicator("selection")
	_selection_ring.draw.connect(func():
		if sel_tex:
			# 选择环素材（六边形蓝框），拉伸到单位尺寸
			var ring_sz = sz * 1.5
			_selection_ring.draw_texture_rect(sel_tex, Rect2(-ring_sz / 2.0, ring_sz), false, Color(0.3, 1, 0.4))
		else:
			_selection_ring.draw_rect(
				Rect2(-sz / 2.0 - Vector2(3, 3), sz + Vector2(6, 6)),
				Color(0, 1, 0, 0.6), false, 2.0
			)
	)

func _process(delta: float) -> void:
	if _health_bar.visible and max_health > 0:
		var h_ratio = float(health) / float(max_health)
		_health_bar.value = h_ratio
		if h_ratio > 0.6:
			_health_fill.bg_color = Color(0, 1, 0)
		elif h_ratio > 0.3:
			_health_fill.bg_color = Color(1, 1, 0)
		else:
			_health_fill.bg_color = Color(1, 0, 0)
	# 双帧动画：非空闲状态循环切帧，空闲回首帧
	if _frames.size() >= 2:
		if current_state == UnitState.IDLE:
			if _frame_index != 0:
				_frame_index = 0
				_sprite_rect.texture = _frames[0]
		else:
			_anim_timer -= delta
			if _anim_timer <= 0:
				_anim_timer = 0.22
				_frame_index = (_frame_index + 1) % 2
				_sprite_rect.texture = _frames[_frame_index]

## 像素精灵用水平翻转表现朝向（素材默认朝左），避免整体旋转导致"躺平"
func _update_facing(dir: Vector2) -> void:
	_facing = dir.angle()
	if _sprite_rect and absf(dir.x) > 0.1:
		_sprite_rect.flip_h = dir.x > 0

func _physics_process(delta: float) -> void:
	match current_state:
		UnitState.IDLE:
			_process_idle(delta)
		UnitState.MOVING:
			_process_moving(delta)
		UnitState.ATTACKING:
			_process_attacking(delta)
		UnitState.HARVESTING:
			_process_harvesting(delta)
		UnitState.RETURNING_ORE:
			_process_returning_ore(delta)

func _process_idle(delta: float) -> void:
	if harvest_capacity > 0 and _home_refinery and is_instance_valid(_home_refinery):
		if ore_carried >= harvest_capacity:
			_return_to_refinery()
			return
		var nearest_ore = _find_nearest_ore()
		if nearest_ore != Vector2.ZERO:
			_start_path_move(nearest_ore)
			return
	if is_instance_valid(_current_target):
		var dist = global_position.distance_to(_current_target.global_position)
		if dist <= attack_range:
			current_state = UnitState.ATTACKING
		else:
			_start_path_move(_current_target.global_position)
		return
	# 空闲战斗单位定期扫描附近敌人，主动迎击/防守
	if attack_damage > 0 and harvest_capacity == 0:
		_idle_scan_timer -= delta
		if _idle_scan_timer <= 0:
			_idle_scan_timer = 0.5
			var enemy = UnitRegistry.get_nearest_enemy(global_position, player_id, attack_range * 1.5)
			if enemy:
				_current_target = enemy
				current_state = UnitState.ATTACKING

## 请求寻路并进入移动状态（不清除攻击目标，供追击复用）
func _start_path_move(pos: Vector2) -> void:
	if move_domain == "air":
		# 空中单位直线飞行，无视地形
		_path = PackedVector2Array([pos])
	else:
		_path = GameManager.find_path(global_position, pos, move_domain)
	_path_index = 0
	_move_target = pos
	_is_moving = true
	current_state = UnitState.MOVING

func _process_moving(_delta: float) -> void:
	if not _is_moving:
		current_state = UnitState.IDLE
		return
	# 追击中进入射程立即开火
	if is_instance_valid(_current_target) and attack_damage > 0:
		if global_position.distance_to(_current_target.global_position) <= attack_range:
			velocity = Vector2.ZERO
			_is_moving = false
			current_state = UnitState.ATTACKING
			return
	# 工程师接近敌方建筑即占领（自身消耗）
	if unit_id == "engineer" and is_instance_valid(_current_target) \
			and _current_target.is_in_group("buildings") and _current_target.player_id != player_id:
		var b_info = UnitData.get_unit_info(_current_target.unit_id)
		var bsize = b_info.get("size", Vector2i(1, 1))
		var capture_dist = maxf(bsize.x, bsize.y) * MapData.TILE_SIZE / 2.0 + 22.0
		if global_position.distance_to(_current_target.global_position) <= capture_dist:
			if _current_target.has_method("capture_by"):
				_current_target.capture_by(player_id)
				AudioManager.play_sfx("build")
			remove_from_group("units")
			remove_from_group("entities")
			GameManager.unregister_unit(self)
			queue_free()
			return
	var waypoint := _move_target
	if _path_index < _path.size():
		waypoint = _path[_path_index]
	var dist = global_position.distance_to(waypoint)
	if dist < 6.0:
		if _path_index < _path.size() - 1:
			_path_index += 1
			return
		_is_moving = false
		velocity = Vector2.ZERO
		if harvest_capacity > 0 and GameManager.is_ore_at(global_position):
			current_state = UnitState.HARVESTING
		else:
			current_state = UnitState.IDLE
		return
	var dir = (waypoint - global_position).normalized()
	var cost := 1.0
	if move_domain == "ground":
		var terrain = GameManager.get_terrain_at(global_position)
		cost = MapData.get_move_cost(terrain)
		if cost == INF:
			# 被挤到不可通行地形时按正常速度沿路径脱离
			cost = 1.0
	velocity = dir * (speed / cost)
	_update_facing(dir)
	move_and_slide()
	if attack_range > 0 and harvest_capacity == 0 and not is_instance_valid(_current_target):
		_check_attack_opportunity()

func _find_nearby_passable() -> Vector2:
	for radius in range(1, 5):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var check_pos = global_position + Vector2(dx * MapData.TILE_SIZE, dy * MapData.TILE_SIZE)
				if MapData.is_passable(GameManager.get_terrain_at(check_pos)):
					return check_pos
	return Vector2.ZERO

func _process_attacking(delta: float) -> void:
	if not is_instance_valid(_current_target):
		current_state = UnitState.IDLE
		return
	var dist = global_position.distance_to(_current_target.global_position)
	_update_facing((_current_target.global_position - global_position).normalized())
	if dist > attack_range * 1.1:
		# 目标走远，定期重新寻路追击
		_repath_timer -= delta
		if _repath_timer <= 0:
			_repath_timer = 0.5
			_start_path_move(_current_target.global_position)
		return
	_attack_timer -= delta
	if _attack_timer <= 0:
		_attack_timer = attack_cooldown
		_fire_at(_current_target)

func _process_harvesting(delta: float) -> void:
	if ore_carried >= harvest_capacity:
		_return_to_refinery()
		return
	_harvest_timer -= delta
	if _harvest_timer <= 0:
		_harvest_timer = harvest_rate
		if GameManager.harvest_ore(global_position):
			ore_carried += 1
			var main = get_tree().current_scene
			if main and main.has_node("Effects"):
				main.get_node("Effects").create_ore_harvest_effect(global_position)
			if main and main.has_node("MapRenderer"):
				main.get_node("MapRenderer").update_terrain_at(global_position)
		else:
			var nearest_ore = _find_nearest_ore()
			if nearest_ore != Vector2.ZERO:
				_start_path_move(nearest_ore)
			elif ore_carried > 0:
				_return_to_refinery()
			else:
				current_state = UnitState.IDLE

func _process_returning_ore(_delta: float) -> void:
	if not is_instance_valid(_home_refinery):
		_home_refinery = _find_refinery()
		if not _home_refinery:
			current_state = UnitState.IDLE
			return
	var dist = global_position.distance_to(_home_refinery.global_position)
	if dist < 90.0:
		GameManager.add_credits(player_id, ore_carried * 50)
		if player_id == 0:
			AudioManager.play_sfx("harvest")
		ore_carried = 0
		var nearest = _find_nearest_ore()
		if nearest != Vector2.ZERO:
			_start_path_move(nearest)
		else:
			current_state = UnitState.IDLE
		return
	# 沿寻路路径返回矿厂，避免直线撞障碍卡死
	var waypoint: Vector2 = _home_refinery.global_position
	if _path_index < _path.size():
		waypoint = _path[_path_index]
		if global_position.distance_to(waypoint) < 6.0:
			_path_index += 1
			return
	var dir = (waypoint - global_position).normalized()
	velocity = dir * speed * 0.9
	_update_facing(dir)
	move_and_slide()

func _return_to_refinery() -> void:
	_home_refinery = _find_refinery()
	if _home_refinery:
		_path = GameManager.find_path(global_position, _home_refinery.global_position)
		_path_index = 0
		current_state = UnitState.RETURNING_ORE
	else:
		current_state = UnitState.IDLE

func _find_refinery() -> Node:
	var best: Node = null
	var best_dist := 999999.0
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b):
			continue
		if b.player_id == player_id and b.unit_id == "ore_refinery":
			var d = b.global_position.distance_to(global_position)
			if d < best_dist:
				best_dist = d
				best = b
	return best

func _find_nearest_ore() -> Vector2:
	# 优先以当前位置为起点搜索，避免舍近求远
	var base_tile := MapData.world_to_tile(global_position)
	if _home_refinery and is_instance_valid(_home_refinery):
		base_tile = MapData.world_to_tile(_home_refinery.global_position)
	# 先检查脚下
	if GameManager.is_ore_at(global_position):
		return global_position
	for radius in range(1, 25):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var tile := base_tile + Vector2i(dx, dy)
				if tile.x < 0 or tile.x >= GameManager.map_width or tile.y < 0 or tile.y >= GameManager.map_height:
					continue
				if GameManager.game_map[tile.y][tile.x] == MapData.TerrainType.ORE:
					return Vector2(
						tile.x * MapData.TILE_SIZE + MapData.TILE_SIZE / 2.0,
						tile.y * MapData.TILE_SIZE + MapData.TILE_SIZE / 2.0
					)
	return Vector2.ZERO

func _check_attack_opportunity() -> void:
	var enemy = UnitRegistry.get_nearest_enemy(global_position, player_id, attack_range * 0.8)
	if enemy:
		_current_target = enemy
		current_state = UnitState.ATTACKING

func _fire_at(target: Node2D) -> void:
	var proj = ProjectileScript.create(global_position, target, attack_damage, player_id, self)
	var scene = get_tree().current_scene
	if scene:
		scene.add_child(proj)
		if scene.has_node("Effects"):
			scene.get_node("Effects").create_muzzle_flash(global_position, Vector2.from_angle(_facing))
	AudioManager.play_sfx("attack")

func take_damage(amount: int, _attacker: Node = null) -> void:
	if health <= 0:
		return
	var actual = maxi(1, amount - armor)
	health -= actual
	health = maxi(0, health)
	_health_bar.visible = true
	# 受击红闪：用 red_mask 素材叠在精灵上短暂显示
	var mask_tex = SpriteUtilScript.get_indicator("red_mask")
	if mask_tex and _sprite_rect:
		var flash := TextureRect.new()
		flash.texture = mask_tex
		flash.stretch_mode = TextureRect.STRETCH_SCALE
		flash.size = _sprite_rect.size
		flash.position = _sprite_rect.position
		flash.modulate = Color(1, 1, 1, 0.7)
		add_child(flash)
		var tween = flash.create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.15)
		tween.tween_callback(flash.queue_free)
	var main = get_tree().current_scene
	if main and main.has_node("Effects"):
		main.get_node("Effects").create_hit_effect(global_position)
	if health <= 0:
		die()

func die() -> void:
	AudioManager.play_sfx("explosion")
	var main = get_tree().current_scene
	if main and main.has_node("Effects"):
		var sz = 1.5 if UnitData.get_unit_info(unit_id).get("type", 0) == UnitData.UnitType.VEHICLE else 0.8
		main.get_node("Effects").create_explosion(global_position, sz)
	# 残骸淡出：保留最后一帧灰化渐隐
	if main and _sprite_rect and _sprite_rect.texture:
		var corpse := TextureRect.new()
		corpse.texture = _sprite_rect.texture
		corpse.flip_h = _sprite_rect.flip_h
		corpse.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		corpse.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		corpse.size = _sprite_rect.size
		corpse.position = global_position + _sprite_rect.position
		corpse.modulate = Color(0.45, 0.4, 0.38, 0.75)
		corpse.z_index = -1
		main.add_child(corpse)
		var tween = corpse.create_tween()
		tween.tween_property(corpse, "modulate:a", 0.0, 5.0)
		tween.tween_callback(corpse.queue_free)
	remove_from_group("units")
	remove_from_group("entities")
	GameManager.unregister_unit(self)
	queue_free()

func set_selected(selected: bool) -> void:
	is_selected = selected
	_selection_ring.visible = selected
	_health_bar.visible = selected or health < max_health

func get_unit_id() -> String:
	return unit_id

func get_player_id() -> int:
	return player_id

func get_info() -> Dictionary:
	return UnitData.get_unit_info(unit_id)

func move_to(pos: Vector2) -> void:
	_current_target = null
	_start_path_move(pos)

func attack_target(target: Node2D) -> void:
	if attack_damage <= 0:
		# 工程师锁定敌方建筑前往占领
		if unit_id == "engineer" and target.is_in_group("buildings") and target.player_id != player_id:
			_current_target = target
			_start_path_move(target.global_position)
			return
		# 其余无攻击能力单位（采矿车等）执行移动到目标位置
		move_to(target.global_position)
		return
	_current_target = target
	if global_position.distance_to(target.global_position) <= attack_range:
		current_state = UnitState.ATTACKING
	else:
		_start_path_move(target.global_position)

func set_harvest_target(refinery: Node) -> void:
	_home_refinery = refinery
	if harvest_capacity > 0:
		var nearest_ore = _find_nearest_ore()
		if nearest_ore != Vector2.ZERO:
			_start_path_move(nearest_ore)
