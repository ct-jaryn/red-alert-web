extends Node

var music_volume: float = 0.8
var sfx_volume: float = 1.0

func _ready() -> void:
	pass

func play_sfx(sfx_name: String) -> void:
	var player = AudioStreamPlayer.new()
	player.bus = "SFX"
	add_child(player)
	match sfx_name:
		"select":
			player.pitch_scale = randf_range(0.9, 1.1)
		"attack":
			player.pitch_scale = randf_range(0.8, 1.0)
		"build":
			player.pitch_scale = 1.0
		_:
			pass
	player.finished.connect(player.queue_free)
	if player.stream:
		player.play()
	else:
		player.queue_free()

func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))
