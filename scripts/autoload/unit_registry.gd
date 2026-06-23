extends Node

var registered_units: Dictionary = {}

func register(unit: Node2D) -> void:
	if unit.has_method("get_unit_id"):
		var id = unit.get_instance_id()
		if registered_units.has(id):
			return
		registered_units[id] = unit
		if not unit.tree_exiting.is_connected(_on_unit_exiting.bind(id)):
			unit.tree_exiting.connect(_on_unit_exiting.bind(id))

func _on_unit_exiting(id: int) -> void:
	registered_units.erase(id)

func get_units_in_radius(pos: Vector2, radius: float, exclude: Node2D = null) -> Array:
	var result := []
	for unit in registered_units.values():
		if not is_instance_valid(unit):
			continue
		if not (unit is Node2D):
			continue
		if unit == exclude:
			continue
		if unit.global_position.distance_to(pos) <= radius:
			result.append(unit)
	return result

func get_nearest_enemy(pos: Vector2, player_id: int, radius: float) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := radius
	for unit in registered_units.values():
		if not is_instance_valid(unit):
			continue
		if not (unit is Node2D):
			continue
		if not ("player_id" in unit) or unit.player_id == player_id:
			continue
		var dist = unit.global_position.distance_to(pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit
	return nearest
