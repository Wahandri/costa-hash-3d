extends Node
## Gestiona los clientes NPC alrededor del jugador.

const ClientScript := preload("res://game/scripts/client.gd")

const MAX_CLIENTS := 6
const SPAWN_MIN := 22.0
const SPAWN_MAX := 90.0
const DESPAWN_DIST := 220.0
const SPAWN_COOLDOWN := 1.2

var _clients: Array = []
var _player: Node3D
var _cd := 0.0


func _ready() -> void:
	add_to_group("clients_manager")
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	_cd = maxf(0.0, _cd - delta)
	_prune()
	if _clients.size() < MAX_CLIENTS and _cd <= 0.0:
		_spawn()
		_cd = SPAWN_COOLDOWN


func _prune() -> void:
	for i in range(_clients.size() - 1, -1, -1):
		var c = _clients[i]
		if not is_instance_valid(c):
			_clients.remove_at(i)
			continue
		if (c as Node3D).global_position.distance_to(_player.global_position) > DESPAWN_DIST:
			c.queue_free()
			_clients.remove_at(i)


func _spawn() -> void:
	if not RoadGraph.loaded or Economy.dealers.is_empty():
		return
	var candidates: Array[Vector3] = []
	for i in range(RoadGraph.pts.size()):
		var p := RoadGraph.node_world(i)
		var d := p.distance_to(_player.global_position)
		if d >= SPAWN_MIN and d <= SPAWN_MAX:
			candidates.append(p)
	if candidates.is_empty():
		return
	var pos: Vector3 = candidates[randi_range(0, candidates.size() - 1)]
	var dealer: Dictionary = Economy.dealers[randi_range(0, Economy.dealers.size() - 1)]
	var c := ClientScript.new()
	c.setup(dealer)
	get_parent().add_child(c)
	c.global_position = pos + Vector3(0, 1.0, 0)
	_clients.append(c)


func nearest_within(range_m: float) -> Node3D:
	var best: Node3D = null
	var best_d := range_m * range_m
	for c in _clients:
		if not is_instance_valid(c):
			continue
		var d := (c as Node3D).global_position.distance_squared_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best
