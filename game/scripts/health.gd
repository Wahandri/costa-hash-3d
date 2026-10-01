extends Node
## Health (autoload "Health"): salud del jugador, daño, regeneracion y hospital.
## Referencia (GTA): al quedarte sin vida despiertas en el hospital perdiendo dinero.

signal changed(value: float)
signal died()

const MAX_HEALTH := 100.0
const REGEN_DELAY := 8.0   ## segundos sin daño antes de regenerar
const REGEN_RATE := 4.0    ## vida/seg
const DEATH_LOSS := 0.15   ## % de dinero perdido al ser hospitalizado
const INVULN_TIME := 1.5

var value: float = MAX_HEALTH

var _since_damage: float = 999.0
var _invuln: float = 0.0


func _process(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	_since_damage += delta
	if value > 0.0 and value < MAX_HEALTH and _since_damage >= REGEN_DELAY:
		value = minf(MAX_HEALTH, value + REGEN_RATE * delta)
		changed.emit(value)


func reset() -> void:
	value = MAX_HEALTH
	_since_damage = 999.0
	_invuln = 0.0
	changed.emit(value)


func heal(amount: float) -> void:
	value = clampf(value + amount, 0.0, MAX_HEALTH)
	changed.emit(value)


func damage(amount: float, _cause: String = "") -> void:
	if amount <= 0.0 or _invuln > 0.0 or value <= 0.0:
		return
	value = clampf(value - amount, 0.0, MAX_HEALTH)
	_since_damage = 0.0
	changed.emit(value)
	if value <= 0.0:
		_hospitalize()


func _hospitalize() -> void:
	died.emit()
	var lost := int(round(float(GameState.money) * DEATH_LOSS))
	if lost > 0:
		GameState.add_money(-lost)

	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		if player.has_method("force_exit"):
			player.force_exit()
		if player is Node3D:
			(player as Node3D).global_position = _spawn_point() + Vector3(0, 1.0, 0)

	Wanted.clear()
	GameState.set_wanted(0)
	value = MAX_HEALTH
	_invuln = INVULN_TIME
	_since_damage = 0.0
	changed.emit(value)
	GameState.notify("Hospitalizado: -%d EUR. Recuperado." % lost)
	Audio.play_error()


func _spawn_point() -> Vector3:
	var wb := get_tree().get_first_node_in_group("world_builder")
	if wb != null and wb.has_method("get_spawn_point"):
		return wb.get_spawn_point()
	return Vector3(0, 3, 0)
