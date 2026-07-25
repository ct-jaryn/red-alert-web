extends Control

## 可复用的游戏设置弹窗：音乐/音效音量滑块 + 全屏开关。
## 数据源与应用均通过 SettingsManager，关闭时持久化。
## 主菜单与游戏内暂停面板均可实例化本弹窗。

const FontUtilScript = preload("res://scripts/ui/font_util.gd")

signal closed

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	_build()

func _build() -> void:
	# 半透明遮罩，拦截下层点击
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220
	panel.offset_top = -180
	panel.offset_right = 220
	panel.offset_bottom = 180
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.03, 0.98)
	style.border_color = Color(0.8, 0.2, 0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title := FontUtilScript.make_label("游 戏 设 置", 26, Color(0.9, 0.15, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	vbox.add_child(_make_slider_row("音乐音量", SettingsManager.music_volume, SettingsManager.set_music_volume))
	vbox.add_child(_make_slider_row("音效音量", SettingsManager.sfx_volume, SettingsManager.set_sfx_volume))

	# 全屏开关
	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 10)
	var fs_label := FontUtilScript.make_label("全屏模式", 16)
	fs_label.custom_minimum_size = Vector2(120, 0)
	fs_row.add_child(fs_label)
	var fs_check := CheckButton.new()
	fs_check.button_pressed = SettingsManager.fullscreen
	fs_check.add_theme_font_override("font", FontUtilScript.get_font())
	fs_check.toggled.connect(func(on): SettingsManager.set_fullscreen(on))
	fs_row.add_child(fs_check)
	vbox.add_child(fs_row)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var close_btn := _make_button("关 闭")
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)

func _make_slider_row(label_text: String, initial: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := FontUtilScript.make_label(label_text, 16)
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(180, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := FontUtilScript.make_label("%d%%" % int(round(initial * 100)), 14, Color(1, 0.85, 0))
	value_label.custom_minimum_size = Vector2(52, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	slider.value_changed.connect(func(v):
		value_label.text = "%d%%" % int(round(v * 100))
		on_change.call(v)
	)
	return row

func _make_button(text: String) -> Button:
	var btn := FontUtilScript.make_button(text, 18)
	btn.custom_minimum_size = Vector2(0, 42)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.04, 0.04)
	normal.border_color = Color(0.55, 0.12, 0.08)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.06, 0.06)
	hover.border_color = Color(0.85, 0.2, 0.12)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.8))
	return btn

func _close() -> void:
	SettingsManager.save_settings()
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	# 用 _input 优先消费 ESC，避免与 HUD 的暂停切换冲突
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()
