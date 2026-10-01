extends Node
## QualityPreset (autoload "Quality"): detecta la plataforma y ajusta la calidad
## grafica (sombras, niebla, numero de NPCs/trafico). 0=bajo, 1=medio, 2=alto.

var level: int = 2
var is_mobile: bool = false
var adaptive: bool = true
var _fps_low_t: float = 0.0

const MIN_FPS := 24.0
const DOWNGRADE_AFTER := 6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	level = 0 if is_mobile else 2


func _process(delta: float) -> void:
	# Calidad adaptativa: si el motor no da ~24 fps, baja un nivel.
	if not adaptive or level <= 0:
		return
	if Engine.get_frames_per_second() < MIN_FPS:
		_fps_low_t += delta
		if _fps_low_t >= DOWNGRADE_AFTER:
			_fps_low_t = 0.0
			set_level(level - 1)
	else:
		_fps_low_t = maxf(0.0, _fps_low_t - delta)


func label() -> String:
	return ["Baja", "Media", "Alta"][clampi(level, 0, 2)]


func cycle() -> void:
	# Eleccion manual: desactiva la adaptativa.
	adaptive = false
	level = (level + 1) % 3
	_notify()


func set_level(v: int) -> void:
	level = clampi(v, 0, 2)
	_notify()


func _notify() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		apply_to(scene)


## Aplica el preset a la escena principal (o a la actual).
func apply_to(main: Node) -> void:
	if main == null:
		return
	if main.has_method("apply_quality"):
		main.apply_quality(level)
	_set_prop(main, "Traffic", "max_traffic", [4, 8, 12][level])
	_set_prop(main, "Pedestrians", "max_pedestrians", [8, 14, 20][level])


func _set_prop(main: Node, node_name: String, prop: String, value: int) -> void:
	var n := main.get_node_or_null(node_name)
	if n != null:
		n.set(prop, value)
