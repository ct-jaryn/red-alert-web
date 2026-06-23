extends CharacterBody2D

const MapData = preload("res://scripts/data/map_data.gd")
const UnitData = preload("res://scripts/data/unit_data.gd")
const ProjectileScript = preload("res://scripts/game/projectile.gd")
const SpriteUtilScript = preload("res://scripts/ui/sprite_util.gd")

var unit_id: String = ""
var player_id: int = 0

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
var harvest_capacity: int = 0
var harvest_rate: float = 2.0
var _harvest_timer: float = 0.0
var ore_carried: int = 0
var _home_refinery: Node = null
var _sprite_rect: TextureRect
var _tint_rect: ColorRect
var _facing: float = 0.0
var _health_bar: ProgressBar
var _selection_ring: Node2D
var _health_fill: StyleBoxFlat

enum UnitState { IDLE, MOVING, ATTACKING, HARVESTING, RETURNING_ORE }
var current_state: int = UnitState.IDLE

func _ready() -> void:
	add_to_group("units")
	add_to_group("entities")
	UnitRegistry.register(self)
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
	var sz = Vector2(24, 24) if is_infantry else Vector2(32, 28)
	var tex = SpriteUtilScript.get_texture(unit_id)
	_sprite_rect = TextureRect.new()
	_sprite_rect.custom_minimum_size = sz
	_sprite_rect.size = sz
	_sprite_rect.position = -sz / 2.0
	_sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if tex:
		_sprite_rect.texture = tex
	add_child(_sprite_rect)
	var tint_color = MapData.get_player_tint(player_id)
	_tint_rect = ColorRect.new()
	_tint_rect.size = sz
	_tint_rect.position = -sz / 2.0
	_tint_rect.color = tint_color
	add_child(_tint_rect)
	_selection_ring = Node2D.new()
	_selection_ring.visible = false
	add_child(_selection_ring)
	_selection_ring.draw.connect(func():
		_selection_ring.draw_rect(
			Rect2(-sz / 2.0 - Vector2(3, 3), sz + Vector2(6, 6)),
			Color(0, 1, 0, 0.6), false, 2.0
		)
	)

func _process(_delta: float) -> void:
	if _health_bar.visible and max_health > 0:
		var h_ratio = float(health) / float(max_health)
		_health_bar.value = h_ratio
		if h_ratio > 0.6:
			_health_fill.bg_color = Color(0, 1, 0)
		elif h_ratio > 0.3:
			_health_fill.bg_color = Color(1, 1, 0)
		else:
			_health_fill.bg_color = Color(1, 0, 0)

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

func _process_idle(_delta: float) -> void:
	if harvest_capacity > 0 and _home_refinery and is_instance_valid(_home_refinery):
		var nearest_ore = _find_nearest_ore()
		if nearest_ore != Vector2.ZERO:
			_move_target = nearest_ore
			_is_moving = true
			current_state = UnitState.MOVING
			return
	if is_instance_valid(_current_target):
		var dist = global_position.distance_to(_current_target.global_position)
		if dist <= attack_range:
			current_state = UnitState.ATTACKING
		else:
			_move_target = _current_target.global_position
			_is_moving = true
			current_state = UnitState.MOVING

func _process_moving(_delta: float) -> void:
	if not _is_moving:
		current_state = UnitState.IDLE
		return
	var dir = (_move_target - global_position).normalized()
	var dist = global_position.distance_to(_move_target)
	if dist < 5.0:
		_is_moving = false
		velocity = Vector2.ZERO
		if harvest_capacity > 0 and GameManager.is_ore_at(global_position):
			current_state = UnitState.HARVESTING
		else:
			current_state = UnitState.IDLE
		return
	var terrain = GameManager.get_terrain_at(global_position)
	if not MapData.is_passable(terrain):
		_is_moving = false
		velocity = Vector2.ZERO
		current_state = UnitState.IDLE
		return
	var cost = MapData.get_move_cost(terrain)
	velocity = dir * (speed / cost)
	_facing = dir.angle()
	if _sprite_rect:
		_sprite_rect.rotation = _facing
	move_and_slide()
	if attack_range > 0 and harvest_capacity == 0:
		_check_attack_opportunity()

func _process_attacking(delta: float) -> void:
	if not is_instance_valid(_current_target):
		current_state = UnitState.IDLE
		return
	var dist = global_position.distance_to(_current_target.global_position)
	_facing = (_current_target.global_position - global_position).angle()
	if _sprite_rect:
		_sprite_rect.rotation = _facing
	if dist > attack_range * 1.2:
		_move_target = _current_target.global_position
		_is_moving = true
		current_state = UnitState.MOVING
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
				_move_target = nearest_ore
				_is_moving = true
				current_state = UnitState.MOVING
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
	if dist < 50.0:
		GameManager.add_credits(player_id, ore_carried * 50)
		ore_carried = 0
		var nearest = _find_nearest_ore()
		if nearest != Vector2.ZERO:
			_move_target = nearest
			_is_moving = true
			current_state = UnitState.MOVING
		else:
			current_state = UnitState.IDLE
		return
	var dir = (_home_refinery.global_position - global_position).normalized()
	velocity = dir * speed * 0.8
	_facing = dir.angle()
	if _sprite_rect:
		_sprite_rect.rotation = _facing
	move_and_slide()

func _return_to_refinery() -> void:
	_home_refinery = _find_refinery()
	if _home_refinery:
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

func take_damage(amount: int, _attacker: Node = null) -> void:
	var actual = maxi(1, amount - armor)
	health -= actual
	health = maxi(0, health)
	_health_bar.visible = true
	var main = get_tree().current_scene
	if main and main.has_node("Effects"):
		main.get_node("Effects").create_hit_effect(global_position)
	if health <= 0:
		die()

func die() -> void:
	var main = get_tree().current_scene
	if main and main.has_node("Effects"):
		var sz = 1.5 if UnitData.get_unit_info(unit_id).get("type", 0) == UnitData.UnitType.VEHICLE else 0.8
		main.get_node("Effects").create_explosion(global_position, sz)
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
	_move_target = pos
	_is_moving = true
	_current_target = null
	current_state = UnitState.MOVING

func attack_target(target: Node2D) -> void:
	if attack_damage <= 0:
		# 无攻击能力的单位（工程师、采矿车等）执行移动到目标位置
		move_to(target.global_position)
		return
	_current_target = target
	current_state = UnitState.ATTACKING

func set_harvest_target(refinery: Node) -> void:
	_home_refinery = refinery
	if harvest_capacity > 0:
		var nearest_ore = _find_nearest_ore()
		if nearest_ore != Vector2.ZERO:
			_move_target = nearest_ore
			_is_moving = true
			current_state = UnitState.MOVING
