extends Node
## Entrada unificada: teclado, raton, mando y tactil. Autoload.

var move: Vector2 = Vector2.ZERO          ## -1..1 (x=derecha, y=delante es -1)
var look_axis: Vector2 = Vector2.ZERO     ## stick derecho / teclas (continuo)
var look_delta: Vector2 = Vector2.ZERO    ## raton / arrastre tactil (pixeles)
var run: bool = false
var action_pressed: bool = false
var action_just_pressed: bool = false
var jump_pressed: bool = false
var jump_just_pressed: bool = false

# Valores escritos por los controles tactiles (touch_controls.gd)
var touch_move: Vector2 = Vector2.ZERO
var touch_run: bool = false
var touch_action: bool = false
var touch_jump: bool = false
var touch_crime: bool = false

var mouse_captured: bool = false
var nav_active: bool = false           ## autopiloto (bots/LLM)
var nav_target: Vector3 = Vector3.ZERO

var _prev_action: bool = false
var _prev_jump: bool = false
var _prev_touch_action: bool = false
var _prev_touch_jump: bool = false
var _prev_touch_crime: bool = false
var _action_buffer: bool = false
var _jump_buffer: bool = false
var _crime_buffer: bool = false


func _ready() -> void:
	_register_actions()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _register_actions() -> void:
	_add("move_forward", ["w", "up"], [JOY_AXIS_LEFT_Y, -1.0], [JOY_BUTTON_DPAD_UP])
	_add("move_back", ["s", "down"], [JOY_AXIS_LEFT_Y, 1.0], [JOY_BUTTON_DPAD_DOWN])
	_add("move_left", ["a", "left"], [JOY_AXIS_LEFT_X, -1.0], [JOY_BUTTON_DPAD_LEFT])
	_add("move_right", ["d", "right"], [JOY_AXIS_LEFT_X, 1.0], [JOY_BUTTON_DPAD_RIGHT])
	_add("run", ["shift"], [], [])
	_add("jump", ["space"], [], [JOY_BUTTON_A])
	_add("action", ["e", "enter"], [], [JOY_BUTTON_X])
	_add("interact", ["f"], [], [JOY_BUTTON_Y])
	_add("crime", ["r"], [], [])


func _add(action: String, keys: Array, axis: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = _key_from_string(k)
		InputMap.action_add_event(action, ev)
	if axis.size() == 2:
		var am := InputEventJoypadMotion.new()
		am.axis = int(axis[0])
		am.axis_value = float(axis[1])
		InputMap.action_add_event(action, am)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = int(b)
		InputMap.action_add_event(action, jb)


func _key_from_string(k: String) -> Key:
	match k:
		"w": return KEY_W
		"a": return KEY_A
		"s": return KEY_S
		"d": return KEY_D
		"up": return KEY_UP
		"down": return KEY_DOWN
		"left": return KEY_LEFT
		"right": return KEY_RIGHT
		"space": return KEY_SPACE
		"shift": return KEY_SHIFT
		"e": return KEY_E
		"f": return KEY_F
		"r": return KEY_R
		"enter": return KEY_ENTER
		_: return KEY_NONE


func _process(_delta: float) -> void:
	var kb := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	move = (kb + touch_move).limit_length(1.0)

	var jx := _deadzone(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X))
	var jy := _deadzone(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	look_axis = Vector2(jx, jy)

	run = Input.is_action_pressed("run") or touch_run

	var a := Input.is_action_pressed("action") or touch_action
	action_just_pressed = a and not _prev_action
	action_pressed = a
	_prev_action = a
	# Los botones tactiles no generan InputEvent de accion: aqui detectamos su flanco.
	if touch_action and not _prev_touch_action:
		_action_buffer = true
	_prev_touch_action = touch_action

	var j := Input.is_action_pressed("jump") or touch_jump
	jump_just_pressed = j and not _prev_jump
	jump_pressed = j
	_prev_jump = j
	if touch_jump and not _prev_touch_jump:
		_jump_buffer = true
	_prev_touch_jump = touch_jump

	if touch_crime and not _prev_touch_crime:
		_crime_buffer = true
	_prev_touch_crime = touch_crime


func consume_action() -> bool:
	var b := _action_buffer
	_action_buffer = false
	return b


func press_action() -> void:
	_action_buffer = true


func press_jump() -> void:
	_jump_buffer = true


func consume_crime() -> bool:
	var b := _crime_buffer
	_crime_buffer = false
	return b


func press_crime() -> void:
	_crime_buffer = true


func consume_jump() -> bool:
	var b := _jump_buffer
	_jump_buffer = false
	return b


func _input(event: InputEvent) -> void:
	# Buffer de eventos: no se pierde una pulsacion corta aunque el frame sea lento.
	if event.is_action_pressed("action"):
		_action_buffer = true
	elif event.is_action_pressed("jump"):
		_jump_buffer = true
	elif event.is_action_pressed("crime"):
		_crime_buffer = true
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := event as InputEventKey
		if k.keycode == KEY_N:
			# Salto rapido de hora (utilidad/pruebas): +6 h.
			if Clock != null:
				Clock.time_of_day = fmod(Clock.time_of_day + 6.0, 24.0)


func add_look_delta(v: Vector2) -> void:
	look_delta += v


func consume_look_delta() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d


func _deadzone(v: float) -> float:
	return 0.0 if absf(v) < 0.16 else v


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mouse_captured:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			mouse_captured = true
	elif event is InputEventMouseMotion and mouse_captured:
		look_delta += (event as InputEventMouseMotion).relative
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and k.keycode == KEY_ESCAPE and mouse_captured:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			mouse_captured = false
