extends Node

func _ready() -> void:
	var font = load("res://assets/simhei.ttf")
	if font:
		ThemeDB.fallback_font = font
		ThemeDB.fallback_font_size = 14
	else:
		push_warning("FontSetup: 无法加载字体 res://assets/simhei.ttf")
