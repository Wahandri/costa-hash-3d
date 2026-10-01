extends Node3D
## Semaforo funcional: alterna rojo/verde y avisa al trafico. Referencia: gta2_re TrafficLights.

const CYCLE := 9.0

var is_red: bool = true
var _t: float = 0.0
var _offset: float = 0.0
var _lamp: MeshInstance3D
var _red_mat: StandardMaterial3D
var _green_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("traffic_lights")
	_offset = randf() * CYCLE
	var model := Assets.prop("traffic_light")
	var top := 3.6
	if model != null:
		add_child(model)
		model.position = Vector3(0, -Assets.min_y(model), 0)
		top = Assets.height_of(model)
	_build_lamp(top)
	_t = _offset


func _build_lamp(top: float) -> void:
	_red_mat = _emissive(Color("ff2d2d"))
	_green_mat = _emissive(Color("2dff6b"))
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	_lamp = MeshInstance3D.new()
	_lamp.mesh = mesh
	_lamp.material_override = _red_mat
	_lamp.position = Vector3(0, top + 0.1, 0.12)
	add_child(_lamp)


func _emissive(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _process(delta: float) -> void:
	_t += delta
	var phase := fmod(_t, CYCLE)
	is_red = phase < CYCLE * 0.5
	if _lamp != null:
		_lamp.material_override = _red_mat if is_red else _green_mat
