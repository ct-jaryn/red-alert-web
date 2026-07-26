extends Node

## 多人联机管理器：WebSocket 主机权威架构（1v1）。
## 主机=玩家0，运行完整模拟；客户端=玩家1，发送指令并按快照渲染镜像。

const MapData = preload("res://scripts/data/map_data.gd")
const UnitData = preload("res://scripts/data/unit_data.gd")
const SpriteUtilScript = preload("res://scripts/ui/sprite_util.gd")

enum Mode { OFFLINE, HOST, CLIENT }

const DEFAULT_PORT := 9101
const SNAPSHOT_INTERVAL := 0.15

var mode: int = Mode.OFFLINE
var match_seed: int = 0
var in_match: bool = false

var _client_peer: int = 0
var _next_net_id: int = 1
var _tracked: Dictionary = {}   # net_id -> Node（主机侧）
var _puppets: Dictionary = {}   # net_id -> Node（客户端侧镜像）
var _snapshot_timer: float = 0.0
var _snap_count: int = 0

signal net_status(text: String)

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func(): net_status.emit("已连接主机，等待开始..."))
	multiplayer.connection_failed.connect(func():
		leave()
		net_status.emit("连接失败")
	)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = DEFAULT_PORT) -> bool:
	var peer = WebSocketMultiplayerPeer.new()
	if peer.create_server(port) != OK:
		net_status.emit("创建主机失败（端口 %d 被占用？）" % port)
		return false
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	net_status.emit("主机已创建（端口 %d），等待玩家加入..." % port)
	return true

func join_game(url: String) -> bool:
	var peer = WebSocketMultiplayerPeer.new()
	if peer.create_client(url) != OK:
		net_status.emit("无效的主机地址")
		return false
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	net_status.emit("正在连接 %s ..." % url)
	return true

func leave() -> void:
	in_match = false
	mode = Mode.OFFLINE
	_client_peer = 0
	_tracked.clear()
	_puppets.clear()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func is_client() -> bool:
	return mode == Mode.CLIENT

func _on_peer_connected(id: int) -> void:
	if mode != Mode.HOST:
		return
	if _client_peer != 0:
		# 仅支持 1v1，多余连接直接断开
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	_client_peer = id
	print("NET_HOST: peer %d connected, starting match" % id)
	_start_match.rpc(randi(), GameManager.map_size_option)

func _on_peer_disconnected(id: int) -> void:
	if mode == Mode.HOST and id == _client_peer:
		_client_peer = 0
		if in_match:
			_back_to_menu("对方已断线")
		else:
			net_status.emit("对方已断线")

func _on_server_disconnected() -> void:
	if mode == Mode.CLIENT:
		var was_in_match = in_match
		net_status.emit("与主机断开连接")
		if was_in_match:
			_back_to_menu("与主机断开连接")
		else:
			leave()

func _back_to_menu(_reason: String) -> void:
	in_match = false
	GameManager.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	leave()

@rpc("authority", "call_local", "reliable")
func _start_match(seed_val: int, map_opt: int) -> void:
	match_seed = seed_val
	in_match = true
	_next_net_id = 1
	_tracked.clear()
	_puppets.clear()
	GameManager.reset()
	# 联机地图用预设尺寸（双方由同一种子确定性生成）
	GameManager.map_size_option = mini(map_opt, 2)
	GameManager.local_player_id = 0 if mode == Mode.HOST else 1
	get_tree().paused = false
	print("NET: match start seed=%d local_player=%d" % [seed_val, GameManager.local_player_id])
	get_tree().change_scene_to_file("res://scenes/game/main.tscn")

## 主机：登记实体并分配网络 ID
func track_entity(node: Node) -> void:
	if mode != Mode.HOST or not in_match:
		return
	if node.has_meta("net_id"):
		return
	node.set_meta("net_id", _next_net_id)
	_tracked[_next_net_id] = node
	_next_net_id += 1

func _process(delta: float) -> void:
	if mode != Mode.HOST or not in_match or _client_peer == 0:
		return
	_snapshot_timer -= delta
	if _snapshot_timer <= 0:
		_snapshot_timer = SNAPSHOT_INTERVAL
		_send_snapshot()

# ---------- 主机 → 客户端：状态快照 ----------

func _send_snapshot() -> void:
	var ents := []
	var dead := []
	for nid in _tracked:
		var n = _tracked[nid]
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			dead.append(nid)
			continue
		var kind := 0 if n.is_in_group("buildings") else 1
		var flip := 0
		if kind == 1 and n._sprite_rect and n._sprite_rect.flip_h:
			flip = 1
		ents.append([nid, kind, n.unit_id, n.player_id, snappedf(n.global_position.x, 0.1), snappedf(n.global_position.y, 0.1), n.health, flip])
	for nid in dead:
		_tracked.erase(nid)
	var data := {"e": ents}
	var p0 = GameManager.get_player(0)
	var p1 = GameManager.get_player(1)
	if p0 and p1:
		data["c"] = [p0.credits, p1.credits]
		data["pw"] = [[p0.power_generated, p0.power_used], [p1.power_generated, p1.power_used]]
		data["q"] = p1.build_queue
		data["cur"] = p1.current_build_item
		data["prog"] = p1.build_progress
		data["bb"] = p1.built_buildings
	_apply_snapshot.rpc_id(_client_peer, data)

@rpc("authority", "reliable")
func _apply_snapshot(data: Dictionary) -> void:
	if mode != Mode.CLIENT or not in_match:
		return
	var main = get_tree().current_scene
	if main == null or not main.has_method("_create_unit"):
		return
	_snap_count += 1
	var seen := {}
	for e in data.get("e", []):
		var nid = int(e[0])
		var kind = int(e[1])
		var uid = str(e[2])
		var pid = int(e[3])
		var pos = Vector2(float(e[4]), float(e[5]))
		var hp = int(e[6])
		var flip = int(e[7]) == 1
		seen[nid] = true
		var node = _puppets.get(nid)
		if node == null or not is_instance_valid(node):
			node = main._create_building(uid, pid, pos) if kind == 0 else main._create_unit(uid, pid, pos)
			if node == null:
				continue
			# 镜像实体：禁用本地模拟，仅随快照更新
			node.set_physics_process(false)
			node.set_meta("puppet", true)
			node.set_meta("net_id", nid)
			_puppets[nid] = node
		node.global_position = pos
		node.health = hp
		if node.player_id != pid:
			# 建筑被占领等所有权变化：刷新阵营视觉
			node.player_id = pid
			if kind == 0:
				node._tint_rect.color = MapData.get_player_tint(pid, 0.12)
				var tex = SpriteUtilScript.get_building_texture(uid, pid)
				if tex:
					node._sprite_rect.texture = tex
		if kind == 1 and node._sprite_rect:
			node._sprite_rect.flip_h = flip
	var to_remove := []
	for nid in _puppets:
		if not seen.has(nid):
			to_remove.append(nid)
	for nid in to_remove:
		var n = _puppets[nid]
		_puppets.erase(nid)
		if is_instance_valid(n):
			if main.has_node("Effects"):
				main.get_node("Effects").create_explosion(n.global_position, 1.2)
			AudioManager.play_sfx("explosion")
			n.queue_free()
	# 同步经济/电力/建造队列到本地显示
	if GameManager.players.size() >= 2 and data.has("c"):
		var c = data["c"]
		var pw = data["pw"]
		for i in range(2):
			var p = GameManager.players[i]
			p.credits = int(c[i])
			p.power_generated = int(pw[i][0])
			p.power_used = int(pw[i][1])
		var lp = GameManager.get_player(1)
		lp.build_queue.clear()
		for q in data.get("q", []):
			lp.build_queue.append(str(q))
		lp.current_build_item = str(data.get("cur", ""))
		lp.build_progress = float(data.get("prog", 0.0))
		lp.built_buildings.clear()
		var bb = data.get("bb", {})
		for k in bb:
			lp.built_buildings[k] = int(bb[k])
		GameManager.credits_changed.emit(1, lp.credits)
		GameManager.power_changed.emit(1, lp.power_generated, lp.power_used)
		GameManager.build_queue_updated.emit(1, lp.build_queue)
	if _snap_count % 40 == 1:
		print("NET_SNAP #%d ents=%d puppets=%d local_credits=%d" % [_snap_count, data.get("e", []).size(), _puppets.size(), GameManager.get_player(1).credits if GameManager.players.size() >= 2 else -1])

# ---------- 客户端 → 主机：操作指令 ----------

func send_move(ids: Array, pos: Vector2) -> void:
	_cmd_move.rpc_id(1, ids, pos.x, pos.y)

@rpc("any_peer", "reliable")
func _cmd_move(ids: Array, x: float, y: float) -> void:
	if mode != Mode.HOST or multiplayer.get_remote_sender_id() != _client_peer:
		return
	var pos = Vector2(x, y)
	var units := []
	for nid in ids:
		var n = _tracked.get(int(nid))
		if is_instance_valid(n) and n.is_in_group("units") and n.player_id == 1:
			units.append(n)
	var cols = ceili(sqrt(maxi(units.size(), 1)))
	for i in range(units.size()):
		var offset = Vector2((i % cols - cols / 2.0) * 30, (i / cols - cols / 2.0) * 30)
		units[i].move_to(pos + offset)

func send_attack(ids: Array, target_nid: int) -> void:
	_cmd_attack.rpc_id(1, ids, target_nid)

@rpc("any_peer", "reliable")
func _cmd_attack(ids: Array, target_nid: int) -> void:
	if mode != Mode.HOST or multiplayer.get_remote_sender_id() != _client_peer:
		return
	var target = _tracked.get(int(target_nid))
	if not is_instance_valid(target):
		return
	for nid in ids:
		var n = _tracked.get(int(nid))
		if is_instance_valid(n) and n.is_in_group("units") and n.player_id == 1 and n.has_method("attack_target"):
			n.attack_target(target)

func send_build(item_id: String) -> void:
	_cmd_build.rpc_id(1, item_id)

@rpc("any_peer", "reliable")
func _cmd_build(item_id: String) -> void:
	if mode != Mode.HOST or multiplayer.get_remote_sender_id() != _client_peer:
		return
	GameManager.add_to_build_queue(1, item_id)

func send_cancel_queue(index: int, item_id: String) -> void:
	_cmd_cancel_queue.rpc_id(1, index, item_id)

@rpc("any_peer", "reliable")
func _cmd_cancel_queue(index: int, item_id: String) -> void:
	if mode != Mode.HOST or multiplayer.get_remote_sender_id() != _client_peer:
		return
	var p = GameManager.get_player(1)
	if not p or index < 0 or index >= p.build_queue.size():
		return
	if p.build_queue[index] != item_id:
		return
	var info = UnitData.get_unit_info(item_id)
	p.build_queue.remove_at(index)
	GameManager.add_credits(1, info.get("cost", 0))
	if index == 0:
		p.current_build_item = ""
		p.build_progress = 0.0
		if not p.build_queue.is_empty():
			p.current_build_item = p.build_queue[0]

func send_place(item_id: String, pos: Vector2) -> void:
	_cmd_place.rpc_id(1, item_id, pos.x, pos.y)

@rpc("any_peer", "reliable")
func _cmd_place(item_id: String, x: float, y: float) -> void:
	if mode != Mode.HOST or multiplayer.get_remote_sender_id() != _client_peer:
		return
	if GameManager.pending_building_player != 1 or GameManager.pending_building_id != item_id:
		return
	var info = UnitData.get_unit_info(item_id)
	var size = info.get("size", Vector2i(1, 1))
	var pos = Vector2(x, y)
	if GameManager._ai_can_place_at(1, pos, size):
		GameManager.confirm_building_placement(pos)
	else:
		# 位置无效：退款并清除待放置
		GameManager.add_credits(1, info.get("cost", 0))
		GameManager.pending_building_id = ""
		GameManager.pending_building_player = -1

func send_cancel_place(item_id: String) -> void:
	_cmd_cancel_place.rpc_id(1, item_id)

@rpc("any_peer", "reliable")
func _cmd_cancel_place(item_id: String) -> void:
	if mode != Mode.HOST or multiplayer.get_remote_sender_id() != _client_peer:
		return
	if GameManager.pending_building_player != 1 or GameManager.pending_building_id != item_id:
		return
	var info = UnitData.get_unit_info(item_id)
	GameManager.add_credits(1, info.get("cost", 0))
	GameManager.pending_building_id = ""
	GameManager.pending_building_player = -1

# ---------- 主机 → 客户端：事件 ----------

## 主机：客户端玩家的建筑就绪，通知其进入放置模式
func notify_ready_to_place(item_id: String) -> void:
	if mode == Mode.HOST and _client_peer != 0:
		_remote_ready_place.rpc_id(_client_peer, item_id)

@rpc("authority", "reliable")
func _remote_ready_place(item_id: String) -> void:
	var main = get_tree().current_scene
	if main and "building_placer" in main and main.building_placer:
		main.building_placer.start_placement(item_id, 1)

## 主机：广播开火事件供客户端播放特效音效
func broadcast_fire(from_pos: Vector2, to_pos: Vector2) -> void:
	if mode == Mode.HOST and _client_peer != 0:
		_fire_event.rpc_id(_client_peer, from_pos.x, from_pos.y, to_pos.x, to_pos.y)
@rpc("authority", "unreliable")
func _fire_event(fx: float, fy: float, tx: float, ty: float) -> void:
	var main = get_tree().current_scene
	if main and main.has_node("Effects"):
		var eff = main.get_node("Effects")
		var from_pos = Vector2(fx, fy)
		var to_pos = Vector2(tx, ty)
		eff.create_muzzle_flash(from_pos, (to_pos - from_pos).normalized())
		eff.create_hit_effect(to_pos)
	AudioManager.play_sfx("attack")

## 主机：胜负判定后同步给客户端
func on_host_game_over(winner: int) -> void:
	if mode == Mode.HOST and _client_peer != 0:
		_game_over_event.rpc_id(_client_peer, winner)

@rpc("authority", "reliable")
func _game_over_event(winner: int) -> void:
	in_match = false
	GameManager.current_state = GameManager.GameState.GAME_OVER
	GameManager.game_over.emit(winner)

## 主机：同步地块变化（矿石被采集等）
func report_tile_change(tile: Vector2i, terrain: int) -> void:
	if mode == Mode.HOST and in_match and _client_peer != 0:
		_tile_change.rpc_id(_client_peer, tile.x, tile.y, terrain)

@rpc("authority", "reliable")
func _tile_change(x: int, y: int, terrain: int) -> void:
	if y >= 0 and y < GameManager.map_height and x >= 0 and x < GameManager.map_width:
		GameManager.game_map[y][x] = terrain
		var main = get_tree().current_scene
		if main and main.has_node("MapRenderer"):
			main.get_node("MapRenderer").queue_redraw()
