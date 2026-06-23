extends Node

var music_volume: float = 0.8
var sfx_volume: float = 1.0

# 音效资源缓存 — 路径 -> AudioStream
var _sfx_cache: Dictionary = {}

# 预定义音效路径映射
var _sfx_paths: Dictionary = {
	"select": "",
	"attack": "",
	"build": "",
	"explosion": "",
	"hit": "",
	"harvest": "",
}

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)

func play_sfx(sfx_name: String) -> void:
	var stream = _get_sfx_stream(sfx_name)
	if not stream:
		return
	var player = AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	match sfx_name:
		"select":
			player.pitch_scale = randf_range(0.9, 1.1)
		"attack":
			player.pitch_scale = randf_range(0.8, 1.0)
		"build":
			player.pitch_scale = 1.0
		_:
			pass
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _get_sfx_stream(sfx_name: String) -> AudioStream:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	var path = _sfx_paths.get(sfx_name, "")
	if path.is_empty():
		return null
	var stream = load(path) as AudioStream
	if stream:
		_sfx_cache[sfx_name] = stream
	return stream

func register_sfx(sfx_name: String, path: String) -> void:
	_sfx_paths[sfx_name] = path

func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	var idx = AudioServer.get_bus_index("Music")
	if idx >= 0:
		var db := -80.0 if music_volume <= 0.0 else linear_to_db(music_volume)
		AudioServer.set_bus_volume_db(idx, db)

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
	var idx = AudioServer.get_bus_index("SFX")
	if idx >= 0:
		var db := -80.0 if sfx_volume <= 0.0 else linear_to_db(sfx_volume)
		AudioServer.set_bus_volume_db(idx, db)
