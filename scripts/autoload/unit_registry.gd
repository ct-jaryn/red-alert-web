extends Node

var registered_units: Dictionary = {}

func register(unit: Node) -> void:
	if unit.has_method("get_unit_id"):
		var id = unit.get_instance_id()
		registered_units[id] = unit
		unit.tree_exiting.connect(_on_unit_exiting.bind(id))

func _on_unit_exiting(id: int) -> void:
	registered_units.erase(id)

func get_units_in_radius(pos: Vector2, radius: float, exclude: Node = null) -> Array:
	var result := []
	for unit in registered_units.values():
		if not is_instance_valid(unit):
			continue
		if unit == exclude:
			continue
		if unit.global_position.distance_to(pos) <= radius:
			result.append(unit)
	return result

func get_nearest_enemy(pos: Vector2, player_id: int, radius: float) -> Node:
	var nearest: Node = null
	var nearest_dist := radius
	for unit in registered_units.values():
		if not is_instance_valid(unit):
			continue
		if not ("player_id" in unit) or unit.player_id == player_id:
			continue
		var dist = unit.global_position.distance_to(pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit
	return nearest
