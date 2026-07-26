extends Node

var music_volume: float = 0.8
var sfx_volume: float = 1.0

const MIX_RATE := 22050

# 音效资源缓存 — 名称 -> AudioStream（启动时程序化合成，无需音频文件）
var _sfx_cache: Dictionary = {}

# 预定义音效路径映射（外部文件可覆盖同名合成音效）
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
	_generate_sfx()

## 程序化合成全部基础音效
func _generate_sfx() -> void:
	_sfx_cache["select"] = _make_stream(_gen_blip([880.0, 1240.0], 0.045))
	_sfx_cache["build"] = _make_stream(_gen_blip([520.0, 660.0, 840.0], 0.06))
	_sfx_cache["harvest"] = _make_stream(_gen_blip([1320.0, 1760.0], 0.04))
	_sfx_cache["attack"] = _make_stream(_gen_shot())
	_sfx_cache["explosion"] = _make_stream(_gen_explosion())
	_sfx_cache["hit"] = _make_stream(_gen_hit())

func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	stream.data = data
	return stream

## 多段单音蜂鸣（UI/提示类）
func _gen_blip(freqs: Array, seg_dur: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	for f in freqs:
		var n = int(seg_dur * MIX_RATE)
		for i in range(n):
			var t = float(i) / MIX_RATE
			var env = 1.0 - float(i) / n
			samples.append(sin(TAU * f * t) * 0.32 * env)
	return samples

## 枪声：噪声爆发 + 低频冲击
func _gen_shot() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var n = int(0.09 * MIX_RATE)
	for i in range(n):
		var t = float(i) / MIX_RATE
		var d = 1.0 - float(i) / n
		samples.append((randf() * 2.0 - 1.0) * 0.4 * d * d + sin(TAU * 170.0 * t) * 0.28 * d)
	return samples

## 爆炸：低通噪声指数衰减
func _gen_explosion() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var n = int(0.45 * MIX_RATE)
	var lp := 0.0
	for i in range(n):
		var t = float(i) / MIX_RATE
		lp = lp * 0.72 + (randf() * 2.0 - 1.0) * 0.28
		samples.append(lp * 0.85 * exp(-4.5 * t))
	return samples

## 命中：短促哒声
func _gen_hit() -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var n = int(0.03 * MIX_RATE)
	for i in range(n):
		var d = 1.0 - float(i) / n
		samples.append((randf() * 2.0 - 1.0) * 0.25 * d)
	return samples

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)

func play_sfx(sfx_name: String) -> void:
	var stream = _get_sfx_stream(sfx_name)
	if not stream:
		return
	# 并发限制：大规模交战时避免音效叠加爆音
	if get_child_count() >= 12:
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
