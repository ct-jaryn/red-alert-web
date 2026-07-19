class_name SpriteUtil
extends RefCounted

static var _cache: Dictionary = {}

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
	"rifle_infantry": "res://assets/sprites/units/elite_command_art_units/units-sliced/40.png",
	"engineer": "res://assets/sprites/units/elite_command_art_units/units-sliced/48.png",
	"rocket_soldier": "res://assets/sprites/units/elite_command_art_units/units-sliced/56.png",
	"harvester": "res://assets/sprites/units/elite_command_art_units/units-sliced/44.png",
	"light_tank": "res://assets/sprites/units/elite_command_art_units/units-sliced/200.png",
	"medium_tank": "res://assets/sprites/units/elite_command_art_units/units-sliced/204.png",
	"heavy_tank": "res://assets/sprites/units/elite_command_art_units/units-sliced/208.png",
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
	return null
