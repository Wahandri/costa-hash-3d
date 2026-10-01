extends Node
## Misiones y encargos. Autoload. Datos en game/data/missions.json.

signal mission_started(mission: Dictionary)
signal mission_completed(mission: Dictionary)

var missions: Array = []
var active_index: int = -1
var active_progress: float = 0.0


func _ready() -> void:
	var txt := FileAccess.get_file_as_string("res://game/data/missions.json")
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		var d: Dictionary = parsed
		missions = d.get("missions", [])
	_restore()


## Restaura el progreso de mision guardado (o empieza por la primera).
func _restore() -> void:
	if missions.is_empty():
		return
	var data := SaveManager.load_data()
	var idx := int(data.get("mission_index", 0))
	if idx < 0 or idx >= missions.size():
		idx = 0
	active_index = idx
	active_progress = float(data.get("mission_progress", 0.0))
	mission_started.emit(active_mission())


func to_dict() -> Dictionary:
	return {
		"mission_index": active_index,
		"mission_progress": active_progress,
	}


## Nodo del grafo asociado a la mision activa (destino del GPS). -1 si no hay.
func target_node() -> int:
	if active_index < 0 or not RoadGraph.loaded or RoadGraph.pts.is_empty():
		return -1
	return (active_index * 137 + 53) % RoadGraph.pts.size()


func target_pos() -> Vector3:
	var n := target_node()
	if n < 0:
		return Vector3.ZERO
	return RoadGraph.node_world(n)


func active_mission() -> Dictionary:
	if active_index < 0 or active_index >= missions.size():
		return {}
	return missions[active_index]


func start_mission(index: int) -> void:
	if index < 0 or index >= missions.size():
		return
	active_index = index
	active_progress = 0.0
	mission_started.emit(active_mission())


func add_progress(amount: float) -> void:
	if active_index < 0:
		return
	active_progress += amount
	var m := active_mission()
	if not m.is_empty() and active_progress >= float(m.get("goal", 1.0)):
		mission_completed.emit(m)
		var current := active_index
		active_index = -1
		active_progress = 0.0
		var next := current + 1
		if next < missions.size():
			start_mission(next)
		else:
			GameState.notify("Campana completada: eres la leyenda de la Costa")
