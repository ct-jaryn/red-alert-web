class_name GameCamera
extends Camera2D

@export var move_speed: float = 400.0
@export var edge_scroll_speed: float = 300.0
@export var edge_scroll_margin: int = 30
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.3
@export var max_zoom: float = 2.0

var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _camera_start: Vector2 = Vector2.ZERO
var _target_position: Vector2 = Vector2.ZERO
var _is_moving_to: bool = false

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	_target_position = position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_dragging = true
				_drag_start = get_viewport().get_mouse_position()
				_camera_start = position
			else:
				_is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = (zoom + Vector2(zoom_speed, zoom_speed)).clampf(min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = (zoom - Vector2(zoom_speed, zoom_speed)).clampf(min_zoom, max_zoom)
	elif event is InputEventMouseMotion and _is_dragging:
		var delta = _drag_start - get_viewport().get_mouse_position()
		position = _camera_start + delta / zoom.x
		_target_position = position
		_is_moving_to = false

func _process(delta: float) -> void:
	if _is_moving_to:
		position = position.lerp(_target_position, 0.1)
		if position.distance_to(_target_position) < 1.0:
			position = _target_position
			_is_moving_to = false
	var move_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		move_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		move_dir.y += 1
	if Input.is_key_pressed(KEY_A):
		move_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		move_dir.x += 1
	if move_dir != Vector2.ZERO:
		position += move_dir.normalized() * move_speed * delta / zoom.x
		_target_position = position
		_is_moving_to = false
	if _is_dragging:
		return
	var viewport_size = get_viewport_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	if _is_mouse_over_ui(mouse_pos, viewport_size):
		return
	var edge_dir = Vector2.ZERO
	if mouse_pos.x < edge_scroll_margin:
		edge_dir.x -= 1
	elif mouse_pos.x > viewport_size.x - edge_scroll_margin:
		edge_dir.x += 1
	if mouse_pos.y < edge_scroll_margin:
		edge_dir.y -= 1
	elif mouse_pos.y > viewport_size.y - edge_scroll_margin:
		edge_dir.y += 1
	if edge_dir != Vector2.ZERO:
		position += edge_dir.normalized() * edge_scroll_speed * delta / zoom.x
		_target_position = position
		_is_moving_to = false

func _is_mouse_over_ui(mouse_pos: Vector2, viewport_size: Vector2) -> bool:
	if mouse_pos.x > viewport_size.x - 210:
		return true
	if mouse_pos.x < 200 and mouse_pos.y > 460:
		return true
	if mouse_pos.x < 320 and mouse_pos.y > 610:
		return true
	return false

func move_to_position(world_pos: Vector2) -> void:
	_target_position = world_pos
	_is_moving_to = true

func get_visible_rect() -> Rect2:
	var viewport_size = get_viewport_rect().size / zoom
	return Rect2(position - viewport_size / 2.0, viewport_size)
