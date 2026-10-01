extends Node3D
## Resplandor emisivo (farolas) que se enciende de noche. Barato: un MultiMesh
## con material emisivo que se activa/desactiva segun el reloj.

var _mat: StandardMaterial3D
var _mmi: MultiMeshInstance3D


func build(transforms: Array, height: float, radius: float, color: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		mm.set_instance_transform(i, Transform3D(Basis(), t.origin + Vector3(0, height, 0)))
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = mm
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 0.0
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mmi.material_override = _mat
	add_child(_mmi)


func _ready() -> void:
	Clock.night_changed.connect(set_night)
	set_night(Clock.is_night())


func set_night(on: bool) -> void:
	if _mat != null:
		_mat.emission_energy_multiplier = 3.0 if on else 0.0
