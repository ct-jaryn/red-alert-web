class_name EntityCommon
extends RefCounted

## 单位与建筑共享的实体 UI 构建工具，消除两侧重复实现。

## 创建血条，返回 {"bar": ProgressBar, "fill": StyleBoxFlat}，由调用方 add_child
static func create_health_bar(width: float, offset: Vector2) -> Dictionary:
	var bar := ProgressBar.new()
	bar.size = Vector2(width, 4)
	bar.position = offset
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2)
	bar.add_theme_stylebox_override("background", bg_style)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0, 1, 0)
	bar.add_theme_stylebox_override("fill", fill)
	bar.visible = false
	return {"bar": bar, "fill": fill}

## 按血量比例更新血条数值与颜色（绿/黄/红三档）
static func update_health_bar(bar: ProgressBar, fill: StyleBoxFlat, health: int, max_health: int) -> void:
	if max_health <= 0:
		return
	var h_ratio := float(health) / float(max_health)
	bar.value = h_ratio
	if h_ratio > 0.6:
		fill.bg_color = Color(0, 1, 0)
	elif h_ratio > 0.3:
		fill.bg_color = Color(1, 1, 0)
	else:
		fill.bg_color = Color(1, 0, 0)

## 护甲减伤后的实际伤害（至少 1 点）
static func apply_armor(amount: int, armor: int) -> int:
	return maxi(1, amount - armor)
