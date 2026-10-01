extends Node
## Nivel de busqueda policial (estrellas 0-5). Autoload.

signal level_changed(level: int)

var level: int = 0
var heat: float = 0.0  ## calor acumulado 0..100 que alimenta el nivel
var chasing: bool = false  ## hay policia persiguiendo: el calor no baja

const HEAT_PER_LEVEL := 20.0
const HEAT_DECAY := 1.2  ## por segundo cuando no hay delito reciente

var _recent_crime: float = 0.0


func _process(delta: float) -> void:
	_recent_crime = maxf(0.0, _recent_crime - delta)
	if heat > 0.0 and not chasing and _recent_crime <= 0.0:
		heat = maxf(0.0, heat - HEAT_DECAY * delta)
		_refresh()


func set_chasing(value: bool) -> void:
	chasing = value


func add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, 100.0)
	_recent_crime = 6.0
	_refresh()


func set_level(value: int) -> void:
	level = clampi(value, 0, 5)
	heat = maxf(heat, float(level) * HEAT_PER_LEVEL)
	level_changed.emit(level)


func clear() -> void:
	level = 0
	heat = 0.0
	level_changed.emit(level)


func _refresh() -> void:
	var new_level := clampi(int(heat / HEAT_PER_LEVEL), 0, 5)
	if new_level != level:
		level = new_level
		level_changed.emit(level)
