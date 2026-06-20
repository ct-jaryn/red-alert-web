extends CanvasLayer

const UnitData = preload("res://scripts/data/unit_data.gd")
const BuildPanelScript = preload("res://scripts/ui/build_panel.gd")
const MinimapScript = preload("res://scripts/ui/minimap.gd")
const FontUtilScript = preload("res://scripts/ui/font_util.gd")

var _credits_label: Label
var _power_label: Label
var _fps_label: Label
var _info_panel: PanelContainer
var _info_label: Label
var _build_panel: Control
var _minimap: Control
var _pause_panel: PanelContainer
var _game_over_panel: PanelContainer
var _notification_label: Label
var _notification_timer: float = 0.0

func _ready() -> void:
	layer = 10
	_setup_ui()
	GameManager.credits_changed.connect(_on_credits_changed)
	GameManager.power_changed.connect(_on_power_changed)
	GameManager.selection_changed.connect(_on_selection_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_paused.connect(_on_game_paused)
	GameManager.construction_complete.connect(_on_construction_complete)

func _setup_ui() -> void:
	var top_bar = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.position = Vector2(15, 10)
	top_bar.size = Vector2(600, 30)
	add_child(top_bar)
	_credits_label = FontUtilScript.make_label("金币: 5000", 18, Color(1, 0.85, 0))
	top_bar.add_child(_credits_label)
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(40, 0)
	top_bar.add_child(spacer)
	_power_label = FontUtilScript.make_label("电力: 0/0", 18, Color(0.5, 1, 0.5))
	top_bar.add_child(_power_label)
	spacer = Control.new()
	spacer.custom_minimum_size = Vector2(40, 0)
	top_bar.add_child(spacer)
	_fps_label = FontUtilScript.make_label("帧率: 60", 13, Color(0.7, 0.7, 0.7))
	top_bar.add_child(_fps_label)

	_info_panel = PanelContainer.new()
	_info_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_info_panel.anchor_left = 0.0
	_info_panel.anchor_top = 1.0
	_info_panel.anchor_right = 0.0
	_info_panel.anchor_bottom = 1.0
	_info_panel.offset_left = 15
	_info_panel.offset_top = -110
	_info_panel.offset_right = 350
	_info_panel.offset_bottom = -10
	var info_style = StyleBoxFlat.new()
	info_style.bg_color = Color(0, 0, 0, 0.75)
	info_style.border_color = Color(0.5, 0.5, 0.5)
	info_style.border_width_bottom = 1
	info_style.border_width_top = 1
	info_style.border_width_left = 1
	info_style.border_width_right = 1
	_info_panel.add_theme_stylebox_override("panel", info_style)
	add_child(_info_panel)
	_info_label = FontUtilScript.make_label("选择单位或建筑", 13)
	_info_panel.add_child(_info_label)

	_notification_label = FontUtilScript.make_label("", 16, Color(0, 1, 0.5))
	_notification_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_notification_label.position = Vector2(500, 55)
	_notification_label.size = Vector2(600, 35)
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.visible = false
	add_child(_notification_label)

	_build_panel = BuildPanelScript.new()
	_build_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_build_panel.anchor_left = 1.0
	_build_panel.anchor_right = 1.0
	_build_panel.offset_left = -230
	_build_panel.offset_top = 10
	_build_panel.offset_right = -10
	_build_panel.offset_bottom = -10
	_build_panel.player_id = 0
	add_child(_build_panel)

	_minimap = MinimapScript.new()
	_minimap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_minimap.anchor_left = 0.0
	_minimap.anchor_top = 1.0
	_minimap.anchor_right = 0.0
	_minimap.anchor_bottom = 1.0
	_minimap.offset_left = 15
	_minimap.offset_top = -220
	_minimap.offset_right = 215
	_minimap.offset_bottom = -120
	add_child(_minimap)

	_setup_pause_panel()
	_setup_game_over_panel()

func _setup_pause_panel() -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.size = Vector2(320, 160)
	_pause_panel.offset_left = -160
	_pause_panel.offset_top = -80
	_pause_panel.offset_right = 160
	_pause_panel.offset_bottom = 80
	_pause_panel.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9)
	style.border_color = Color(0.8, 0.2, 0.15)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	_pause_panel.add_theme_stylebox_override("panel", style)
	add_child(_pause_panel)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_panel.add_child(vbox)
	var label = FontUtilScript.make_label("暂 停", 28, Color(0.9, 0.15, 0.1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	var resume_btn = FontUtilScript.make_button("继续游戏 (ESC)")
	resume_btn.custom_minimum_size = Vector2(200, 40)
	resume_btn.pressed.connect(func(): GameManager.toggle_pause())
	vbox.add_child(resume_btn)
	var menu_btn = FontUtilScript.make_button("返回主菜单")
	menu_btn.custom_minimum_size = Vector2(200, 40)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	vbox.add_child(menu_btn)

func _setup_game_over_panel() -> void:
	_game_over_panel = PanelContainer.new()
	_game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_panel.size = Vector2(450, 220)
	_game_over_panel.offset_left = -225
	_game_over_panel.offset_top = -110
	_game_over_panel.offset_right = 225
	_game_over_panel.offset_bottom = 110
	_game_over_panel.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.92)
	style.border_color = Color(1, 0.8, 0)
	style.border_width_bottom = 3
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_right = 3
	_game_over_panel.add_theme_stylebox_override("panel", style)
	add_child(_game_over_panel)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_game_over_panel.add_child(vbox)
	var label = FontUtilScript.make_label("胜利", 36, Color(1, 0.85, 0))
	label.name = "ResultLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	var restart_btn = FontUtilScript.make_button("重新开始")
	restart_btn.custom_minimum_size = Vector2(200, 45)
	restart_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/game/main.tscn")
	)
	vbox.add_child(restart_btn)
	var menu_btn = FontUtilScript.make_button("返回主菜单")
	menu_btn.custom_minimum_size = Vector2(200, 45)
	menu_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	vbox.add_child(menu_btn)

func _show_notification(text: String, duration: float = 3.0) -> void:
	_notification_label.text = text
	_notification_label.visible = true
	_notification_timer = duration

func _on_credits_changed(player_id: int, amount: int) -> void:
	if player_id == 0:
		_credits_label.text = "金币: %d" % amount

func _on_power_changed(player_id: int, current: int, max_power: int) -> void:
	if player_id == 0:
		_power_label.text = "电力: %d/%d" % [current, max_power]
		if current < max_power:
			_power_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		else:
			_power_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))

func _on_selection_changed(selected: Array) -> void:
	if selected.is_empty():
		_info_label.text = "选择单位或建筑"
		return
	var unit = selected[0]
	if not is_instance_valid(unit):
		return
	var info = UnitData.get_unit_info(unit.unit_id)
	if info.is_empty():
		return
	var text = "%s\n生命: %d/%d" % [info.get("name", unit.unit_id), unit.health, unit.max_health]
	if info.has("attack_damage") and info.get("attack_damage", 0) > 0:
		text += "\n攻击: %d | 射程: %d" % [info.get("attack_damage", 0), int(info.get("attack_range", 0))]
	if info.has("speed"):
		text += "\n速度: %d" % int(info.get("speed", 0))
	if info.has("armor") and info.get("armor", 0) > 0:
		text += " | 护甲: %d" % info.get("armor", 0)
	if selected.size() > 1:
		text += "\n[已选 %d 个单位]" % selected.size()
	_info_label.text = text

func _on_construction_complete(player_id: int, item_id: String) -> void:
	if player_id != 0:
		return
	var info = UnitData.get_unit_info(item_id)
	if not info.is_empty():
		var item_type = "建筑" if info.get("type", -1) == UnitData.UnitType.BUILDING else "单位"
		_show_notification("%s建造完成: %s" % [item_type, info.get("name", item_id)])

func _on_game_over(winner_id: int) -> void:
	_game_over_panel.visible = true
	var label = _game_over_panel.get_node("ResultLabel")
	if winner_id == 0:
		label.text = "胜利!"
		label.add_theme_color_override("font_color", Color(0, 1, 0))
	else:
		label.text = "战败"
		label.add_theme_color_override("font_color", Color(1, 0, 0))

func _on_game_paused(is_paused: bool) -> void:
	_pause_panel.visible = is_paused

func _on_minimap_clicked(world_pos: Vector2) -> void:
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_method("move_to_position"):
		cam.move_to_position(world_pos)

func _process(delta: float) -> void:
	_fps_label.text = "帧率: %d" % Engine.get_frames_per_second()
	if _notification_timer > 0:
		_notification_timer -= delta
		if _notification_timer <= 0:
			_notification_label.visible = false
