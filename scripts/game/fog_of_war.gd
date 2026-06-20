extends Node2D

const MapData = preload("res://scripts/data/map_data.gd")

var _map_width: int = 0
var _map_height: int = 0
var _player_id: int = 0
var _enabled: bool = false

func setup(width: int, height: int, p_id: int) -> void:
	_map_width = width
	_map_height = height
	_player_id = p_id
	_enabled = false

func is_visible_at(_world_pos: Vector2) -> bool:
	return true

func is_explored(_world_pos: Vector2) -> bool:
	return true
