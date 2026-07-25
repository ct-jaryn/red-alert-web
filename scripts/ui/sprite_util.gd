class_name SpriteUtil
extends RefCounted

static var _cache: Dictionary = {}

# 单位图集布局：每行 40 张 = 20 种单位 x 2 帧，共 6 行阵营配色
# 行起始索引：红 40 / 蓝 80 / 绿 120 / 橙 160 / 紫 200 / 黄 240
const UNIT_SHEET_DIR := "res://assets/sprites/units/elite_command_art_units/units-sliced"

# 玩家 0 用蓝色行，玩家 1（AI）用红色行，其余预留
static var _faction_row_base := [80, 40, 120, 160, 200, 240]

# 各单位在阵营行内的帧偏移（每单位占 2 帧）
static var unit_frame_offsets := {
	"rifle_infantry": 0,   # 步枪兵
	"rocket_soldier": 2,   # 火箭筒兵
	"grenadier": 4,        # 榴弹兵小组
	"artillery": 6,        # 牵引式火炮
	"light_tank": 8,       # 奇兵快攻车
	"apc": 10,             # 装甲运兵车
	"medium_tank": 12,     # 主战坦克
	"heavy_tank": 12,      # 主战坦克（放大渲染体现重型）
	"fighter": 14,         # 战斗机
	"bomber": 16,          # 轰炸机
	"helicopter": 18,      # 直升机
	"machine_gunner": 20,  # 机枪兵
	"harvester": 22,       # 运输卡车
	"gunboat": 24,         # 快艇
	"destroyer": 26,       # 战舰
	"battleship": 28,      # 重型舰
	"at_squad": 30,        # 反坦克炮组
	"engineer": 38,        # 工兵/后勤兵
}

# 建筑图集：每 3 张一组（总部/圆顶/码头）× 7 套配色
# 按功能选色；建造厂与造船厂按阵营区分（玩家蓝/AI 红）
const BUILDING_SHEET_DIR := "res://assets/sprites/buildings/elite_command_art_buildings/bases-sliced"

static var building_sheet_index := {
	"power_plant": 19,      # 黄色能量圆顶
	"barracks": 18,         # 黄旗营房
	"ore_refinery": 13,     # 金币圆顶
	"war_factory": 0,       # 灰色厂房
	"radar": 1,             # 灰色雷达碗圆顶
	"repair_pad": 10,       # 绿色按钮圆顶
	"turret_gun": 4,        # 红色按钮圆顶
	"turret_missile": 16,   # 紫色高科技圆顶
	"airfield": 12,         # 金色旗帜总部
}

# 阵营专属：[玩家蓝, AI 红]
static var building_faction_index := {
	"construction_yard": [6, 3],
	"shipyard": [8, 5],
}

# 指示器与状态图标素材
static var indicator_paths := {
	"selection": "res://assets/sprites/units/elite_command_art_units/selection.png",
	"target": "res://assets/sprites/units/elite_command_art_units/target.png",
	"friendly_target": "res://assets/sprites/units/elite_command_art_units/friendly_target.png",
	"red_mask": "res://assets/sprites/units/elite_command_art_units/red_mask.png",
	"grey_mask": "res://assets/sprites/units/elite_command_art_units/grey_mask.png",
	"peace": "res://assets/sprites/units/elite_command_art_units/peace.png",
	"defeated": "res://assets/sprites/units/elite_command_art_units/defeated.png",
	"bridge_v": "res://assets/sprites/buildings/elite_command_art_buildings/bridges-sliced/0.png",
	"bridge_h": "res://assets/sprites/buildings/elite_command_art_buildings/bridges-sliced/2.png",
}

static var building_sprites := {
	"construction_yard": "res://assets/sprites/buildings/elite_command_art_buildings/bases-sliced/0.png",
	"power_plant": "res://assets/sprites/buildings/elite_command_art_buildings/bases-sliced/4.png",
	"barracks": "res://assets/sprites/buildings/elite_command_art_buildings/bases-sliced/8.png",
	"ore_refinery": "res://assets/sprites/buildings/elite_command_art_buildings/bases-sliced/12.png",
	"war_factory": "res://assets/sprites/buildings/elite_command_art_buildings/bases-sliced/16.png",
	"radar": "res://assets/sprites/buildings/elite_command_art_buildings/bases-sliced/2.png",
	"repair_pad": "res://assets/sprites/buildings/elite_command_art_buildings/bases-sliced/6.png",
	"turret_gun": "res://assets/sprites/buildings/elite_command_art_buildings/bases-sliced/10.png",
	"turret_missile": "res://assets/sprites/buildings/elite_command_art_buildings/bases-sliced/14.png",
}

static var unit_sprites := {
	"rifle_infantry": UNIT_SHEET_DIR + "/40.png",
	"engineer": UNIT_SHEET_DIR + "/78.png",
	"rocket_soldier": UNIT_SHEET_DIR + "/42.png",
	"harvester": UNIT_SHEET_DIR + "/62.png",
	"light_tank": UNIT_SHEET_DIR + "/48.png",
	"medium_tank": UNIT_SHEET_DIR + "/52.png",
	"heavy_tank": UNIT_SHEET_DIR + "/52.png",
}

# 建筑图标（用于建造面板）
static var building_icons := {
	"construction_yard": "res://assets/sprites/icons/buildings/construction_yard.png",
	"power_plant": "res://assets/sprites/icons/buildings/power_plant.png",
	"barracks": "res://assets/sprites/icons/buildings/barracks.png",
	"ore_refinery": "res://assets/sprites/icons/buildings/ore_refinery.png",
	"war_factory": "res://assets/sprites/icons/buildings/war_factory.png",
	"radar": "res://assets/sprites/icons/buildings/radar.png",
	"repair_pad": "res://assets/sprites/icons/buildings/repair_pad.png",
	"turret_gun": "res://assets/sprites/icons/buildings/turret_gun.png",
	"turret_missile": "res://assets/sprites/icons/buildings/turret_missile.png",
}

# 单位图标（用于建造面板）
static var unit_icons := {
	"rifle_infantry": "res://assets/sprites/icons/units/rifle_infantry.png",
	"engineer": "res://assets/sprites/icons/units/engineer.png",
	"rocket_soldier": "res://assets/sprites/icons/units/rocket_soldier.png",
	"harvester": "res://assets/sprites/icons/units/harvester.png",
	"light_tank": "res://assets/sprites/icons/units/light_tank.png",
	"medium_tank": "res://assets/sprites/icons/units/medium_tank.png",
	"heavy_tank": "res://assets/sprites/icons/units/heavy_tank.png",
}

# HUD图标
static var hud_icons := {
	"credits": "res://assets/sprites/icons/hud/credits.png",
	"power": "res://assets/sprites/icons/hud/power.png",
}

static func get_texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path = ""
	if building_sprites.has(id):
		path = building_sprites[id]
	elif unit_sprites.has(id):
		path = unit_sprites[id]
	if path != "":
		var tex = load(path) as Texture2D
		if tex:
			_cache[id] = tex
			return tex
		else:
			push_warning("SpriteUtil: 无法加载纹理 %s -> %s" % [id, path])
	return null

## 获取建筑精灵：阵营专属建筑按 player_id 区分，其余按功能配色
static func get_building_texture(building_id: String, player_id: int = 0) -> Texture2D:
	var idx := -1
	if building_faction_index.has(building_id):
		var pair: Array = building_faction_index[building_id]
		idx = pair[player_id % pair.size()]
	elif building_sheet_index.has(building_id):
		idx = building_sheet_index[building_id]
	if idx < 0:
		return get_texture(building_id)
	var cache_key = "bld_%d" % idx
	if _cache.has(cache_key):
		return _cache[cache_key]
	var tex = load("%s/%d.png" % [BUILDING_SHEET_DIR, idx]) as Texture2D
	if tex:
		_cache[cache_key] = tex
	return tex

## 获取指示器/图标素材
static func get_indicator(name: String) -> Texture2D:
	var cache_key = "ind_" + name
	if _cache.has(cache_key):
		return _cache[cache_key]
	var path = indicator_paths.get(name, "")
	if path.is_empty():
		return null
	var tex = load(path) as Texture2D
	if tex:
		_cache[cache_key] = tex
	return tex

static func get_icon(id: String) -> Texture2D:
	var cache_key = "icon_" + id
	if _cache.has(cache_key):
		return _cache[cache_key]
	var path = ""
	if building_icons.has(id):
		path = building_icons[id]
	elif unit_icons.has(id):
		path = unit_icons[id]
	elif hud_icons.has(id):
		path = hud_icons[id]
	if path != "":
		var tex = load(path) as Texture2D
		if tex:
			_cache[cache_key] = tex
			return tex
		else:
			push_warning("SpriteUtil: 无法加载图标 %s -> %s" % [id, path])
	# 无专属图标的新单位/建筑：回退到蓝色阵营的实体精灵
	if unit_frame_offsets.has(id):
		var frames = get_unit_frames(id, 0)
		if not frames.is_empty():
			_cache[cache_key] = frames[0]
			return frames[0]
	if building_sheet_index.has(id) or building_faction_index.has(id):
		var btex = get_building_texture(id, 0)
		if btex:
			_cache[cache_key] = btex
			return btex
	return null

## 获取单位的阵营配色动画帧（2 帧）；无映射时返回空数组
static func get_unit_frames(unit_id: String, player_id: int) -> Array:
	if not unit_frame_offsets.has(unit_id):
		return []
	var base: int = _faction_row_base[player_id % _faction_row_base.size()]
	var idx: int = base + unit_frame_offsets[unit_id]
	var frames := []
	for i in range(2):
		var cache_key = "unit_frame_%d" % (idx + i)
		if _cache.has(cache_key):
			frames.append(_cache[cache_key])
			continue
		var path = "%s/%d.png" % [UNIT_SHEET_DIR, idx + i]
		var tex = load(path) as Texture2D
		if tex:
			_cache[cache_key] = tex
			frames.append(tex)
		else:
			push_warning("SpriteUtil: 无法加载单位帧 %s -> %s" % [unit_id, path])
	return frames
