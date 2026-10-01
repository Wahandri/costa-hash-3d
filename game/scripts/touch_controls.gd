extends CanvasLayer
## HUD y controles tactiles (joystick + arrastre de camara + botones).
## Se construyen por codigo para que la IA pueda editarlos facilmente.

const JOY_MAX := 52.0
const JOY_SIZE := Vector2(150, 150)
const KNOB_SIZE := Vector2(62, 62)

var _joy_base: Panel
var _joy_knob: Panel
var _look_hint: Label
var _money_label: Label
var _wanted_label: Label
var _info_label: Label
var _inv_label: Label
var _fps_label: Label
var _toast: Label
var _toast_timer: float = 0.0
var _buttons: Array[Control] = []
var _stamina_fill: ColorRect
var _health_fill: ColorRect
var _player: Node = null
const STAMINA_W := 180.0

var _joy_touch := -1
var _look_touch := -1
var _joy_origin := Vector2.ZERO
var _look_last := Vector2.ZERO


func _ready() -> void:
	layer = 10
	_build_hud()
	_build_joystick()
	_build_buttons()
	GameState.money_changed.connect(_on_money_changed)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.xp_changed.connect(_on_xp_changed)
	Wanted.level_changed.connect(_on_wanted_changed)
	GameState.notification.connect(show_message)
	_on_money_changed(GameState.money)
	_on_inventory_changed(GameState.posturas)
	_on_xp_changed(GameState.xp, GameState.rank())
	_on_wanted_changed(Wanted.level)
	_info_label.text = GameState.district_name
	_player = get_tree().get_first_node_in_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS


# --------------------------------------------------------------------------
# Construccion de UI
# --------------------------------------------------------------------------

func _build_hud() -> void:
	var top := Panel.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 46
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _bar_style(Color(0.05, 0.06, 0.1, 0.72)))
	add_child(top)

	_money_label = _label(top, "0 EUR", 16, Color("e8c86a"))
	_money_label.position = Vector2(14, 10)

	_info_label = _label(top, GameState.district_name, 15, Color("cfd6e6"))
	_info_label.position = Vector2(180, 11)

	_wanted_label = _label(top, "", 16, Color("ff7a7a"))
	_wanted_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wanted_label.offset_left = -200
	_wanted_label.offset_top = 10

	_inv_label = _label(self, "Posturas: 0  |  Rango 1", 14, Color("a9e6a0"))
	_inv_label.position = Vector2(14, 50)

	# Barra de vida.
	var hbg := Panel.new()
	hbg.position = Vector2(14, 70)
	hbg.size = Vector2(STAMINA_W, 9)
	hbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbg.add_theme_stylebox_override("panel", _bar_style(Color(0, 0, 0, 0.45)))
	add_child(hbg)
	_health_fill = ColorRect.new()
	_health_fill.position = Vector2.ZERO
	_health_fill.size = Vector2(STAMINA_W, 9)
	_health_fill.color = Color("ff5a5a")
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbg.add_child(_health_fill)

	# Barra de estamina (correr).
	var bg := Panel.new()
	bg.position = Vector2(14, 83)
	bg.size = Vector2(STAMINA_W, 6)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", _bar_style(Color(0, 0, 0, 0.45)))
	add_child(bg)
	_stamina_fill = ColorRect.new()
	_stamina_fill.position = Vector2.ZERO
	_stamina_fill.size = Vector2(STAMINA_W, 6)
	_stamina_fill.color = Color("8ad6ff")
	_stamina_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_stamina_fill)

	_look_hint = _label(self, "Arrastra = camara  |  WASD = moverte  |  E = accion  |  M = mapa  |  P = movil", 13, Color(1, 1, 1, 0.55))
	_look_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_look_hint.offset_left = -260
	_look_hint.offset_bottom = -70
	_look_hint.offset_top = -94

	_fps_label = _label(self, "", 12, Color(1, 1, 1, 0.5))
	_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_label.offset_left = 10
	_fps_label.offset_top = -26

	_toast = _label(self, "", 17, Color("ffd166"))
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -320
	_toast.offset_right = 320
	_toast.offset_top = 200
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false


func _build_joystick() -> void:
	_joy_base = Panel.new()
	_joy_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joy_base.offset_left = 28
	_joy_base.offset_top = -178
	_joy_base.offset_right = 28 + JOY_SIZE.x
	_joy_base.offset_bottom = -178 + JOY_SIZE.y
	_joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_theme_stylebox_override("panel", _circle_style(Color(1, 1, 1, 0.12)))
	add_child(_joy_base)

	_joy_knob = Panel.new()
	_joy_knob.custom_minimum_size = KNOB_SIZE
	_joy_knob.size = KNOB_SIZE
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_knob.add_theme_stylebox_override("panel", _circle_style(Color(0.9, 0.75, 0.35, 0.65)))
	_joy_base.add_child(_joy_knob)
	_center_knob()


func _build_buttons() -> void:
	var run := _button("RUN", Vector2(-206, -132), Vector2(92, 92))
	run.button_down.connect(func() -> void: Controls.touch_run = true)
	run.button_up.connect(func() -> void: Controls.touch_run = false)

	var jump := _button("SALTAR", Vector2(-108, -132), Vector2(92, 92))
	jump.button_down.connect(func() -> void: Controls.touch_jump = true)
	jump.button_up.connect(func() -> void: Controls.touch_jump = false)

	var act := _button("ACCION", Vector2(-118, -244), Vector2(104, 104))
	act.button_down.connect(func() -> void: Controls.touch_action = true)
	act.button_up.connect(func() -> void: Controls.touch_action = false)

	var phone := _button("MOVIL", Vector2(-92, -70), Vector2(86, 50))
	phone.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	phone.offset_left = -96
	phone.offset_top = 58
	phone.offset_right = -10
	phone.offset_bottom = 108
	phone.pressed.connect(_toggle_phone)


func _toggle_phone() -> void:
	var phone_ui := get_tree().get_first_node_in_group("phone_ui")
	if phone_ui != null and phone_ui.has_method("toggle"):
		phone_ui.toggle()


func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(text: String, offset: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 14)
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = offset.x
	b.offset_top = offset.y
	b.offset_right = offset.x + sz.x
	b.offset_bottom = offset.y + sz.y
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	_buttons.append(b)
	return b


func _circle_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(200)
	return s


func _bar_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	return s


func _center_knob() -> void:
	_joy_knob.position = (JOY_SIZE - KNOB_SIZE) * 0.5


# --------------------------------------------------------------------------
# Entrada tactil (multitouch manual)
# --------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _handle_touch(ev: InputEventScreenTouch) -> void:
	var pos := ev.position
	if ev.pressed:
		if _in_button(pos):
			return  # deja que el Button reciba el toque
		# El minimapa gestiona sus propios toques (abrir mapa).
		var mm := get_tree().get_first_node_in_group("minimap")
		if mm != null and mm.has_method("is_in_radar") and mm.is_in_radar(pos):
			return
		if _joy_base.get_global_rect().grow(30.0).has_point(pos) and _joy_touch == -1:
			_joy_touch = ev.index
			_joy_origin = _joy_base.get_global_rect().get_center()
			_update_joystick(pos)
			get_viewport().set_input_as_handled()
		elif _look_touch == -1:
			_look_touch = ev.index
			_look_last = pos
			get_viewport().set_input_as_handled()
	else:
		if ev.index == _joy_touch:
			_joy_touch = -1
			Controls.touch_move = Vector2.ZERO
			_center_knob()
		elif ev.index == _look_touch:
			_look_touch = -1


func _handle_drag(ev: InputEventScreenDrag) -> void:
	if ev.index == _joy_touch:
		_update_joystick(ev.position)
	elif ev.index == _look_touch:
		var delta := ev.position - _look_last
		_look_last = ev.position
		Controls.add_look_delta(delta * 2.0)


func _update_joystick(pos: Vector2) -> void:
	var v := pos - _joy_origin
	if v.length() > JOY_MAX:
		v = v.normalized() * JOY_MAX
	Controls.touch_move = v / JOY_MAX
	_joy_knob.position = (JOY_SIZE - KNOB_SIZE) * 0.5 + v


func _in_button(pos: Vector2) -> bool:
	for b in _buttons:
		if (b as Control).get_global_rect().has_point(pos):
			return true
	return false


# --------------------------------------------------------------------------
# HUD
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	_fps_label.text = "%d fps" % Engine.get_frames_per_second()
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast.visible = false
	# Estamina.
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player != null and _stamina_fill != null:
		_stamina_fill.size.x = STAMINA_W * clampf(float(_player.stamina) / 100.0, 0.0, 1.0)
	if _health_fill != null and Health != null:
		_health_fill.size.x = STAMINA_W * clampf(Health.value / 100.0, 0.0, 1.0)
	# Hora y dia en el HUD.
	if _info_label != null and Clock != null:
		var h := int(Clock.time_of_day)
		var m := int(fmod(Clock.time_of_day, 1.0) * 60.0)
		_info_label.text = "%s  ·  Dia %d  %02d:%02d" % [GameState.district_name, Clock.day, h, m]


func show_message(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_timer = 3.5


func _on_money_changed(value: int) -> void:
	_money_label.text = "%s EUR" % _thousands(value)


func _on_inventory_changed(posturas: int) -> void:
	_refresh_inv()


func _on_xp_changed(_xp: int, _rank: int) -> void:
	_refresh_inv()


func _refresh_inv() -> void:
	if _inv_label == null:
		return
	var r := GameState.rank()
	_inv_label.text = "Posturas: %d  |  Rango %d %s  |  Dinero: %s EUR" % [
		GameState.posturas, r, Economy.rank_name(r), _thousands(GameState.money)]


func _on_wanted_changed(level: int) -> void:
	_wanted_label.text = "" if level <= 0 else "BUSCADO " + "*".repeat(level)


func _thousands(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if v < 0 else "") + out
