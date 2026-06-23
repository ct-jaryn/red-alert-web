extends StaticBody2D

const MapData = preload("res://scripts/data/map_data.gd")
const UnitData = preload("res://scripts/data/unit_data.gd")
const ProjectileScript = preload("res://scripts/game/projectile.gd")
const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const SpriteUtilScript = preload("res://scripts/ui/sprite_util.gd")

var unit_id: String = ""
var player_id: int = 0

var health: int = 100
var max_health: int = 100
var is_selected: bool = false
var armor: int = 0
var size_cells: Vector2i = Vector2i(1, 1)
var can_attack: bool = false
var attack_damage: int = 0
var attack_range: float = 0.0
var attack_cooldown: float = 1.0
var _attack_timer: float = 0.0
var _current_target: Node2D = null
var _rally_point: Vector2 = Vector2.ZERO
var _construction_timer: float = 0.0
var _construction_duration: float = 1.0
var _is_constructing: bool = false

var _health_bar: ProgressBar
var _selection_rect: Node2D
var _sprite_rect: TextureRect
var _border: ReferenceRect
var _label: Label
var _construction_overlay: ColorRect
var _tint_rect: ColorRect
var _health_fill: StyleBoxFlat

func _ready() -> void:
	add_to_group("buildings")
	add_to_group("entities")
	UnitRegistry.register(self)
	var info = UnitData.get_unit_info(unit_id)
	if not info.is_empty():
		max_health = info.get("health", 100)
		health = max_health
		armor = info.get("armor", 0)
		size_cells = info.get("size", Vector2i(1, 1))
		attack_damage = info.get("attack_damage", 0)
		attack_range = info.get("attack_range", 0.0)
		attack_cooldown = info.get("attack_cooldown", 1.0)
		can_attack = attack_damage > 0 and attack_range > 0.0
	_setup_visuals()
	_rally_point = global_position + Vector2(0, size_cells.y * MapData.TILE_SIZE / 2.0 + 30)
	_start_construction()

func _setup_visuals() -> void:
	var w = size_cells.x * MapData.TILE_SIZE
	var h = size_cells.y * MapData.TILE_SIZE
	var tex = SpriteUtilScript.get_texture(unit_id)
	_sprite_rect = TextureRect.new()
	_sprite_rect.custom_minimum_size = Vector2(w, h)
	_sprite_rect.size = Vector2(w, h)
	_sprite_rect.position = Vector2(-w / 2.0, -h / 2.0)
	_sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if tex:
		_sprite_rect.texture = tex
	add_child(_sprite_rect)
	var tint_color = MapData.get_player_tint(player_id, 0.25)
	_tint_rect = ColorRect.new()
	_tint_rect.size = Vector2(w, h)
	_tint_rect.position = Vector2(-w / 2.0, -h / 2.0)
	_tint_rect.color = tint_color
	add_child(_tint_rect)
	_border = ReferenceRect.new()
	_border.size = Vector2(w, h)
	_border.position = Vector2(-w / 2.0, -h / 2.0)
	_border.border_color = Color(0.3, 0.3, 0.3)
	_border.border_width = 2.0
	_border.editor_only = false
	add_child(_border)
	_health_bar = ProgressBar.new()
	_health_bar.size = Vector2(w, 4)
	_health_bar.position = Vector2(-w / 2.0, -h / 2.0 - 8)
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
	_selection_rect = Node2D.new()
	_selection_rect.visible = false
	add_child(_selection_rect)
	_selection_rect.draw.connect(_draw_selection)
	_label = Label.new()
	_label.text = _get_display_name()
	_label.position = Vector2(-w / 2.0 + 4, -h / 2.0 + 4)
	_label.add_theme_font_override("font", FontUtilScript.get_font())
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_label)
	_construction_overlay = ColorRect.new()
	_construction_overlay.size = Vector2(w, h)
	_construction_overlay.position = Vector2(-w / 2.0, -h / 2.0)
	_construction_overlay.color = Color(0, 0, 0, 0.5)
	_construction_overlay.visible = false
	add_child(_construction_overlay)

func _start_construction() -> void:
	_is_constructing = true
	_construction_timer = 0.0
	_construction_duration = 1.0
	_construction_overlay.visible = true

func _process(delta: float) -> void:
	if _is_constructing:
		_construction_timer += delta
		var progress = clampf(_construction_timer / _construction_duration, 0.0, 1.0)
		_construction_overlay.color.a = 0.5 * (1.0 - progress)
		if progress >= 1.0:
			_is_constructing = false
			_construction_overlay.visible = false
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
	if can_attack and not _is_constructing and health > 0:
		_attack_timer -= delta
		if _attack_timer <= 0:
			_try_attack()

func _draw_selection() -> void:
	var w = size_cells.x * MapData.TILE_SIZE
	var h = size_cells.y * MapData.TILE_SIZE
	_selection_rect.draw_rect(
		Rect2(Vector2(-w / 2.0 - 2, -h / 2.0 - 2), Vector2(w + 4, h + 4)),
		Color(0, 1, 0, 0.5), false, 2.0
	)

func _get_display_name() -> String:
	var info = UnitData.get_unit_info(unit_id)
	return info.get("name", unit_id)

func _try_attack() -> void:
	if not is_instance_valid(_current_target):
		_current_target = _find_target()
	if is_instance_valid(_current_target):
		_attack_timer = attack_cooldown
		_fire_at(_current_target)
	else:
		# 无目标时 also 重置扫描间隔，避免每帧都搜索
		_attack_timer = attack_cooldown

func _find_target() -> Node2D:
	var enemies = UnitRegistry.get_units_in_radius(global_position, attack_range)
	var best: Node2D = null
	var best_dist := attack_range + 1.0
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if not (e is Node2D):
			continue
		if not ("player_id" in e) or e.player_id == player_id:
			continue
		var dist = e.global_position.distance_to(global_position)
		if dist < best_dist:
			best_dist = dist
			best = e
	return best

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
	if health <= 0:
		die()

func die() -> void:
	var main = get_tree().current_scene
	if main and main.has_node("Effects"):
		main.get_node("Effects").create_explosion(global_position, 2.0)
	GameManager.unregister_building(self)
	queue_free()

func set_selected(selected: bool) -> void:
	is_selected = selected
	_selection_rect.visible = selected
	_health_bar.visible = selected or health < max_health

func get_rally_point() -> Vector2:
	return _rally_point

func get_unit_id() -> String:
	return unit_id

func get_player_id() -> int:
	return player_id
