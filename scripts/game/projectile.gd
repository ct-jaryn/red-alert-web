extends Area2D

var target: Node2D = null
var damage: int = 10
var speed: float = 300.0
var player_id: int = 0
var attacker: Node2D = null
var _direction: Vector2 = Vector2.ZERO

static func create(from_pos: Vector2, target_node: Node2D, dmg: int, owner_id: int, p_attacker: Node2D = null) -> Area2D:
	var p = preload("res://scripts/game/projectile.gd").new()
	p.position = from_pos
	p.target = target_node
	p.damage = dmg
	p.player_id = owner_id
	p.attacker = p_attacker
	return p

func _ready() -> void:
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	var visual = ColorRect.new()
	visual.size = Vector2(6, 6)
	visual.position = Vector2(-3, -3)
	visual.color = Color(1, 0.8, 0) if player_id == 0 else Color(1, 0.2, 0)
	add_child(visual)
	collision_layer = 0
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		_spawn_hit_effect()
		queue_free()
		return
	var target_pos := target.global_position
	_direction = (target_pos - global_position).normalized()
	var step := speed * delta
	var dist := global_position.distance_to(target_pos)
	if dist <= step or dist < 10.0:
		global_position = target_pos
		_hit()
	else:
		global_position += _direction * step

func _hit() -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage, attacker)
	_spawn_hit_effect()
	queue_free()

func _spawn_hit_effect() -> void:
	var main = get_tree().current_scene
	if main and main.has_node("Effects"):
		main.get_node("Effects").create_hit_effect(global_position)
