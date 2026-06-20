class_name SelectionBox
extends Node2D

signal selection_finished(rect: Rect2)

var is_active: bool = false
var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO

func start(pos: Vector2) -> void:
	is_active = true
	start_pos = pos
	end_pos = pos
	visible = true
	queue_redraw()

func update(pos: Vector2) -> void:
	if not is_active:
		return
	end_pos = pos
	queue_redraw()

func finish() -> Rect2:
	is_active = false
	visible = false
	var rect = _get_rect()
	selection_finished.emit(rect)
	return rect

func _draw() -> void:
	if not is_active:
		return
	var rect = _get_rect()
	if rect.size.x < 2 and rect.size.y < 2:
		return
	draw_rect(rect, Color(0, 1, 0, 0.12), true)
	draw_rect(rect, Color(0, 1, 0, 0.7), false, 2.0)

func _get_rect() -> Rect2:
	var top_left = Vector2(
		minf(start_pos.x, end_pos.x),
		minf(start_pos.y, end_pos.y)
	)
	var bottom_right = Vector2(
		maxf(start_pos.x, end_pos.x),
		maxf(start_pos.y, end_pos.y)
	)
	return Rect2(top_left, bottom_right - top_left)
