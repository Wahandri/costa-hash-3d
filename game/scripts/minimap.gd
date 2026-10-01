extends CanvasLayer
## Minimapa/radar con GPS hacia la mision activa y HUD de mision.

const RADAR_SIZE := 176.0
const RADIUS_M := 165.0
const SCALE := RADAR_SIZE / (RADIUS_M * 2.0)  # px por metro

var _view: Control
var _mission_label: Label
var _player: Node3D
var _redraw_cd: float = 0.0
var _route: PackedInt32Array = PackedInt32Array()
var _route_cd: float = 0.0
var _pcol: Color = Color("#6cf0a0")
var _rcol: Color = Color("#ff5a5a")
var _tcol: Color = Color("#ffd166")
var _road_col := Color(0.75, 0.78, 0.85, 0.55)


func _ready() -> void:
	layer = 5
	add_to_group("minimap")
	_player = get_tree().get_first_node_in_group("player")
	_build()
	Missions.mission_started.connect(func(_m: Dictionary) -> void: _route_cooldown())
	Missions.mission_completed.connect(func(_m: Dictionary) -> void: Audio.play_jingle())


func _build() -> void:
	_view = Control.new()
	_view.position = Vector2(14, 84)
	_view.size = Vector2(RADAR_SIZE, RADAR_SIZE)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_radar)
	_view.gui_input.connect(_on_radar_input)
	add_child(_view)

	_mission_label = Label.new()
	_mission_label.position = Vector2(14, 266)
	_mission_label.add_theme_font_size_override("font_size", 13)
	_mission_label.add_theme_color_override("font_color", Color("ffd166"))
	_mission_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mission_label)


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	_redraw_cd -= delta
	if _redraw_cd <= 0.0:
		_redraw_cd = 0.12
		_update_route(delta)
		_view.queue_redraw()
		_update_label()


func _route_cooldown() -> void:
	_route_cd = 0.0


func _update_label() -> void:
	var m: Dictionary = Missions.active_mission()
	if m.is_empty():
		_mission_label.text = ""
		return
	var goal := float(m.get("goal", 1.0))
	var prog := Missions.active_progress
	var dist_txt := ""
	if _player != null:
		var tp := Missions.target_pos()
		var d := Vector2(tp.x - _player.global_position.x, tp.z - _player.global_position.z).length()
		if d > 1.0:
			dist_txt = "  (a %d m)" % int(d)
	_mission_label.text = "MISION: %s  %d/%d%s\n%s" % [
		str(m.get("name", "")), int(prog), int(goal), dist_txt, str(m.get("desc", ""))]


func _update_route(_delta: float) -> void:
	_route_cd -= 0.12
	if _route_cd > 0.0:
		return
	_route_cd = 0.6
	var tn: int = Missions.target_node()
	if tn < 0 or _player == null or not RoadGraph.loaded:
		_route = PackedInt32Array()
		return
	var start := RoadGraph.nearest_node(_player.global_position)
	_route = RoadGraph.find_path(start, tn)


# --------------------------------------------------------------------------
# Dibujo
# --------------------------------------------------------------------------

func _draw_radar() -> void:
	var c := RADAR_SIZE * 0.5
	var center := Vector2(c, c)
	# fondo
	_view.draw_circle(center, c, Color(0.05, 0.07, 0.11, 0.72))
	_view.draw_arc(center, c - 1.0, 0.0, TAU, 40, Color(0.7, 0.75, 0.85, 0.5), 1.5)
	if _player == null or not RoadGraph.loaded:
		return
	var ppos := _player.global_position

	# calles cercanas
	var n := RoadGraph.pts.size()
	for i in range(n):
		var a := RoadGraph.node_world(i)
		if a.distance_squared_to(ppos) > (RADIUS_M + 20.0) * (RADIUS_M + 20.0):
			continue
		for e in RoadGraph.adj[i]:
			var j: int = int(e["to"])
			if j < i:
				continue
			var b := RoadGraph.node_world(j)
			if b.distance_squared_to(ppos) > (RADIUS_M + 20.0) * (RADIUS_M + 20.0):
				continue
			_view.draw_line(_proj(a, ppos, center), _proj(b, ppos, center), _road_col, 1.5)

	# ruta GPS
	if _route.size() > 1:
		for k in range(_route.size() - 1):
			var a := RoadGraph.node_world(_route[k])
			var b := RoadGraph.node_world(_route[k + 1])
			_view.draw_line(_proj(a, ppos, center), _proj(b, ppos, center), Color("ffcf3f"), 2.5)

	# objetivo de mision (punto si esta dentro, flecha al borde si esta fuera)
	var tn: int = Missions.target_node()
	if tn >= 0:
		var tp := RoadGraph.node_world(tn)
		if tp.distance_to(ppos) <= RADIUS_M:
			_view.draw_circle(_proj(tp, ppos, center), 5.0, Color("ffd166"))
		else:
			var dir := Vector2(tp.x - ppos.x, tp.z - ppos.z).normalized()
			var edge := center + dir * (c - 10.0)
			var perp := Vector2(-dir.y, dir.x)
			var tip := edge + dir * 8.0
			var l := edge - dir * 4.0 + perp * 6.0
			var r := edge - dir * 4.0 - perp * 6.0
			_view.draw_colored_polygon(PackedVector2Array([tip, l, r]), Color("ffd166"))

	# blips
	_draw_group("police", _rcol, ppos, center, 3.5)
	_draw_group("clients", _pcol, ppos, center, 3.0)
	_draw_group("traffic", _tcol, ppos, center, 2.2)
	# vehiculos propios (la moto) en cian
	_draw_group("vehicles", Color("66e0ff"), ppos, center, 3.6)
	# landmarks (iglesia/salud/colegio...) como cuadrados blancos
	for node in get_tree().get_nodes_in_group("landmarks"):
		if node is Node3D:
			var lp := (node as Node3D).global_position
			if lp.distance_to(ppos) <= RADIUS_M:
				var s := _proj(lp, ppos, center)
				_view.draw_rect(Rect2(s - Vector2(3, 3), Vector2(6, 6)), Color("ffffff"), true)

	# jugador (triangulo orientado hacia donde mira la camara/jugador)
	var cam := get_viewport().get_camera_3d()
	var fwd3 := Vector3(0, 0, -1)
	if cam != null:
		fwd3 = -cam.global_transform.basis.z
	var fwd := Vector2(fwd3.x, fwd3.z)
	if fwd.length() < 0.01:
		fwd = Vector2(0, -1)
	fwd = fwd.normalized()
	var right := Vector2(-fwd.y, fwd.x)
	var tip := center + fwd * 7.5
	var l := center - fwd * 4.5 + right * 4.5
	var r := center - fwd * 4.5 - right * 4.5
	_view.draw_colored_polygon(PackedVector2Array([tip, l, r]), Color("ffffff"))

	# norte
	_view.draw_string(ThemeDB.fallback_font, Vector2(c - 4.0, 12.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))


## True si el punto (global de pantalla) cae sobre el radar.
func is_in_radar(pos: Vector2) -> bool:
	return _view != null and _view.get_global_rect().has_point(pos)


func _input(event: InputEvent) -> void:
	# Tap sobre el radar -> abrir mapa (se maneja aqui para asegurar que tiene
	# prioridad frente al sistema de camara tactil).
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		if is_in_radar((event as InputEventScreenTouch).position):
			_open_map()
			get_viewport().set_input_as_handled()


func _on_radar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_open_map()
			_view.accept_event()
	elif event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			_open_map()
			_view.accept_event()


func _open_map() -> void:
	var m := get_tree().get_first_node_in_group("map_screen")
	if m != null and m.has_method("toggle"):
		m.toggle()


func _draw_group(group: String, color: Color, ppos: Vector3, center: Vector2, radius: float) -> void:
	for node in get_tree().get_nodes_in_group(group):
		if not (node is Node3D):
			continue
		var p := (node as Node3D).global_position
		if p.distance_to(ppos) > RADIUS_M:
			continue
		_view.draw_circle(_proj(p, ppos, center), radius, color)


func _proj(world: Vector3, ppos: Vector3, center: Vector2) -> Vector2:
	var d := Vector2(world.x - ppos.x, world.z - ppos.z) * SCALE
	# ojo: en el mundo +Z es "sur"; en pantalla +Y es abajo, asi que se mantiene.
	return center + d
