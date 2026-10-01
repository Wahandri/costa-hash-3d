extends CharacterBody3D
## Coche de trafico (IA cinematica). Circula por el grafo de calles y desaparezca
## lejos del jugador (lo gestiona traffic.gd). Usa modelos de Assets.

const SPEED := 9.0
const ACCEL := 22.0
const GRAVITY := 24.0
const ARRIVE := 6.0
const MODEL_YAW_OFFSET := PI  ## el morro del modelo mira a -Z

const MODELS := ["sedan", "hatchback_sports", "suv", "van", "taxi", "truck", "delivery", "luxury", "sedan_sports"]
const CarLights := preload("res://game/scripts/car_lights.gd")

var route: PackedInt32Array = PackedInt32Array()
var route_i: int = 0
var dest_node: int = -1

var _speed: float = 0.0
var _stuck_t: float = 0.0
var _model: Node3D
var _lights: Dictionary = {}


func _ready() -> void:
	add_to_group("traffic")
	collision_layer = 8
	collision_mask = 1 | 4 | 8 | 2
	var key: String = MODELS[randi() % MODELS.size()]
	var body_size := Vector3(1.8, 1.3, 4.4)
	_model = Assets.vehicle(key)
	if _model != null:
		add_child(_model)
		_model.scale = Vector3.ONE
		Assets.fit_length(_model, 4.4)
		body_size = Assets.size_of(_model)
		_model.position = Vector3(0, -Assets.min_y(_model), 0)
		_model.rotation.y = PI  ## modelo Kenney mira a +Z; aqui -Z es el avance
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = body_size
		cs.shape = box
		cs.position = Vector3(0, body_size.y * 0.5, 0)
		add_child(cs)
		Assets.tint(_model, Color.from_hsv(randf(), 0.5, 0.9), 0.35)
	else:
		var cs2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = body_size
		cs2.shape = b2
		cs2.position = Vector3(0, 0.65, 0)
		add_child(cs2)
	_lights = CarLights.attach(self, body_size, false)
	Clock.night_changed.connect(func(on: bool) -> void: CarLights.set_night(_lights, on))
	CarLights.set_night(_lights, Clock.is_night())


func retarget(_from_pos: Vector3) -> void:
	if not RoadGraph.loaded:
		return
	var start := RoadGraph.nearest_node(global_position)
	var best := start
	var best_d := 0.0
	for _k in range(12):
		var cand := randi() % RoadGraph.pts.size()
		var d := RoadGraph.pts[cand].distance_to(RoadGraph.pts[start])
		if d > best_d and d < 320.0:
			best_d = d
			best = cand
	dest_node = best
	route = RoadGraph.find_path(start, dest_node)
	route_i = 0


func _physics_process(delta: float) -> void:
	var tgt := _current_target()
	var to := tgt - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.5 else Vector3.ZERO

	var want := SPEED
	if dist < ARRIVE:
		want = SPEED * clampf(dist / ARRIVE, 0.0, 1.0)
	if dir.length() > 0.05 and _red_light_ahead(dir):
		want = 0.0
	if _car_ahead(dir):
		want = minf(want, 2.0)
	_speed = move_toward(_speed, want, ACCEL * delta)

	velocity.x = dir.x * _speed
	velocity.z = dir.z * _speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var before := global_position
	move_and_slide()
	_unstick(before, delta)

	if dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z) + MODEL_YAW_OFFSET, clampf(delta * 5.0, 0.0, 1.0))


func _red_light_ahead(dir: Vector3) -> bool:
	for tl in get_tree().get_nodes_in_group("traffic_lights"):
		if not (tl is Node3D) or not bool(tl.is_red):
			continue
		var to := (tl as Node3D).global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > 0.6 and d < 9.0 and to.normalized().dot(dir) > 0.35:
			return true
	return false


func _car_ahead(dir: Vector3) -> bool:
	for other in get_tree().get_nodes_in_group("traffic"):
		if other == self or not (other is Node3D):
			continue
		var to := (other as Node3D).global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > 0.8 and d < 7.0 and to.normalized().dot(dir) > 0.7:
			return true
	return false


func _current_target() -> Vector3:
	while route.size() > 0 and route_i < route.size():
		var p := RoadGraph.node_world(route[route_i])
		if global_position.distance_to(p) < 7.0:
			route_i += 1
			continue
		return p
	# Ruta terminada: elige otro destino.
	retarget(global_position)
	if route.size() > 0:
		return RoadGraph.node_world(route[route_i])
	return global_position - global_transform.basis.z


func _unstick(before: Vector3, delta: float) -> void:
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if moved < 0.03:
		_stuck_t += delta
		if _stuck_t > 1.5:
			_stuck_t = 0.0
			retarget(global_position)
	else:
		_stuck_t = 0.0
