extends VehicleBody3D
## Vehiculo conducible (jugador o IA). Usa modelos de Assets (Kenney Car Kit).
## Tipos: car / sport / van / truck / luxury / taxi / police ...

const CarLights := preload("res://game/scripts/car_lights.gd")

@export var vtype := "car"
@export var color_override := Color(0, 0, 0, 0)

var driven: bool = false
var ai_active: bool = false
var _driver: Node = null
var _cfg: Dictionary = {}
var _model: Node3D = null
var _model_yaw: float = 0.0

var _cam_pivot: Node3D
var _cam_arm: SpringArm3D
var _camera: Camera3D
var _wheels: Array[VehicleWheel3D] = []
var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.08
var _cam_recenter: float = 99.0
var _fx_cd: float = 0.0
var _prev_speed: float = 0.0
var _lights: Dictionary = {}
var _is_moto: bool = false

const LOOK_SENS := 0.0050
const PAD_LOOK_SPEED := 2.6
const PITCH_MIN := -0.95
const PITCH_MAX := 0.45


func _ready() -> void:
	add_to_group("vehicles")
	_cfg = type_config(vtype)
	_is_moto = str(_cfg.get("model", "")) == "moto"
	mass = _cfg.mass
	# Capas: 1=suelo, 2=jugador, 4=edificios, 8=vehiculos, 16=NPCs
	collision_layer = 8
	collision_mask = 1 | 4 | 8 | 2
	# Amortiguacion: asienta antes y evita derrapes raros.
	angular_damp = 1.0
	linear_damp = 0.12
	# ANTI-VUELCO DEFINITIVO: bloquea el balanceo (roll) y el cabeceo (pitch) en
	# ejes del mundo. El vehiculo solo puede girar en Y (rumbo): nunca vuelca.
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	_build_body()
	_build_camera()


static func type_config(t: String) -> Dictionary:
	# length = longitud objetivo (metros). wheel_r = radio rueda. wheel_xf/zf = fracciones.
	match t:
		"moto":
			return {
				"mass": 220.0, "engine": 780.0, "boost": 1150.0, "steer": 0.5,
				"length": 2.2, "wheel_r": 0.34, "wheel_xf": 1.3, "wheel_zf": 0.78,
				"model": "moto", "cam_len": 5.2, "color": Color("7c2419"),
			}
		"sport":
			return {
				"mass": 1000.0, "engine": 1150.0, "boost": 1900.0, "steer": 0.5,
				"length": 4.0, "wheel_r": 0.32, "wheel_xf": 0.47, "wheel_zf": 0.63,
				"model": "hatchback_sports", "cam_len": 6.8, "color": Color("e67e22"),
			}
		"van":
			return {
				"mass": 2200.0, "engine": 1000.0, "boost": 1600.0, "steer": 0.34,
				"length": 5.1, "wheel_r": 0.4, "wheel_xf": 0.46, "wheel_zf": 0.62,
				"model": "van", "cam_len": 8.5, "color": Color("ecf0f1"),
			}
		"truck":
			return {
				"mass": 3200.0, "engine": 900.0, "boost": 1400.0, "steer": 0.3,
				"length": 6.4, "wheel_r": 0.48, "wheel_xf": 0.45, "wheel_zf": 0.6,
				"model": "truck", "cam_len": 9.5, "color": Color("95a5a6"),
			}
		"luxury":
			return {
				"mass": 1500.0, "engine": 1050.0, "boost": 1750.0, "steer": 0.44,
				"length": 4.6, "wheel_r": 0.36, "wheel_xf": 0.47, "wheel_zf": 0.62,
				"model": "suv_luxury", "cam_len": 7.6, "color": Color("2c3e50"),
			}
		"taxi":
			return {
				"mass": 1250.0, "engine": 900.0, "boost": 1500.0, "steer": 0.45,
				"length": 4.4, "wheel_r": 0.34, "wheel_xf": 0.47, "wheel_zf": 0.62,
				"model": "taxi", "cam_len": 7.5, "color": Color("f1c40f"),
			}
		"police":
			return {
				"mass": 1350.0, "engine": 1150.0, "boost": 1850.0, "steer": 0.47,
				"length": 4.6, "wheel_r": 0.35, "wheel_xf": 0.47, "wheel_zf": 0.62,
				"model": "police", "cam_len": 7.8, "color": Color("16324f"),
			}
		_:
			return {
				"mass": 1250.0, "engine": 950.0, "boost": 1550.0, "steer": 0.45,
				"length": 4.4, "wheel_r": 0.34, "wheel_xf": 0.47, "wheel_zf": 0.63,
				"model": "sedan", "cam_len": 7.5, "color": Color("c0392b"),
			}


# --------------------------------------------------------------------------
# Construccion
# --------------------------------------------------------------------------

func _build_body() -> void:
	var is_moto: bool = str(_cfg.get("model", "")) == "moto"
	_model = Assets.motorcycle() if is_moto else Assets.vehicle(str(_cfg.get("model", "sedan")))

	var size := Vector3(1.8, 1.3, 4.4)
	if _model != null:
		add_child(_model)
		_model.scale = Vector3.ONE
		Assets.fit_length(_model, float(_cfg.length))
		size = Assets.size_of(_model)
		_model.position = Vector3(0, -Assets.min_y(_model), 0)
		# Los modelos Kenney miran a +Z; el vehiculo avanza a -Z -> giro 180.
		# La moto es procedural y ya mira a -Z (sin giro).
		_model.rotation.y = 0.0 if is_moto else PI
		if not is_moto:
			if color_override.a > 0.0:
				Assets.tint(_model, color_override, 0.75)
			else:
				Assets.tint(_model, _cfg.color, 0.28)

	# Colision (caja ajustada al modelo, algo mas baja para no engancharse).
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x * 0.96, size.y * 0.8, size.z * 0.98)
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	add_child(shape)

	# Centro de masa BAJO: evita que el vehiculo vuelque al girar (clave en arcade).
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, size.y * (0.08 if _is_moto else 0.16), 0)

	# Luces (se encienden de noche).
	_lights = CarLights.attach(self, size, true)
	Clock.night_changed.connect(func(on: bool) -> void: CarLights.set_night(_lights, on))
	CarLights.set_night(_lights, Clock.is_night())

	# Ruedas fisicas (sin malla: el modelo ya trae las suyas). Se alinean al modelo.
	var wheel_r := float(_cfg.wheel_r)
	var hx := size.x * 0.5 * float(_cfg.wheel_xf)
	var hz := size.z * 0.5 * float(_cfg.wheel_zf)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_make_wheel(Vector3(sx * hx, wheel_r, sz * hz), sz < 0.0, true, wheel_r)


func _make_wheel(pos: Vector3, steer: bool, drive: bool, radius: float) -> void:
	var w := VehicleWheel3D.new()
	w.position = pos
	w.use_as_steering = steer
	w.use_as_traction = drive
	# Valores tipo demo oficial de Godot: rest_length CORTO (si es largo, el
	# coche rebota y vuelca). Estas son las claves de la estabilidad.
	w.wheel_radius = radius
	w.wheel_rest_length = 0.15
	w.wheel_friction_slip = 4.0
	w.suspension_stiffness = 32.0
	w.suspension_travel = 0.2
	w.suspension_max_force = mass * 25.0
	w.damping_compression = 0.85
	w.damping_relaxation = 0.95
	add_child(w)
	_wheels.append(w)


func _build_camera() -> void:
	_cam_pivot = Node3D.new()
	_cam_pivot.position = Vector3(0, 1.7, 0)
	add_child(_cam_pivot)

	_cam_arm = SpringArm3D.new()
	_cam_arm.spring_length = float(_cfg.cam_len)
	_cam_arm.margin = 0.35
	_cam_arm.collision_mask = 1 | 4 | 8
	_cam_pivot.add_child(_cam_arm)
	_cam_arm.add_excluded_object(get_rid())

	_camera = Camera3D.new()
	_camera.fov = 72.0
	_camera.far = 5000.0
	_camera.current = false
	_cam_arm.add_child(_camera)


func enter(by: Node) -> void:
	driven = true
	_driver = by
	_camera.current = true
	_cam_yaw = 0.0
	_cam_pitch = -0.08
	_cam_recenter = 99.0


func exit() -> void:
	driven = false
	_driver = null
	_camera.current = false
	engine_force = 0.0
	brake = 12.0
	steering = 0.0


func is_active() -> bool:
	return driven or ai_active


func _drive_input() -> Vector2:
	if not driven:
		return Vector2.ZERO
	# OJO: engine_force positivo empuja el vehiculo hacia +Z, pero el morro del
	# modelo y la camara estan a -Z -> se invierte el acelerador para que W avance.
	var mv := Controls.move
	return Vector2(mv.x, mv.y)


func _wants_boost() -> bool:
	return driven and Controls.run


func _physics_process(delta: float) -> void:
	if not is_active():
		engine_force = 0.0
		brake = 12.0
		steering = lerp(steering, 0.0, delta * 4.0)
		_stabilize(delta)  # que no se quede volcado al aparcar
		return

	var speed := linear_velocity.length()
	var inp := _drive_input()

	# Direccion progresiva: menos giro a mas velocidad (evita trompos/vuelcos).
	var steer_max := float(_cfg.steer) * clampf(1.0 - speed / 42.0, 0.32, 1.0)
	steering = lerp(steering, clampf(inp.x, -1.0, 1.0) * steer_max, delta * 6.0)

	var handbrake := driven and Controls.jump_pressed
	if absf(inp.y) > 0.05 and not handbrake:
		engine_force = inp.y * (float(_cfg.boost) if _wants_boost() else float(_cfg.engine))
		brake = 0.0
	else:
		engine_force = 0.0
		brake = 22.0 if handbrake else 6.0
	_set_rear_grip(1.1 if handbrake else 3.4)

	_stabilize(delta)
	if angular_velocity.length() > 2.6:
		angular_velocity = angular_velocity.normalized() * 2.6

	if driven:
		_update_camera_control(delta)

	_update_fx(delta, speed)
	Audio.engine_update(speed)


func _update_fx(delta: float, speed: float) -> void:
	_fx_cd = maxf(0.0, _fx_cd - delta)
	# Chispas + golpe al chocar fuerte.
	if _prev_speed - speed > 5.0 and _fx_cd <= 0.0:
		Fx.sparks(global_position + Vector3(0, 0.6, 0))
		Audio.play_impact()
		_fx_cd = 0.35
	_prev_speed = speed
	# Humo al derrapar.
	if speed > 6.0 and _fx_cd <= 0.0:
		for w in _wheels:
			if w.is_in_contact() and w.get_skidinfo() < 0.55:
				Fx.smoke(w.get_contact_point())
				_fx_cd = 0.12
				break


func _set_rear_grip(v: float) -> void:
	for w in _wheels:
		if w.use_as_traction and not w.use_as_steering:
			w.wheel_friction_slip = v


func _stabilize(delta: float) -> void:
	# Anti-vuelco arcade: par que endereza + amortiguacion del balanceo (roll).
	# Mantiene coches y, sobre todo, la moto, sin volcar a cada curva.
	var up := global_transform.basis.y
	var d := clampf(up.dot(Vector3.UP), -1.0, 1.0)
	var axis := up.cross(Vector3.UP)
	if axis.length() > 0.0001:
		var ang := acos(d)
		var k := 60.0 if _is_moto else 38.0
		apply_torque(axis.normalized() * (mass * ang * k))
	# Amortigua el giro de balanceo (impide volcar al girar o al pisar un bordillo).
	var roll_axis := global_transform.basis.z
	var roll_v := angular_velocity.dot(roll_axis)
	angular_velocity -= roll_axis * roll_v * clampf(delta * 5.0, 0.0, 1.0)
	if _is_moto:
		# La moto tambien amortigua cabeceo (evita caballitos/vuelcos).
		var pitch_axis := global_transform.basis.x
		var pitch_v := angular_velocity.dot(pitch_axis)
		angular_velocity -= pitch_axis * pitch_v * clampf(delta * 3.0, 0.0, 1.0)
	# Seguridad: si aun asi queda muy inclinado y casi parado, lo endereza de golpe.
	if d < 0.3 and linear_velocity.length() < 1.5:
		var yaw := global_transform.basis.get_euler().y
		global_transform.basis = Basis(Vector3.UP, yaw)
		angular_velocity = Vector3.ZERO


func _update_camera_control(delta: float) -> void:
	var ld := Controls.consume_look_delta()
	var la := Controls.look_axis
	_cam_yaw -= ld.x * LOOK_SENS
	_cam_pitch -= ld.y * LOOK_SENS
	_cam_yaw -= la.x * PAD_LOOK_SPEED * delta
	_cam_pitch -= la.y * PAD_LOOK_SPEED * delta
	_cam_pitch = clampf(_cam_pitch, PITCH_MIN, PITCH_MAX)

	var active := absf(ld.x) + absf(ld.y) + la.length()
	if active > 0.05:
		_cam_recenter = 0.0
	else:
		_cam_recenter += delta
		if _cam_recenter > 1.0 and linear_velocity.length() > 3.0:
			_cam_yaw = lerp_angle(_cam_yaw, 0.0, delta * 2.5)

	_cam_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


func get_camera() -> Camera3D:
	return _camera


func get_model() -> Node3D:
	return _model


## Posicion del jinete sobre el vehiculo. El personaje Kenney mira a +Z, asi que
## se gira 180 (PI) para mirar en la misma direccion que el vehiculo (-Z).
func seat_transform() -> Transform3D:
	var yaw := Basis(Vector3.UP, PI)
	if _is_moto:
		return Transform3D(yaw, Vector3(0.0, 0.62, 0.22))
	return Transform3D(yaw, Vector3(0.32, 0.55, 0.02))


## Animacion del jinete: "sit" en moto, "drive" en coches.
func rider_anim() -> String:
	return "sit" if _is_moto else "drive"


func wheel_debug() -> Array:
	var out: Array = []
	for w in _wheels:
		out.append({
			"contact": w.is_in_contact(),
			"pt": w.get_contact_point(),
			"normal": w.get_contact_normal(),
			"skid": w.get_skidinfo(),
		})
	return out
