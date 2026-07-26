extends Control

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const SettingsDialogScript = preload("res://scripts/ui/settings_dialog.gd")

var _title_label: Label
var _subtitle_label: Label
var _btn_container: VBoxContainer
var _version_label: Label
var _scanline_overlay: ColorRect
var _bg_particles: Node2D
var _glow_timer: float = 0.0
var _particles: Array = []
var _screen_w: float = 1920.0
var _screen_h: float = 1080.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_screen_w = get_viewport_rect().size.x
	_screen_h = get_viewport_rect().size.y
	_setup_background()
	_setup_ui()
	_setup_animations()

func _setup_background() -> void:
	# 加载背景图片
	var bg_tex = load("res://assets/sprites/ui/menu_background.png") as Texture2D
	if bg_tex:
		var bg_image = TextureRect.new()
		bg_image.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_image.texture = bg_tex
		bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_image.modulate = Color(0.6, 0.5, 0.5, 1.0)  # 稍微变暗以便UI更清晰
		add_child(bg_image)
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.02, 0.02, 0.5)  # 半透明覆盖层
	add_child(bg)
	_bg_particles = Node2D.new()
	_bg_particles.z_index = 1
	add_child(_bg_particles)
	for i in range(80):
		_particles.append({
			"pos": Vector2(randf() * _screen_w, randf() * _screen_h),
			"speed": randf_range(10, 50),
			"size": randf_range(1, 3.5),
			"alpha": randf_range(0.08, 0.35),
		})
	_bg_particles.draw.connect(func():
		for p in _particles:
			var c = Color(1, 0.2, 0.1, p["alpha"])
			_bg_particles.draw_circle(p["pos"], p["size"], c)
	)
	_scanline_overlay = ColorRect.new()
	_scanline_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scanline_overlay.color = Color(0, 0, 0, 0.03)
	_scanline_overlay.z_index = 2
	add_child(_scanline_overlay)
	var top_bar = ColorRect.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 3)
	top_bar.color = Color(0.8, 0.1, 0.1)
	top_bar.z_index = 3
	add_child(top_bar)
	var bottom_bar = ColorRect.new()
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.custom_minimum_size = Vector2(0, 3)
	bottom_bar.color = Color(0.8, 0.1, 0.1)
	bottom_bar.z_index = 3
	add_child(bottom_bar)
	var edge_margin = _screen_w * 0.03
	var left_accent = ColorRect.new()
	left_accent.position = Vector2(edge_margin, _screen_h * 0.11)
	left_accent.size = Vector2(3, _screen_h * 0.78)
	left_accent.color = Color(0.6, 0.1, 0.1, 0.4)
	left_accent.z_index = 3
	add_child(left_accent)
	var right_accent = ColorRect.new()
	right_accent.position = Vector2(_screen_w - edge_margin - 3, _screen_h * 0.11)
	right_accent.size = Vector2(3, _screen_h * 0.78)
	right_accent.color = Color(0.6, 0.1, 0.1, 0.4)
	right_accent.z_index = 3
	add_child(right_accent)

func _setup_ui() -> void:
	var center = VBoxContainer.new()
	center.anchor_left = 0.25
	center.anchor_top = 0.1
	center.anchor_right = 0.75
	center.anchor_bottom = 0.9
	center.offset_left = 0
	center.offset_top = 0
	center.offset_right = 0
	center.offset_bottom = 0
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)
	var title_container = VBoxContainer.new()
	title_container.add_theme_constant_override("separation", 5)
	center.add_child(title_container)
	_title_label = FontUtilScript.make_label("", int(_screen_h * 0.07), Color(0.9, 0.15, 0.1))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "RED ALERT"
	title_container.add_child(_title_label)
	_subtitle_label = FontUtilScript.make_label("", int(_screen_h * 0.035), Color(0.95, 0.85, 0.2))
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.text = "红 色 警 戒"
	title_container.add_child(_subtitle_label)
	var line = HSeparator.new()
	line.custom_minimum_size = Vector2(0, 30)
	center.add_child(line)
	_btn_container = VBoxContainer.new()
	_btn_container.add_theme_constant_override("separation", 16)
	_btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_btn_container)
	var btn_w = _screen_w * 0.22
	var btn_h = _screen_h * 0.06
	var btn_data := [
		{"text": "新 游 戏", "action": "_on_new_game"},
	]
	if GameManager.has_save():
		btn_data.append({"text": "继续游戏", "action": "_on_continue"})
	btn_data.append({"text": "游戏设置", "action": "_on_settings"})
	btn_data.append({"text": "退出游戏", "action": "_on_exit"})
	for data in btn_data:
		var btn = _create_menu_button(data["text"], btn_w, btn_h)
		btn.pressed.connect(Callable(self, data["action"]))
		_btn_container.add_child(btn)
	# 难度选择行
	var diff_row = HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 10)
	_btn_container.add_child(diff_row)
	var diff_label = FontUtilScript.make_label("难度:", 15, Color(0.7, 0.6, 0.5))
	diff_row.add_child(diff_label)
	var diff_group := ButtonGroup.new()
	var diff_data := [["简单", 1], ["普通", 2], ["困难", 3]]
	for dd in diff_data:
		var db = _create_menu_button(dd[0], btn_w * 0.28, btn_h * 0.75)
		db.toggle_mode = true
		db.button_group = diff_group
		db.button_pressed = GameManager.ai_difficulty == dd[1]
		db.pressed.connect(func(): GameManager.ai_difficulty = dd[1])
		diff_row.add_child(db)
	# 地图大小选择行
	var size_row = HBoxContainer.new()
	size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	size_row.add_theme_constant_override("separation", 10)
	_btn_container.add_child(size_row)
	var size_label = FontUtilScript.make_label("地图:", 15, Color(0.7, 0.6, 0.5))
	size_row.add_child(size_label)
	var size_group := ButtonGroup.new()
	var size_data := [["小", 0], ["中", 1], ["大", 2]]
	for sd in size_data:
		var sb = _create_menu_button(sd[0], btn_w * 0.28, btn_h * 0.75)
		sb.toggle_mode = true
		sb.button_group = size_group
		sb.button_pressed = GameManager.map_size_option == sd[1]
		sb.pressed.connect(func(): GameManager.map_size_option = sd[1])
		size_row.add_child(sb)
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, _screen_h * 0.05)
	center.add_child(spacer)
	var tip = FontUtilScript.make_label("", 13, Color(0.4, 0.35, 0.3))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.text = "WASD移动 | 左键选择 | 右键命令 | ESC暂停"
	center.add_child(tip)
	_version_label = FontUtilScript.make_label("", 12, Color(0.4, 0.15, 0.1))
	_version_label.text = "v1.0.0 | Godot 4.3"
	_version_label.position = Vector2(_screen_w - 180, _screen_h - 30)
	_version_label.z_index = 5
	add_child(_version_label)
	var credits = FontUtilScript.make_label("", 12, Color(0.3, 0.25, 0.2))
	credits.text = "素材: Elite Command by Chris Vincent (CC-BY 4.0)"
	credits.position = Vector2(15, _screen_h - 30)
	credits.z_index = 5
	add_child(credits)

func _create_menu_button(text: String, btn_w: float, btn_h: float) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(btn_w, btn_h)
	btn.add_theme_font_override("font", FontUtilScript.get_font())
	btn.add_theme_font_size_override("font_size", int(btn_h * 0.4))
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.04, 0.04)
	normal_style.border_color = Color(0.55, 0.12, 0.08)
	normal_style.border_width_bottom = 2
	normal_style.border_width_top = 2
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.corner_radius_top_left = 3
	normal_style.corner_radius_top_right = 3
	normal_style.corner_radius_bottom_left = 3
	normal_style.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("normal", normal_style)
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.25, 0.06, 0.06)
	hover_style.border_color = Color(0.85, 0.2, 0.12)
	hover_style.border_width_bottom = 2
	hover_style.border_width_top = 2
	hover_style.border_width_left = 2
	hover_style.border_width_right = 2
	hover_style.corner_radius_top_left = 3
	hover_style.corner_radius_top_right = 3
	hover_style.corner_radius_bottom_left = 3
	hover_style.corner_radius_bottom_right = 3
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.45, 0.08, 0.08)
	pressed_style.border_color = Color(1, 0.3, 0.2)
	pressed_style.border_width_bottom = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_left = 2
	pressed_style.border_width_right = 2
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.8))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return btn

func _setup_animations() -> void:
	_title_label.modulate = Color(1, 1, 1, 0)
	_subtitle_label.modulate = Color(1, 1, 1, 0)
	for btn in _btn_container.get_children():
		btn.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_title_label, "modulate:a", 1.0, 0.8)
	tween.tween_property(_subtitle_label, "modulate:a", 1.0, 0.5)
	for btn in _btn_container.get_children():
		tween.tween_property(btn, "modulate:a", 1.0, 0.3)

func _process(delta: float) -> void:
	_glow_timer += delta
	for p in _particles:
		p["pos"].y -= p["speed"] * delta
		p["pos"].x += sin(_glow_timer * 0.5 + p["pos"].x * 0.01) * 0.3
		if p["pos"].y < -10:
			p["pos"].y = _screen_h + 10
			p["pos"].x = randf() * _screen_w
	_bg_particles.queue_redraw()
	var glow = 0.15 + sin(_glow_timer * 2.0) * 0.05
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.15 + glow * 0.3, 0.1))

func _on_new_game() -> void:
	GameManager.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/game/main.tscn")

func _on_continue() -> void:
	if GameManager.load_save():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/game/main.tscn")

func _on_settings() -> void:
	var dialog = SettingsDialogScript.new()
	add_child(dialog)

func _on_exit() -> void:
	_show_exit_confirm()

func _show_exit_confirm() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -190
	panel.offset_top = -95
	panel.offset_right = 190
	panel.offset_bottom = 95
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.03, 0.98)
	style.border_color = Color(0.8, 0.2, 0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	var msg := FontUtilScript.make_label("确定要退出游戏吗？", 20, Color(0.95, 0.85, 0.7))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 20)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)
	var yes_btn := _create_menu_button("确定", 140, 44)
	yes_btn.pressed.connect(_do_exit)
	btn_row.add_child(yes_btn)
	var no_btn := _create_menu_button("取消", 140, 44)
	no_btn.pressed.connect(overlay.queue_free)
	btn_row.add_child(no_btn)
	add_child(overlay)

func _do_exit() -> void:
	if OS.has_feature("web"):
		# 浏览器安全策略通常禁止脚本关闭用户手动打开的标签页；
		# 先尝试关闭，失败则显示告别界面兜底。
		JavaScriptBridge.eval("window.open('', '_self'); window.close();", true)
		_show_farewell()
	else:
		get_tree().quit()

func _show_farewell() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.96)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 200
	var label := FontUtilScript.make_label("感谢游玩！\n您可以安全关闭此页面。", 28, Color(0.9, 0.15, 0.1))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(label)
	add_child(overlay)
