extends CanvasLayer
## Menu "MOVIL": producto, comprar placa, mejoras y progreso. Táctil.

var _panel: Panel
var _list: VBoxContainer
var _open: bool = false
var _districts: Array = []


func _ready() -> void:
	layer = 20
	add_to_group("phone_ui")
	_load_districts()
	_build()
	close()


func _load_districts() -> void:
	var txt := FileAccess.get_file_as_string("res://game/data/districts.json")
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		var d: Dictionary = parsed
		_districts = d.get("districts", [])


func _call_mechanic() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("deliver_vehicle"):
		main.deliver_vehicle(GameState.garage_vehicle())


func _apply_vehicle(id: String) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("replace_player_vehicle"):
		var vtype := str(Economy.vehicle_by_id(id).get("type", "car"))
		main.replace_player_vehicle(vtype)


func _travel(slug: String, name: String) -> void:
	GameState.district_slug = slug
	GameState.district_name = name
	GameState.save_game(false)
	close()
	get_tree().reload_current_scene()


func _build() -> void:
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -270
	_panel.offset_right = 270
	_panel.offset_top = -300
	_panel.offset_bottom = 300
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.12, 0.96)
	style.set_corner_radius_all(14)
	style.border_color = Color(0.3, 0.35, 0.5)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var title := Label.new()
	title.text = "MOVIL"
	title.add_theme_font_size_override("font_size", 22)
	title.position = Vector2(20, 14)
	_panel.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(470, 12)
	close_btn.size = Vector2(48, 40)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	_panel.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 60)
	scroll.size = Vector2(506, 520)
	_panel.add_child(scroll)

	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(480, 0)
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_P:
			toggle()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_ESCAPE and _open:
			close()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	_open = true
	_panel.visible = true
	_rebuild()


func close() -> void:
	_open = false
	_panel.visible = false


func _add_label(text: String, size: int = 15, color: Color = Color("cfd6e6")) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_list.add_child(l)


func _add_button(text: String, enabled: bool, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 15)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.pressed.connect(func() -> void: Audio.play_click())
	b.pressed.connect(cb)
	_list.add_child(b)


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()

	_add_label("Rango %d - %s" % [GameState.rank(), Economy.rank_name(GameState.rank())], 18, Color("ffd166"))
	_add_label("XP %d  |  Respeto %.0f  |  Dinero %d EUR" % [GameState.xp, GameState.respeto, GameState.money])
	_add_label("Posturas: %d  |  Producto: %s" % [GameState.posturas, str(Economy.current_product().get("name", "-"))])
	var qauto := " (auto)" if Quality.adaptive else ""
	_add_button("Calidad grafica: %s%s (toca para cambiar)" % [Quality.label(), qauto], true, func() -> void:
		Quality.cycle()
		_rebuild())
	_list.add_child(HSeparator.new())

	_add_label("PRODUCTO", 16, Color("9fd0ff"))
	for p in Economy.products:
		var pid := str(p.get("id", ""))
		var unlocked := GameState.rank() >= int(p.get("rank", 1))
		var inuse := "  [EN USO]" if pid == GameState.product_id else ""
		var label := "%s  (vende %d / compra %d)%s" % [str(p.get("name", pid)), Economy.sell_price_for(pid), int(p.get("buy", 0)), inuse]
		if not unlocked:
			label += "  [rango %d]" % int(p.get("rank", 1))
		var id_copy := pid
		_add_button(label, unlocked, func() -> void:
			Economy.set_product(id_copy)
			_rebuild())
	_list.add_child(HSeparator.new())

	_add_label("SUMINISTRO", 16, Color("9fd0ff"))
	var cost := Economy.placa_cost()
	_add_button("Comprar placa (%d posturas) - %d EUR" % [Economy.placa_units, cost],
		GameState.money >= cost, func() -> void:
			Economy.buy_placa()
			_rebuild())
	_list.add_child(HSeparator.new())

	_add_label("MEJORAS Y BANDA", 16, Color("9fd0ff"))
	for u in Economy.upgrades:
		var uid := str(u.get("id", ""))
		if Economy.has_upgrade(uid):
			_add_label("%s - COMPRADA" % str(u.get("name", uid)), 14, Color("7bd88f"))
			continue
		var unlocked := GameState.rank() >= int(u.get("rank", 1))
		var ucost := int(u.get("cost", 0))
		var text := "%s - %d EUR (%s)" % [str(u.get("name", uid)), ucost, str(u.get("desc", ""))]
		if not unlocked:
			text += "  [rango %d]" % int(u.get("rank", 1))
		var uid_copy := uid
		_add_button(text, unlocked and GameState.money >= ucost, func() -> void:
			Economy.buy_upgrade(uid_copy)
			_rebuild())
	_list.add_child(HSeparator.new())

	_add_label("GARAJE", 16, Color("9fd0ff"))
	for v in Economy.vehicles:
		var vid := str(v.get("id", ""))
		var vname := str(v.get("name", vid))
		var vcost := int(v.get("cost", 0))
		var vrank := int(v.get("rank", 1))
		if GameState.owns_vehicle(vid):
			if GameState.garage_vehicle() == vid:
				_add_label("%s - EN USO" % vname, 14, Color("7bd88f"))
			else:
				var vid_use := vid
				_add_button("Usar %s" % vname, true, func() -> void:
					Economy.buy_vehicle(vid_use)
					_apply_vehicle(vid_use)
					_rebuild())
		else:
			var locked := GameState.rank() < vrank
			var text := "Comprar %s - %d EUR" % [vname, vcost]
			if locked:
				text += "  [rango %d]" % vrank
			var vid_buy := vid
			_add_button(text, not locked and GameState.money >= vcost, func() -> void:
				if Economy.buy_vehicle(vid_buy):
					_apply_vehicle(vid_buy)
				_rebuild())
	_list.add_child(HSeparator.new())

	_add_label("MECANICO", 16, Color("9fd0ff"))
	var mcost := 40
	var gv := str(Economy.vehicle_by_id(GameState.garage_vehicle()).get("name", GameState.garage_vehicle()))
	_add_button("Llamar al mecanico (trae tu %s) - %d EUR" % [gv, mcost],
		GameState.money >= mcost, func() -> void:
			if GameState.money >= mcost:
				GameState.add_money(-mcost)
				Audio.play_confirm()
				_call_mechanic()
			else:
				Audio.play_error()
			_rebuild())
	_list.add_child(HSeparator.new())

	_add_label("VIAJAR", 16, Color("9fd0ff"))
	for dist in _districts:
		if not bool(dist.get("playable", true)):
			continue
		var dslug := str(dist.get("slug", ""))
		var dname := str(dist.get("name", dslug))
		if dslug == GameState.district_slug:
			_add_label("%s (aqui)" % dname, 14, Color("7bd88f"))
			continue
		var ds_copy := dslug
		var dn_copy := dname
		_add_button("Viajar a %s" % dname, true, func() -> void:
			_travel(ds_copy, dn_copy))
