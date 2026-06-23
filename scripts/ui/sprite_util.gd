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
