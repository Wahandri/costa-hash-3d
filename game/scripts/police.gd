extends Node
## Gestiona la policia segun el nivel de busqueda (estrellas).
## Crea coches de policia que persiguen al jugador por el grafo de calles.

const PoliceCarScript := preload("res://game/scripts/police_car.gd")

const ARREST_RANGE := 9.0
const ARREST_TIME := 1.2
const ROUTE_REFRESH := 0.6
const SPAWN_COOLDOWN := 1.6
const BOUNTY_LOSS := 0.2
const SIGHT_RANGE := 70.0
const SEARCH_TIME := 14.0
const ROADBLOCK_LEVEL := 4
const ROADBLOCK_INTERVAL := 9.0
const ROADBLOCK_MAX := 2

var _cars: Array = []
var _player: Node3D
var _spawn_point := Vector3.ZERO
var _spawn_cd := 0.0
var _route_cd := 0.0
var _arrest_timer := 0.0
var _rng := RandomNumberGenerator.new()

## Fases (referencia OpenRW Chase / re3 Wanted): pursuit -> search -> escape.
var phase: String = "none"
var _last_seen := Vector3.ZERO
var _search_t := 0.0
var _roadblock_cd := 0.0
var _roadblocks: Array = []


func _ready() -> void:
	_rng.seed = 20260928
	add_to_group("police_manager")
	_player = get_tree().get_first_node_in_group("player")
	var wb := get_tree().get_first_node_in_group("world_builder")
	if wb != null and wb.has_method("get_spawn_point"):
		_spawn_point = wb.get_spawn_point()
	Wanted.level_changed.connect(_on_level_changed)
	_on_level_changed(Wanted.level)


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	_spawn_cd = maxf(0.0, _spawn_cd - delta)
	_route_cd -= delta

	if Controls.consume_crime():
		_commit_crime()

	_sync_count()
	_prune_roadblocks()

	if not _cars.is_empty():
		_update_phase(delta)
		var tgt := _last_seen if phase == "search" else _player.global_position
		for c in _cars:
			c.target = tgt
		if _route_cd <= 0.0:
			_route_cd = ROUTE_REFRESH
			_assign_routes(tgt)
		_check_arrest(delta)
		_maybe_roadblock(delta)
	else:
		phase = "none"

	Wanted.set_chasing(not _cars.is_empty())


func _update_phase(delta: float) -> void:
	var closest := INF
	if _player != null:
		for c in _cars:
			closest = minf(closest, c.global_position.distance_to(_player.global_position))
		# Si aun no hay "ultima posicion conocida", usa la actual (evita que
		# la policia se vaya al origen (0,0,0) en la fase de busqueda).
		if _last_seen == Vector3.ZERO:
			_last_seen = _player.global_position
	if closest <= SIGHT_RANGE:
		phase = "pursuit"
		_last_seen = _player.global_position
		_search_t = 0.0
	elif phase != "search":
		phase = "search"
		_search_t = 0.0
	else:
		_search_t += delta
		if _search_t >= SEARCH_TIME:
			_escape()


func _escape() -> void:
	_clear_police()
	Wanted.clear()
	GameState.set_wanted(0)
	GameState.notify("Te has librado: la policia pierde tu rastro")


func _commit_crime() -> void:
	Wanted.add_heat(24.0)
	GameState.notify("Trapicheo en la calle: la policia te busca")


func _on_level_changed(level: int) -> void:
	if level <= 0:
		_clear_police()


func _sync_count() -> void:
	var want := Wanted.level
	while _cars.size() > want:
		_remove_car(_cars.pop_back())
	if _cars.size() < want and _spawn_cd <= 0.0 and _player != null:
		_spawn_car()
		_spawn_cd = SPAWN_COOLDOWN


func _spawn_car() -> void:
	var pos := _pick_spawn_position()
	if pos == Vector3.ZERO:
		return
	var car := PoliceCarScript.new()
	get_parent().add_child(car)
	car.global_position = pos + Vector3(0, 1.2, 0)
	_cars.append(car)


func _pick_spawn_position() -> Vector3:
	if not RoadGraph.loaded or _player == null:
		return Vector3.ZERO
	var player_pos := _player.global_position
	var candidates: Array[Vector3] = []
	for i in range(RoadGraph.pts.size()):
		var p := RoadGraph.node_world(i)
		var d := p.distance_to(player_pos)
		if d >= 60.0 and d <= 200.0:
			candidates.append(p)
	if candidates.is_empty():
		return RoadGraph.node_world(RoadGraph.nearest_node(player_pos))
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _assign_routes(target: Vector3) -> void:
	if not RoadGraph.loaded:
		return
	var pnode := RoadGraph.nearest_node(target)
	for c in _cars:
		var cnode := RoadGraph.nearest_node(c.global_position)
		c.route = RoadGraph.find_path(cnode, pnode)
		c.route_i = 0


# --------------------------------------------------------------------------
# Barricadas (refuerzos a nivel alto)
# --------------------------------------------------------------------------

func _maybe_roadblock(delta: float) -> void:
	_roadblock_cd = maxf(0.0, _roadblock_cd - delta)
	if Wanted.level < ROADBLOCK_LEVEL or _roadblock_cd > 0.0:
		return
	if _roadblocks.size() >= ROADBLOCK_MAX or _player == null or not RoadGraph.loaded:
		return
	_roadblock_cd = ROADBLOCK_INTERVAL
	_spawn_roadblock()


func _spawn_roadblock() -> void:
	# Busca un nodo de calle por delante del jugador y bloquealo.
	var fwd := -_player.global_transform.basis.z if _player is Node3D else Vector3.FORWARD
	var best := -1
	var best_score := -INF
	for i in range(RoadGraph.pts.size()):
		var p := RoadGraph.node_world(i)
		var to := p - _player.global_position
		to.y = 0.0
		var d := to.length()
		if d < 45.0 or d > 130.0:
			continue
		var align := to.normalized().dot(fwd)
		if align < 0.4:
			continue
		var score := align * 100.0 - absf(d - 80.0)
		if score > best_score:
			best_score = score
			best = i
	if best < 0:
		return
	var pos := RoadGraph.node_world(best)
	var body := StaticBody3D.new()
	body.name = "Roadblock"
	body.collision_layer = 4
	body.collision_mask = 0
	var model := Assets.prop("barrier")
	if model != null:
		body.add_child(model)
		model.position = Vector3(0, -Assets.min_y(model), 0)
		var sz := Assets.size_of(model)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(sz.x, sz.y, sz.z)
		cs.shape = box
		cs.position = Vector3(0, sz.y * 0.5, 0)
		body.add_child(cs)
	get_parent().add_child(body)
	body.global_position = pos
	body.rotation.y = atan2(fwd.x, fwd.z) + PI * 0.5
	_roadblocks.append(body)
	GameState.notify("Barricada policial en la via!")


func _prune_roadblocks() -> void:
	for i in range(_roadblocks.size() - 1, -1, -1):
		var b = _roadblocks[i]
		if not is_instance_valid(b):
			_roadblocks.remove_at(i)
			continue
		if _player != null and (b as Node3D).global_position.distance_to(_player.global_position) > 260.0:
			b.queue_free()
			_roadblocks.remove_at(i)


func _check_arrest(delta: float) -> void:
	var close := false
	for c in _cars:
		if c.global_position.distance_to(_player.global_position) < ARREST_RANGE:
			close = true
			break
	if close:
		_arrest_timer += delta
		if _arrest_timer >= ARREST_TIME:
			_arrest()
	else:
		_arrest_timer = maxf(0.0, _arrest_timer - delta * 2.0)


func _arrest() -> void:
	_arrest_timer = 0.0
	var lost := int(round(float(GameState.money) * BOUNTY_LOSS))
	if lost > 0:
		GameState.add_money(-lost)
	if _player != null:
		if _player.has_method("force_exit"):
			_player.force_exit()
		_player.global_position = _spawn_point + Vector3(0, 2.0, 0)
	Wanted.clear()
	GameState.set_wanted(0)
	_clear_police()
	GameState.notify("Te han trincado. Multa: %d EUR" % lost)


func _clear_police() -> void:
	for c in _cars:
		_remove_car(c)
	_cars.clear()
	for b in _roadblocks:
		if is_instance_valid(b):
			b.queue_free()
	_roadblocks.clear()
	phase = "none"


func _remove_car(c: Node) -> void:
	if is_instance_valid(c):
		c.queue_free()
