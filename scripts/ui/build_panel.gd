class_name BuildPanel
extends PanelContainer

const UnitData = preload("res://scripts/data/unit_data.gd")
const FontUtilScript = preload("res://scripts/ui/font_util.gd")

var player_id: int = 0
var _build_buttons: Dictionary = {}
var _queue_container: VBoxContainer
var _progress_bar: ProgressBar
var _progress_label: Label
var _category_tabs: TabContainer
var _building_ids := [
	"power_plant", "barracks", "ore_refinery",
	"war_factory", "radar", "repair_pad",
	"turret_gun", "turret_missile"
]
var _infantry_ids := ["rifle_infantry", "engineer", "rocket_soldier"]
var _vehicle_ids := ["harvester", "light_tank", "medium_tank", "heavy_tank"]

func _ready() -> void:
	_setup_ui()
	GameManager.construction_complete.connect(_on_construction_complete)
	GameManager.build_queue_updated.connect(_on_queue_updated)
	GameManager.building_placed.connect(_on_building_placed)
	GameManager.credits_changed.connect(_on_credits_changed)

func _setup_ui() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.75)
	panel_style.border_color = Color(0.4, 0.12, 0.08)
	panel_style.border_width_bottom = 1
	panel_style.border_width_top = 1
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	add_theme_stylebox_override("panel", panel_style)
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	add_child(main_vbox)
	var title = FontUtilScript.make_label("建 造", 16, Color(0.9, 0.15, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	_progress_label = FontUtilScript.make_label("空闲", 11, Color(0.6, 0.6, 0.6))
	main_vbox.add_child(_progress_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.custom_minimum_size = Vector2(0, 12)
	_progress_bar.show_percentage = false
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2)
	_progress_bar.add_theme_stylebox_override("background", bg)
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0, 0.7, 1)
	_progress_bar.add_theme_stylebox_override("fill", fill)
	main_vbox.add_child(_progress_bar)
	_category_tabs = TabContainer.new()
	_category_tabs.custom_minimum_size = Vector2(200, 0)
	main_vbox.add_child(_category_tabs)
	_create_building_tab()
	_create_infantry_tab()
	_create_vehicle_tab()
	var queue_label = FontUtilScript.make_label("队列 (右键取消):", 11, Color(0.7, 0.7, 0.7))
	main_vbox.add_child(queue_label)
	_queue_container = VBoxContainer.new()
	main_vbox.add_child(_queue_container)

func _create_building_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "建筑"
	_category_tabs.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	for id in _building_ids:
		_add_build_button(vbox, id)

func _create_infantry_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "步兵"
	_category_tabs.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	for id in _infantry_ids:
		_add_build_button(vbox, id)

func _create_vehicle_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "载具"
	_category_tabs.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	for id in _vehicle_ids:
		_add_build_button(vbox, id)

func _add_build_button(parent: Control, item_id: String) -> void:
	var info = UnitData.get_unit_info(item_id)
	if info.is_empty():
		return
	var btn = FontUtilScript.make_button("%s [$%d]" % [info.get("name", item_id), info.get("cost", 0)])
	btn.name = item_id
	btn.custom_minimum_size = Vector2(180, 30)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_build_button_pressed.bind(item_id))
	parent.add_child(btn)
	_build_buttons[item_id] = btn

func _on_build_button_pressed(item_id: String) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var p = GameManager.get_player(player_id)
	if not p:
		return
	var info = UnitData.get_unit_info(item_id)
	if info.is_empty():
		return
	if not UnitData.can_build(item_id, p.built_buildings):
		return
	if p.credits < info.get("cost", 0):
		return
	GameManager.add_to_build_queue(player_id, item_id)

func _on_construction_complete(p_id: int, item_id: String) -> void:
	if p_id != player_id:
		return
	var info = UnitData.get_unit_info(item_id)
	if not info.is_empty():
		_progress_label.text = "完成: %s" % info.get("name", item_id)
	_update_button_states()

func _on_building_placed(_building: Node) -> void:
	_update_button_states()

func _on_queue_updated(p_id: int, queue: Array) -> void:
	if p_id != player_id:
		return
	_rebuild_queue_display(queue)

func _rebuild_queue_display(queue: Array) -> void:
	for child in _queue_container.get_children():
		child.queue_free()
	for i in range(queue.size()):
		var item_id = queue[i]
		var info = UnitData.get_unit_info(item_id)
		var hbox = HBoxContainer.new()
		var label = FontUtilScript.make_label(info.get("name", item_id), 11)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		if i > 0:
			var cancel_btn = FontUtilScript.make_button("取消", 10)
			cancel_btn.custom_minimum_size = Vector2(40, 20)
			cancel_btn.pressed.connect(_cancel_queue_item.bind(i, item_id))
			hbox.add_child(cancel_btn)
		_queue_container.add_child(hbox)

func _cancel_queue_item(index: int, item_id: String) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var p = GameManager.get_player(player_id)
	if not p:
		return
	if index < 0 or index >= p.build_queue.size():
		return
	var info = UnitData.get_unit_info(item_id)
	var refund = info.get("cost", 0)
	p.build_queue.remove_at(index)
	GameManager.add_credits(player_id, refund)
	if index == 0:
		p.current_build_item = ""
		p.build_progress = 0.0
		if not p.build_queue.is_empty():
			p.current_build_item = p.build_queue[0]
	GameManager.build_queue_updated.emit(player_id, p.build_queue)

func _update_button_states() -> void:
	var p = GameManager.get_player(player_id)
	if not p:
		return
	for item_id in _build_buttons:
		var btn = _build_buttons[item_id]
		var info = UnitData.get_unit_info(item_id)
		var can_build = UnitData.can_build(item_id, p.built_buildings)
		var can_afford = p.credits >= info.get("cost", 0)
		btn.disabled = not can_build or not can_afford
		if can_build and not can_afford:
			btn.modulate = Color(0.5, 0.5, 0.5)
		elif can_build and can_afford:
			btn.modulate = Color(1, 1, 1)
		else:
			btn.modulate = Color(0.3, 0.3, 0.3)

func _on_credits_changed(p_id: int, _amount: int) -> void:
	if p_id == player_id:
		_update_button_states()

func _process(_delta: float) -> void:
	var p = GameManager.get_player(player_id)
	if p and not p.current_build_item.is_empty():
		_progress_bar.value = p.build_progress
		var info = UnitData.get_unit_info(p.current_build_item)
		_progress_label.text = "建造中: %s (%d%%)" % [info.get("name", p.current_build_item), int(p.build_progress * 100)]
	else:
		_progress_bar.value = 0.0
		if _progress_label.text.begins_with("建造中:"):
			_progress_label.text = "空闲"
