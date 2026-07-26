extends Node2D

## 地图编辑器：笔刷绘制地形，保存为自定义地图供新游戏使用。
## 操作：左键绘制 | WASD/中键拖拽移动视角 | 滚轮缩放

const MapData = preload("res://scripts/data/map_data.gd")
const MapRendererScript = preload("res://scripts/game/map_renderer.gd")
const GameCameraScript = preload("res://scripts/game/game_camera.gd")
const FontUtilScript = preload("res://scripts/ui/font_util.gd")

var map_width: int = 80
var map_height: int = 60
var game_map: Array = []
var map_renderer: Node2D
var camera: Camera2D
var current_terrain: int = MapData.TerrainType.GRASS
var brush_size: int = 1
var _painting: bool = false
var _status_label: Label

var _terrain_names := {
	MapData.TerrainType.WATER: "水域",
	MapData.TerrainType.SAND: "沙地",
	MapData.TerrainType.GRASS: "草地",
	MapData.TerrainType.ORE: "矿石",
	MapData.TerrainType.ROCK: "岩石",
	MapData.TerrainType.ROAD: "道路",
	MapData.TerrainType.BRIDGE: "桥梁",
}

func _ready() -> void:
	# 已有自定义地图则继续编辑，否则新建全草地画布
	game_map = GameManager.load_custom_map()
	if game_map.is_empty():
		for y in range(map_height):
			var row := []
			row.resize(map_width)
			row.fill(MapData.TerrainType.GRASS)
			game_map.append(row)
	else:
		map_height = game_map.size()
		map_width = game_map[0].size()
	# 相机边界依赖全局地图尺寸
	GameManager.map_width = map_width
	GameManager.map_height = map_height
	map_renderer = MapRendererScript.new()
	map_renderer.name = "MapRenderer"
	map_renderer.z_index = -10
	add_child(map_renderer)
	map_renderer.setup_map(game_map)
	camera = GameCameraScript.new()
	camera.name = "EditorCamera"
	add_child(camera)
	camera.make_current()
	camera.position = Vector2(map_width, map_height) * MapData.TILE_SIZE / 2.0
	RenderingServer.set_default_clear_color(Color(0.08, 0.08, 0.1))
	_setup_ui()

func _setup_ui() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.border_color = Color(0.4, 0.12, 0.08)
	style.border_width_bottom = 2
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)
	hbox.add_child(FontUtilScript.make_label("地形:", 13, Color(0.7, 0.6, 0.5)))
	var terrain_group := ButtonGroup.new()
	for terrain in _terrain_names:
		var btn = FontUtilScript.make_button(_terrain_names[terrain], 12)
		btn.toggle_mode = true
		btn.button_group = terrain_group
		btn.button_pressed = terrain == current_terrain
		btn.custom_minimum_size = Vector2(52, 30)
		btn.pressed.connect(func(): current_terrain = terrain)
		hbox.add_child(btn)
	hbox.add_child(VSeparator.new())
	hbox.add_child(FontUtilScript.make_label("笔刷:", 13, Color(0.7, 0.6, 0.5)))
	var brush_group := ButtonGroup.new()
	for b in [1, 2, 4]:
		var bb = FontUtilScript.make_button("%dx%d" % [b * 2 - 1, b * 2 - 1], 12)
		bb.toggle_mode = true
		bb.button_group = brush_group
		bb.button_pressed = b == brush_size
		bb.custom_minimum_size = Vector2(42, 30)
		bb.pressed.connect(func(): brush_size = b)
		hbox.add_child(bb)
	hbox.add_child(VSeparator.new())
	var save_btn = FontUtilScript.make_button("保存地图", 13)
	save_btn.custom_minimum_size = Vector2(80, 30)
	save_btn.pressed.connect(func():
		if GameManager.save_custom_map(game_map):
			_status_label.text = "已保存！主菜单地图选'自定义'即可游玩"
		else:
			_status_label.text = "保存失败"
	)
	hbox.add_child(save_btn)
	var clear_btn = FontUtilScript.make_button("清空", 13)
	clear_btn.custom_minimum_size = Vector2(56, 30)
	clear_btn.pressed.connect(func():
		for row in game_map:
			for x in range(row.size()):
				row[x] = MapData.TerrainType.GRASS
		map_renderer.queue_redraw()
		_status_label.text = "已清空为草地"
	)
	hbox.add_child(clear_btn)
	var back_btn = FontUtilScript.make_button("返回菜单", 13)
	back_btn.custom_minimum_size = Vector2(80, 30)
	back_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	hbox.add_child(back_btn)
	_status_label = FontUtilScript.make_label("左键绘制 | WASD移动 | 滚轮缩放 | 四角为出生点", 12, Color(0.6, 0.6, 0.6))
	hbox.add_child(_status_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_painting = event.pressed
		if event.pressed:
			_paint(get_global_mouse_position())
	elif event is InputEventMouseMotion and _painting:
		_paint(get_global_mouse_position())

func _paint(world_pos: Vector2) -> void:
	var center = MapData.world_to_tile(world_pos)
	var r = brush_size - 1
	var changed := false
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var tx = center.x + dx
			var ty = center.y + dy
			if tx < 0 or tx >= map_width or ty < 0 or ty >= map_height:
				continue
			if game_map[ty][tx] != current_terrain:
				game_map[ty][tx] = current_terrain
				changed = true
	if changed:
		map_renderer.queue_redraw()
