extends Node

func _ready() -> void:
	var font = load("res://assets/simhei.ttf")
	if font:
		ThemeDB.fallback_font = font
		ThemeDB.fallback_font_size = 14
