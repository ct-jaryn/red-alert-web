extends Node2D

var _particles: Array = []

func create_explosion(pos: Vector2, size: float = 1.0) -> void:
	for i in range(int(8 * size)):
		_add_particle(
			pos + Vector2(randf_range(-10, 10) * size, randf_range(-10, 10) * size),
			Vector2(randf_range(-80, 80) * size, randf_range(-80, 80) * size),
			Color(1, randf_range(0.3, 0.8), 0),
			randf_range(0.3, 0.6),
			randf_range(3.0, 6.0) * size
		)
	for i in range(int(5 * size)):
		_add_particle(
			pos,
			Vector2(randf_range(-40, 40) * size, randf_range(-40, 40) * size),
			Color(0.3, 0.3, 0.3, 0.8),
			randf_range(0.5, 1.0),
			randf_range(4.0, 8.0) * size
		)

func create_muzzle_flash(pos: Vector2, direction: Vector2) -> void:
	for i in range(3):
		_add_particle(
			pos,
			direction * randf_range(100, 200) + Vector2(randf_range(-30, 30), randf_range(-30, 30)),
			Color(1, 0.9, 0.5),
			0.15,
			randf_range(2.0, 4.0)
		)

func create_hit_effect(pos: Vector2, color: Color = Color(1, 0.5, 0)) -> void:
	for i in range(5):
		_add_particle(
			pos,
			Vector2(randf_range(-60, 60), randf_range(-60, 60)),
			color,
			randf_range(0.2, 0.4),
			randf_range(2.0, 4.0)
		)

func create_ore_harvest_effect(pos: Vector2) -> void:
	for i in range(3):
		_add_particle(
			pos + Vector2(randf_range(-5, 5), randf_range(-5, 5)),
			Vector2(randf_range(-20, 20), randf_range(-40, -20)),
			Color(1, 0.85, 0),
			randf_range(0.3, 0.5),
			randf_range(2.0, 3.0)
		)

func create_build_effect(pos: Vector2, sz: Vector2) -> void:
	for i in range(12):
		var angle = i * TAU / 12.0
		var r = maxf(sz.x, sz.y) / 2.0
		_add_particle(
			pos + Vector2(cos(angle) * r, sin(angle) * r),
			Vector2(cos(angle) * 20, sin(angle) * 20),
			Color(0.5, 0.8, 1, 0.6),
			0.8,
			3.0
		)

func _add_particle(pos: Vector2, vel: Vector2, color: Color, lifetime: float, size: float) -> void:
	_particles.append({
		"pos": pos,
		"vel": vel,
		"color": color,
		"life": lifetime,
		"max_life": lifetime,
		"size": size,
	})
	queue_redraw()

func _process(delta: float) -> void:
	if _particles.is_empty():
		return
	for i in range(_particles.size() - 1, -1, -1):
		var p = _particles[i]
		p["life"] -= delta
		if p["life"] <= 0:
			_particles.remove_at(i)
		else:
			p["vel"] = p["vel"] + Vector2(0, 40 * delta)
			p["pos"] = p["pos"] + p["vel"] * delta
	queue_redraw()

func _draw() -> void:
	for p in _particles:
		var ratio = p["life"] / p["max_life"]
		var alpha = p["color"].a * ratio
		var c = Color(p["color"].r, p["color"].g, p["color"].b, alpha)
		var s = p["size"] * ratio
		if s > 0.5:
			draw_circle(p["pos"], s, c)
