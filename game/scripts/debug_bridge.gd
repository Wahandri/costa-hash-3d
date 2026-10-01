extends Node
## Puente de depuracion para playtest automatico / agente LLM.
## Solo se activa en escritorio/headless con el argumento de usuario "--debug-bridge".
## Protocolo: JSON por linea (un objeto por linea, respuesta JSON + "\n").
##
##   -> {"cmd":"state"}                 <- estado del juego
##   -> {"cmd":"move","x":0.0,"y":-1.0} <- mueve al jugador (autopilot)
##   -> {"cmd":"look","x":10,"y":0}     <- giro de camara en pixeles
##   -> {"cmd":"action"}                <- boton de accion
##   -> {"cmd":"ping"}                  <- "pong"

const DEFAULT_PORT := 9099

var enabled: bool = false
var _server: TCPServer
var _clients: Array[StreamPeerTCP] = []
var _buffers: Dictionary = {}


func _ready() -> void:
	if OS.has_feature("web"):
		set_process(false)
		return
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if not args.has("--debug-bridge"):
		set_process(false)
		return
	enabled = true
	_server = TCPServer.new()
	var err := _server.listen(DEFAULT_PORT, "127.0.0.1")
	if err != OK:
		push_warning("[DebugBridge] no se pudo escuchar en %d (err %d)" % [DEFAULT_PORT, err])
		set_process(false)
		return
	print("[DebugBridge] escuchando en 127.0.0.1:%d" % DEFAULT_PORT)


func _process(_delta: float) -> void:
	if _server == null:
		return
	while _server.is_connection_available():
		var peer := _server.take_connection()
		_clients.append(peer)
		_buffers[peer.get_instance_id()] = ""

	for i in range(_clients.size() - 1, -1, -1):
		var c: StreamPeerTCP = _clients[i]
		c.poll()
		if c.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_buffers.erase(c.get_instance_id())
			_clients.remove_at(i)
			continue
		var avail := c.get_available_bytes()
		if avail > 0:
			var chunk := c.get_utf8_string(avail)
			var key := c.get_instance_id()
			_buffers[key] = str(_buffers.get(key, "")) + chunk
			_consume_lines(c, key)


func _consume_lines(c: StreamPeerTCP, key: int) -> void:
	var buf: String = str(_buffers.get(key, ""))
	while buf.contains("\n"):
		var idx := buf.find("\n")
		var line := buf.substr(0, idx).strip_edges()
		buf = buf.substr(idx + 1)
		if not line.is_empty():
			_handle(c, line)
	_buffers[key] = buf


func _handle(c: StreamPeerTCP, line: String) -> void:
	var parsed: Variant = JSON.parse_string(line)
	if typeof(parsed) != TYPE_DICTIONARY:
		_send(c, {"ok": false, "error": "json invalido"})
		return
	var msg: Dictionary = parsed
	match str(msg.get("cmd", "")):
		"state":
			_send(c, {"ok": true, "state": get_state()})
		"move":
			Controls.touch_move = Vector2(float(msg.get("x", 0.0)), float(msg.get("y", 0.0)))
			Controls.nav_active = false
			_send(c, {"ok": true})
		"goto":
			Controls.nav_target = Vector3(float(msg.get("x", 0.0)), 0.0, float(msg.get("z", 0.0)))
			Controls.nav_active = true
			_send(c, {"ok": true})
		"stop":
			Controls.nav_active = false
			Controls.touch_move = Vector2.ZERO
			_send(c, {"ok": true})
		"look":
			Controls.add_look_delta(Vector2(float(msg.get("x", 0.0)), float(msg.get("y", 0.0))))
			_send(c, {"ok": true})
		"action":
			Controls.press_action()
			_send(c, {"ok": true})
		"crime":
			Controls.press_crime()
			_send(c, {"ok": true})
		"damage":
			Health.damage(float(msg.get("amount", 10.0)), "debug")
			_send(c, {"ok": true, "health": Health.value, "money": GameState.money})
		"heal":
			Health.heal(float(msg.get("amount", 100.0)))
			_send(c, {"ok": true, "health": Health.value})
		"travel":
			var slug := str(msg.get("slug", GameState.district_slug))
			GameState.district_slug = slug
			RoadGraph.load_for(slug)
			GameState.save_game(false)
			_send(c, {"ok": true, "district": GameState.district_slug, "road_nodes": RoadGraph.pts.size()})
			get_tree().reload_current_scene()
		"buy_placa":
			_send(c, {"ok": Economy.buy_placa(), "posturas": GameState.posturas, "money": GameState.money})
		"sell":
			var cm := get_tree().get_first_node_in_group("clients_manager")
			var client: Node = null
			if cm != null and cm.has_method("nearest_within"):
				client = cm.nearest_within(60.0)
			if client == null:
				_send(c, {"ok": false, "error": "sin clientes cerca"})
			else:
				var res: Dictionary = Economy.sell_to(client.qty_max(), client.risk_factor())
				client.leave()
				_send(c, {"ok": true, "result": res, "money": GameState.money, "posturas": GameState.posturas})
		"ping":
			_send(c, {"ok": true, "pong": true})
		_:
			_send(c, {"ok": false, "error": "cmd desconocido"})


func _send(c: StreamPeerTCP, obj: Dictionary) -> void:
	c.put_data((JSON.stringify(obj) + "\n").to_utf8_buffer())


func get_state() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player")
	var pos := Vector3.ZERO
	var driving := false
	if player is Node3D:
		pos = (player as Node3D).global_position
	if player != null and player.has_method("is_driving"):
		driving = player.is_driving()
	var police_pos: Array = []
	for p in get_tree().get_nodes_in_group("police"):
		if p is Node3D:
			var pp := (p as Node3D).global_position
			police_pos.append([pp.x, pp.y, pp.z])

	var nearest_client: Array = []
	var cm := get_tree().get_first_node_in_group("clients_manager")
	if cm != null and cm.has_method("nearest_within"):
		var cl = cm.nearest_within(400.0)
		if cl is Node3D:
			var cp := (cl as Node3D).global_position
			nearest_client = [cp.x, cp.y, cp.z]

	return {
		"money": GameState.money,
		"posturas": GameState.posturas,
		"xp": GameState.xp,
		"rank": GameState.rank(),
		"respeto": GameState.respeto,
		"health": Health.value,
		"product": GameState.product_id,
		"clients": get_tree().get_nodes_in_group("clients").size(),
		"day": GameState.day,
		"hour": Clock.time_of_day,
		"mission": Missions.active_index,
		"mission_progress": Missions.active_progress,
		"wanted": GameState.wanted,
		"wanted_level": Wanted.level,
		"heat": Wanted.heat,
		"chasing": Wanted.chasing,
		"police": police_pos.size(),
		"nearest_client": nearest_client,
		"police_pos": police_pos,
		"driving": driving,
		"district": GameState.district_slug,
		"road_nodes": RoadGraph.pts.size(),
		"player_name": GameState.player_name,
		"pos": [pos.x, pos.y, pos.z],
		"bridge_clients": _clients.size(),
		"fps": Engine.get_frames_per_second(),
	}
