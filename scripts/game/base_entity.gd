class_name BaseEntity
extends CharacterBody2D

const UnitData = preload("res://scripts/data/unit_data.gd")

@export var unit_id: String = ""
@export var player_id: int = 0

var health: int = 100
var max_health: int = 100
var is_selected: bool = false
var armor: int = 0

var _health_bar: ProgressBar
var _selection_ring: Node2D

func _ready() -> void:
	add_to_group("entities")
	_setup_health_bar()
	_setup_selection_ring()
	var info = UnitData.get_unit_info(unit_id)
	if not info.is_empty():
		max_health = info.get("health", 100)
		health = max_health
		armor = info.get("armor", 0)

func _setup_health_bar() -> void:
	_health_bar = ProgressBar.new()
	_health_bar.size = Vector2(40, 4)
	_health_bar.position = Vector2(-20, -30)
	_health_bar.max_value = 1.0
	_health_bar.value = 1.0
	_health_bar.show_percentage = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2)
	_health_bar.add_theme_stylebox_override("background", style)
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0, 1, 0)
	_health_bar.add_theme_stylebox_override("fill", fill)
	add_child(_health_bar)
	_health_bar.visible = false

func _setup_selection_ring() -> void:
	_selection_ring = Node2D.new()
	_selection_ring.visible = false
	add_child(_selection_ring)

func _process(_delta: float) -> void:
	if _selection_ring.visible:
		_selection_ring.queue_redraw()
	if _health_bar.visible:
		_health_bar.value = float(health) / float(max_health)
		var h_ratio = float(health) / float(max_health)
		var fill_style = StyleBoxFlat.new()
		if h_ratio > 0.6:
			fill_style.bg_color = Color(0, 1, 0)
		elif h_ratio > 0.3:
			fill_style.bg_color = Color(1, 1, 0)
		else:
			fill_style.bg_color = Color(1, 0, 0)
		_health_bar.add_theme_stylebox_override("fill", fill_style)

func take_damage(amount: int, attacker: Node = null) -> void:
	var actual_damage = maxi(1, amount - armor)
	health -= actual_damage
	health = maxi(0, health)
	_health_bar.visible = true
	if health <= 0:
		die()

func heal(amount: int) -> void:
	health = mini(health + amount, max_health)

func die() -> void:
	queue_free()

func set_selected(selected: bool) -> void:
	is_selected = selected
	_selection_ring.visible = selected
	_health_bar.visible = selected or health < max_health

func get_unit_id() -> String:
	return unit_id

func get_player_id() -> int:
	return player_id

func is_enemy(other: BaseEntity) -> bool:
	return player_id != other.player_id

func get_info() -> Dictionary:
	return UnitData.get_unit_info(unit_id)
