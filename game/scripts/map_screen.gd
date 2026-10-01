extends CanvasLayer
## Mapa a pantalla completa (tecla M en PC; clic/tap en el minimapa en movil).
## Dibuja todas las calles del distrito y los marcadores (mision, clientes,
## policia, trafico, vehiculos propios y jugador).

var _view: Control
var _panel: Control
var _open: bool = false
var _scale: float = 1.0
var _origin: Vector2 = Vector2.ZERO
var _min: Vector2 = Vector2.ZERO
var _max: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 30
	add_to_group("map_screen")
	_build()
	close()


func _build() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.07, 0.94)
	_panel.add_child(bg)

	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_map)
	_panel.add_child(_view)

	var title := Label.new()
	title.text = "MAPA - " + GameState.district_name
	title.add_theme_font_size_override("font_size", 22)
	title.position = Vector2(24, 16)
	_panel.add_child(title)

	var hint := Label.new()
	hint.text = "M / ESC o X para cerrar"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hint.position = Vector2(24, 46)
	_panel.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -64
	close_btn.offset_top = 14
	close_btn.offset_right = -18
	close_btn.offset_bottom = 54
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	_panel.add_child(close_btn)


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	_open = true
	_panel.visible = true
	_recompute()
	_view.queue_redraw()


func close() -> void:
	_open = false
	_panel.visible = false


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_M:
			toggle()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_ESCAPE and _open:
			close()
			get_viewport().set_input_as_handled()


func _recompute() -> void:
	if not RoadGraph.loaded or RoadGraph.pts.is_empty():
		return
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in RoadGraph.pts:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	_min = mn
	_max = mx
	var vsize := get_viewport().get_visible_rect().size
	var margin := 60.0
	var w := maxf(mx.x - mn.x, 1.0)
	var h := maxf(mx.y - mn.y, 1.0)
	_scale = minf((vsize.x - margin * 2.0) / w, (vsize.y - margin * 2.0) / h)
	_origin = Vector2(
		(vsize.x - w * _scale) * 0.5,
		(vsize.y - h * _scale) * 0.5)


func _project(world: Vector3) -> Vector2:
	var bp := Vector2(world.x, -world.z)
	return Vector2(
		_origin.x + (bp.x - _min.x) * _scale,
		_origin.y + (_max.y - bp.y) * _scale)


func _draw_map() -> void:
	if not RoadGraph.loaded:
		return
	var n := RoadGraph.pts.size()
	for i in range(n):
		var a := RoadGraph.node_world(i)
		var pa := _project(a)
		for e in RoadGraph.adj[i]:
			var j: int = int(e["to"])
			if j < i:
				continue
			var pb := _project(RoadGraph.node_world(j))
			_view.draw_line(pa, pb, Color(0.8, 0.84, 0.92, 0.7), 2.0)

	# marcadores
	_marks("traffic", Color("ffd166"), 4.0)
	_marks("clients", Color("6cf0a0"), 5.0)
	_marks("police", Color("ff5a5a"), 6.0)
	_marks("vehicles", Color("66e0ff"), 6.0)
	# landmarks (sin nombres): solo marca la posicion
	for node in get_tree().get_nodes_in_group("landmarks"):
		if node is Node3D:
			var lp := _project((node as Node3D).global_position)
			_view.draw_rect(Rect2(lp - Vector2(4, 4), Vector2(8, 8)), Color("ffffff"), true)

	var tn: int = Missions.target_node()
	if tn >= 0:
		var tp := _project(RoadGraph.node_world(tn))
		_view.draw_circle(tp, 8.0, Color("ffd166"))
		_view.draw_string(ThemeDB.fallback_font, tp + Vector2(10, 4), "OBJETIVO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd166"))

	# jugador
	var player := get_tree().get_first_node_in_group("player")
	if player is Node3D:
		var pp := _project((player as Node3D).global_position)
		var dir := Vector2(0, -1)
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var f := -cam.global_transform.basis.z
			dir = Vector2(f.x, f.z).normalized()
		var right := Vector2(-dir.y, dir.x)
		_view.draw_colored_polygon(PackedVector2Array([
			pp + dir * 12.0, pp - dir * 7.0 + right * 7.0, pp - dir * 7.0 - right * 7.0
		]), Color("ffffff"))
		_view.draw_circle(pp, 14.0, Color(1, 1, 1, 0.15))


func _marks(group: String, color: Color, r: float) -> void:
	for node in get_tree().get_nodes_in_group(group):
		if node is Node3D:
			_view.draw_circle(_project((node as Node3D).global_position), r, color)
