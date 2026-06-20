class_name FontUtil
extends RefCounted

static var _font: Font = null

static func get_font() -> Font:
	if _font == null:
		_font = load("res://assets/simhei.ttf")
	return _font

static func apply_to_control(control: Control) -> void:
	var f = get_font()
	if f:
		control.add_theme_font_override("font", f)

static func make_label(text: String, font_size: int = 14, color: Color = Color.WHITE) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", get_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

static func make_button(text: String, font_size: int = 12) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_override("font", get_font())
	btn.add_theme_font_size_override("font_size", font_size)
	return btn
