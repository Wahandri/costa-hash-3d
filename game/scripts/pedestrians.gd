extends Node
## Gestiona peatones de ambiente alrededor del jugador.

const PedestrianScript := preload("res://game/scripts/pedestrian.gd")

const SPAWN_MIN := 25.0
const SPAWN_MAX := 85.0
const DESPAWN_DIST := 240.0
const SPAWN_COOLDOWN := 0.6

var max_pedestrians: int = 18
var _peds: Array = []
var _player: Node3D
var _cd := 0.0


func _ready() -> void:
	add_to_group("pedestrians_manager")
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	_cd = maxf(0.0, _cd - delta)
	_prune()
	var budget := max_pedestrians if not Clock.is_night() else int(max_pedestrians * 0.4)
	if _peds.size() < budget and _cd <= 0.0:
		_spawn()
		_cd = SPAWN_COOLDOWN


func _prune() -> void:
	for i in range(_peds.size() - 1, -1, -1):
		var c = _peds[i]
		if not is_instance_valid(c):
			_peds.remove_at(i)
			continue
		if (c as Node3D).global_position.distance_to(_player.global_position) > DESPAWN_DIST:
			c.queue_free()
			_peds.remove_at(i)


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
	var ped := PedestrianScript.new()
	get_parent().add_child(ped)
	ped.global_position = pos + Vector3(0, 1.0, 0)
	_peds.append(ped)
