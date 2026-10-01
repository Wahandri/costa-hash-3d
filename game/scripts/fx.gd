extends Node
## FX (autoload "Fx"): efectos one-shot baratos (humo de derrape, chispas).
## Usa CPUParticles3D para ser compatible con WebGL2 (Compatibility).

var _smoke_mesh: SphereMesh
var _spark_mesh: SphereMesh


func _ready() -> void:
	_smoke_mesh = SphereMesh.new()
	_smoke_mesh.radius = 0.22
	_smoke_mesh.height = 0.44
	_spark_mesh = SphereMesh.new()
	_spark_mesh.radius = 0.06
	_spark_mesh.height = 0.12


func smoke(pos: Vector3, amount: int = 8) -> void:
	_puff(pos, amount, Color(0.82, 0.82, 0.82, 0.55), Vector3.UP, 2.2, 0.9, _smoke_mesh, 1.4)


func sparks(pos: Vector3, amount: int = 12) -> void:
	_puff(pos, amount, Color(1.0, 0.75, 0.2, 0.9), Vector3.UP, 5.0, 0.45, _spark_mesh, 0.6)


func _puff(pos: Vector3, amount: int, color: Color, dir: Vector3, vel: float, life: float, mesh: Mesh, scale_max: float) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = 55.0
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.gravity = Vector3(0, -3.0, 0) if color.a < 0.7 else Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = scale_max
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = false
	p.material_override = mat
	var scene := get_tree().current_scene
	if scene == null:
		p.free()
		return
	scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)
