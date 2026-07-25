extends Node

## 全局用户设置管理：统一持久化音量与显示设置，并在启动时应用。
## 设置保存到 user://settings.cfg（Web 平台由浏览器 IndexedDB 持久化）。

const SETTINGS_PATH := "user://settings.cfg"

signal settings_changed

var music_volume: float = 0.8
var sfx_volume: float = 1.0
var fullscreen: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_volume = clampf(cfg.get_value("audio", "music_volume", music_volume), 0.0, 1.0)
	sfx_volume = clampf(cfg.get_value("audio", "sfx_volume", sfx_volume), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)

func apply_all() -> void:
	_apply_music_volume()
	_apply_sfx_volume()
	_apply_fullscreen()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_music_volume()
	settings_changed.emit()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_sfx_volume()
	settings_changed.emit()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	settings_changed.emit()

func _apply_music_volume() -> void:
	if AudioManager:
		AudioManager.set_music_volume(music_volume)

func _apply_sfx_volume() -> void:
	if AudioManager:
		AudioManager.set_sfx_volume(sfx_volume)

func _apply_fullscreen() -> void:
	# Web 平台切换全屏需要用户手势触发，启动时的窗口化调用为无害的空操作。
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
