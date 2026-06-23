extends Node2D

# 战争迷雾占位 — 当前始终可见，后续可扩展实际实现

var _map_width: int = 0
var _map_height: int = 0
var _player_id: int = 0

func setup(width: int, height: int, p_id: int) -> void:
	_map_width = width
	_map_height = height
	_player_id = p_id

func is_visible_at(_world_pos: Vector2) -> bool:
	return true

func is_explored(_world_pos: Vector2) -> bool:
	return true
