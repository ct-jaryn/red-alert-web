class_name Minimap
extends Control

const MapData = preload("res://scripts/data/map_data.gd")
const UnitData = preload("res://scripts/data/unit_data.gd")

signal minimap_clicked(world_position: Vector2)

var game_map: Array = []
var map_width: int = 0
var map_height: int = 0
var minimap_size: Vector2 = Vector2(180, 140)
var _texture_rect: TextureRect
var _camera_indicator: Node2D
var _unit_dots: Node2D
var _image: Image
var _texture: ImageTexture
var _border: ReferenceRect
var _last_camera_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	minimap_size = size
	if minimap_size.x < 50:
		minimap_size = Vector2(200, 150)
	custom_minimum_size = minimap_size
	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_texture_rect)
	_border = ReferenceRect.new()
	_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_border.border_color = Color(0.6, 0.6, 0.6)
	_border.border_width = 2.0
	_border.editor_only = false
	add_child(_border)
	_camera_indicator = Node2D.new()
	add_child(_camera_indicator)
	_camera_indicator.draw.connect(func():
		var camera = get_viewport().get_camera_2d()
		if not camera or game_map.is_empty():
			return
		var scale_x = minimap_size.x / (map_width * MapData.TILE_SIZE)
		var scale_y = minimap_size.y / (map_height * MapData.TILE_SIZE)
		var view_rect = camera.get_visible_rect()
		var mm_pos = Vector2(
			clampf(view_rect.position.x * scale_x, 0, minimap_size.x),
			clampf(view_rect.position.y * scale_y, 0, minimap_size.y)
		)
		var mm_size = Vector2(
			minf(view_rect.size.x * scale_x, minimap_size.x - mm_pos.x),
			minf(view_rect.size.y * scale_y, minimap_size.y - mm_pos.y)
		)
		_camera_indicator.draw_rect(Rect2(mm_pos, mm_size), Color(1, 1, 1, 0.8), false, 2.0)
	)
	_unit_dots = Node2D.new()
	add_child(_unit_dots)
	_unit_dots.draw.connect(func():
		if game_map.is_empty():
			return
		var scale_x = minimap_size.x / (map_width * MapData.TILE_SIZE)
		var scale_y = minimap_size.y / (map_height * MapData.TILE_SIZE)
		for node in get_tree().get_nodes_in_group("entities"):
			if not is_instance_valid(node):
				continue
			if not ("player_id" in node):
				continue
			var color: Color
			if node.player_id == 0:
				color = Color(0, 0.5, 1)
			else:
				color = Color(1, 0.2, 0)
			var pos = Vector2(
				clampf(node.global_position.x * scale_x, 0, minimap_size.x),
				clampf(node.global_position.y * scale_y, 0, minimap_size.y)
			)
			if node.is_in_group("buildings"):
				var info = UnitData.get_unit_info(node.unit_id)
				var bsize = info.get("size", Vector2i(1, 1))
				var sz = Vector2(
					maxf(bsize.x * scale_x * MapData.TILE_SIZE, 3),
					maxf(bsize.y * scale_y * MapData.TILE_SIZE, 3)
				)
				_unit_dots.draw_rect(Rect2(pos - sz / 2.0, sz), color)
			else:
				_unit_dots.draw_circle(pos, 2.0, color)
	)

func setup_map(map: Array) -> void:
	game_map = map
	map_height = map.size()
	map_width = map[0].size() if map_height > 0 else 0
	_generate_minimap_image()

func _generate_minimap_image() -> void:
	_image = Image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
	for y in range(map_height):
		for x in range(map_width):
			var terrain = game_map[y][x]
			_image.set_pixel(x, y, MapData.get_terrain_color(terrain))
	_texture = ImageTexture.create_from_image(_image)
	_texture_rect.texture = _texture

func _process(_delta: float) -> void:
	# 仅在相机移动时重绘指示器
	var camera = get_viewport().get_camera_2d()
	if camera:
		var cam_pos = camera.position
		if cam_pos.distance_to(_last_camera_pos) > 1.0:
			_last_camera_pos = cam_pos
			_camera_indicator.queue_redraw()
	# 实体标记每帧更新（位置持续变化）
	_unit_dots.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = event.position
		var world_x = click_pos.x / minimap_size.x * map_width * MapData.TILE_SIZE
		var world_y = click_pos.y / minimap_size.y * map_height * MapData.TILE_SIZE
		minimap_clicked.emit(Vector2(world_x, world_y))
		accept_event()
