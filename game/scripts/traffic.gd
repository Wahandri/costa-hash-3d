extends Node
## Gestiona el trafico rodado alrededor del jugador (coches por el grafo de calles).

const TrafficCarScript := preload("res://game/scripts/traffic_car.gd")

const SPAWN_MIN := 60.0
const SPAWN_MAX := 200.0
const DESPAWN_DIST := 300.0
const SPAWN_COOLDOWN := 0.5
const RETARGET_EVERY := 2.0

var max_traffic: int = 12
var _cars: Array = []
var _player: Node3D
var _cd := 0.0
var _retarget_cd := 0.0


func _ready() -> void:
	add_to_group("traffic_manager")
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	_cd = maxf(0.0, _cd - delta)
	_prune()
	var budget := max_traffic if not Clock.is_night() else int(max_traffic * 0.45)
	if _cars.size() < budget and _cd <= 0.0:
		_spawn()
		_cd = SPAWN_COOLDOWN

	_retarget_cd -= delta
	if _retarget_cd <= 0.0:
		_retarget_cd = RETARGET_EVERY
		for c in _cars:
			if is_instance_valid(c) and (c.route.size() == 0 or c.route_i >= c.route.size()):
				c.retarget(_player.global_position)


func _prune() -> void:
	for i in range(_cars.size() - 1, -1, -1):
		var c = _cars[i]
		if not is_instance_valid(c):
			_cars.remove_at(i)
			continue
		if (c as Node3D).global_position.distance_to(_player.global_position) > DESPAWN_DIST:
			c.queue_free()
			_cars.remove_at(i)


func _spawn() -> void:
	if not RoadGraph.loaded:
		return
	var candidates: Array[Vector3] = []
	for i in range(RoadGraph.pts.size()):
		var p := RoadGraph.node_world(i)
		var d := p.distance_to(_player.global_position)
		if d >= SPAWN_MIN and d <= SPAWN_MAX:
			candidates.append(p)
	if candidates.is_empty():
		return
	var pos: Vector3 = candidates[randi() % candidates.size()]
	var car := TrafficCarScript.new()
	get_parent().add_child(car)
	car.global_position = pos + Vector3(0, 0.6, 0)
	car.retarget(pos)
	_cars.append(car)
