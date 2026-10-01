extends CharacterBody3D
## Coche de policia (agente cinemático). Sigue el grafo de calles hacia el jugador.
## Se usa CharacterBody3D en vez de VehicleBody porque la IA de conducción debe ser
## fiable (GTA-like) y no depender de la suspensión física.

const SPEED := 16.0
const ACCEL := 34.0
const GRAVITY := 24.0

var target: Vector3 = Vector3.ZERO
var route: PackedInt32Array = PackedInt32Array()
var route_i: int = 0

const MODEL_YAW_OFFSET := PI  ## el morro del modelo mira a -Z
const LENGTH := 4.7
const CarLights := preload("res://game/scripts/car_lights.gd")

var _speed: float = 0.0
var _model: Node3D
var _lamp_l: MeshInstance3D
var _lamp_r: MeshInstance3D
var _blink: float = 0.0
var _top_y: float = 1.5
var _stuck_t: float = 0.0
var _lights: Dictionary = {}


func _ready() -> void:
	add_to_group("police")
	collision_layer = 8
	collision_mask = 1 | 4 | 8 | 2  # suelo + edificios + vehiculos + jugador
	_build_body()
	_add_lightbar()
	_add_siren()


func _add_siren() -> void:
	var s := AudioStreamPlayer3D.new()
	s.stream = Audio.siren_stream()
	s.volume_db = -6.0
	s.unit_size = 14.0
	s.max_distance = 90.0
	add_child(s)
	s.play()


func _build_body() -> void:
	var size := Vector3(1.8, 1.3, 4.4)
	_model = Assets.vehicle("police")
	if _model != null:
		add_child(_model)
		_model.scale = Vector3.ONE
		Assets.fit_length(_model, LENGTH)
		size = Assets.size_of(_model)
		_model.position = Vector3(0, -Assets.min_y(_model), 0)
		_model.rotation.y = PI  ## modelo Kenney mira a +Z; aqui -Z es el avance
		_top_y = size.y

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, size.z)
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	add_child(shape)

	_lights = CarLights.attach(self, size, true)
	Clock.night_changed.connect(func(on: bool) -> void: CarLights.set_night(_lights, on))
	CarLights.set_night(_lights, Clock.is_night())


func _add_lightbar() -> void:
	var y := _top_y + 0.06
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 0.12, 0.32)
	bar.mesh = bm
	bar.material_override = _mat(Color("111111"))
	bar.position = Vector3(0, y, 0.1)
	add_child(bar)

	_lamp_l = _make_lamp(Vector3(-0.32, y + 0.09, 0.1), Color("ff2d2d"))
	_lamp_r = _make_lamp(Vector3(0.32, y + 0.09, 0.1), Color("2d6bff"))


func _make_lamp(pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.14, 0.36)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.0
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	_blink += delta
	var on := fmod(_blink, 0.5) < 0.25
	if _lamp_l != null:
		_lamp_l.visible = on
	if _lamp_r != null:
		_lamp_r.visible = not on


func _physics_process(delta: float) -> void:
	var tgt := _current_target()
	var to := tgt - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.5 else Vector3.ZERO

	var want_speed := SPEED
	if dist < 12.0:
		want_speed = SPEED * clampf(dist / 12.0, 0.0, 1.0)
	_speed = move_toward(_speed, want_speed, ACCEL * delta)

	velocity.x = dir.x * _speed
	velocity.z = dir.z * _speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var before := global_position
	move_and_slide()
	_unstick(before, delta, dist)

	if dir.length() > 0.05:
		var yaw := atan2(dir.x, dir.z) + MODEL_YAW_OFFSET
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 5.0, 0.0, 1.0))


func _unstick(before: Vector3, delta: float, dist_to_target: float) -> void:
	# Si se queda atascado con un edificio, salta al siguiente nodo de la ruta.
	if dist_to_target < 12.0:
		_stuck_t = 0.0
		return
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if moved < 0.03:
		_stuck_t += delta
		if _stuck_t > 1.2:
			_stuck_t = 0.0
			if route_i < route.size():
				route_i += 1
	else:
		_stuck_t = 0.0


func _current_target() -> Vector3:
	if target != Vector3.ZERO:
		if route.size() == 0 or global_position.distance_to(target) < 70.0:
			return target

	while route.size() > 0 and route_i < route.size():
		var node_pos := RoadGraph.node_world(route[route_i])
		if global_position.distance_to(node_pos) < 8.0:
			route_i += 1
			continue
		return node_pos

	if target != Vector3.ZERO:
		return target
	return global_position - global_transform.basis.z


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	return m
