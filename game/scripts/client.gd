extends CharacterBody3D
## Cliente NPC: pasea por las calles y compra posturas al jugador.

const SPEED := 1.7
const GRAVITY := 24.0
const ARRIVE := 1.5
const SIDEWALK_OFFSET := 3.8

var _side: float = 1.0
var _gesture_t: float = 0.0

var dealer: Dictionary = {}
var purchased: bool = false

var _target: Vector3 = Vector3.ZERO
var _idle: float = 0.0
var _leaving: bool = false
var _leave_t: float = 0.0
var _model: Node3D
var _stuck_t: float = 0.0
var _marker: MeshInstance3D
var _marker_t: float = 0.0

const MODEL_YAW_OFFSET := 0.0


func setup(d: Dictionary) -> void:
	dealer = d


func _ready() -> void:
	add_to_group("clients")
	collision_layer = 16
	collision_mask = 1 | 4 | 8  # suelo + edificios + vehiculos
	_side = 1.0 if randf() < 0.5 else -1.0
	_build()
	_pick_target()
	_snap_to_sidewalk()


func _build() -> void:
	var node := Npc.character("buyer")
	if node != null:
		add_child(node)
		Npc.apply(node)
		Assets.enable_locomotion(node)
		_model = node
	else:
		var cap := CapsuleMesh.new()
		cap.radius = 0.3
		cap.height = 1.6
		var mesh := MeshInstance3D.new()
		mesh.mesh = cap
		mesh.position = Vector3(0, 0.8, 0)
		add_child(mesh)
		_model = mesh

	var shape := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.28
	cs.height = 1.5
	shape.shape = cs
	shape.position = Vector3(0, 0.75, 0)
	add_child(shape)

	_build_marker()


## Marca flotante (dorada) que identifica a quien SI compra.
func _build_marker() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.54
	_marker = MeshInstance3D.new()
	_marker.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffe066")
	mat.emission_enabled = true
	mat.emission = Color("ffb300")
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = mat
	_marker.position = Vector3(0, 2.05, 0)
	add_child(_marker)


func _process(delta: float) -> void:
	if _marker == null or _leaving:
		return
	_marker_t += delta
	_marker.position.y = 2.05 + sin(_marker_t * 3.0) * 0.12
	_marker.rotate_y(delta * 1.8)


func qty_max() -> int:
	return int(dealer.get("qty", 1))


func risk_factor() -> float:
	return float(dealer.get("risk", 1.0))


func dealer_name() -> String:
	return str(dealer.get("name", "Cliente"))


func _physics_process(delta: float) -> void:
	_gesture_t = maxf(0.0, _gesture_t - delta)
	if _leaving:
		_leave_t -= delta
		if _leave_t <= 0.0:
			queue_free()
			return
	if _idle > 0.0:
		_idle -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		_set_anim("idle")
	else:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < ARRIVE:
			_idle = randf_range(1.0, 3.0)
			_pick_target()
		else:
			var dir := to.normalized()
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
			_set_anim("walk")
			if _model != null:
				_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z) + MODEL_YAW_OFFSET, 0.15)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var before := global_position
	move_and_slide()
	_detect_stuck(before, delta)


func _detect_stuck(before: Vector3, delta: float) -> void:
	# Si quiere moverse pero apenas avanza (bloqueado por un edificio), cambia de destino.
	if _idle > 0.0 or _leaving:
		_stuck_t = 0.0
		return
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if moved < 0.02:
		_stuck_t += delta
		if _stuck_t > 1.5:
			_stuck_t = 0.0
			_pick_target()
	else:
		_stuck_t = 0.0


func _set_anim(state: String) -> void:
	if _model == null or _gesture_t > 0.0:
		return
	Assets.set_locomotion(_model, 0.5 if state == "walk" else 0.0)


func _pick_target() -> void:
	if not RoadGraph.loaded:
		_target = global_position
		return
	var base := Vector3.ZERO
	var candidates: Array[Vector3] = []
	for i in range(RoadGraph.pts.size()):
		var p := RoadGraph.node_world(i)
		if p.distance_to(global_position) < 45.0:
			candidates.append(p)
	if candidates.is_empty():
		base = RoadGraph.node_world(RoadGraph.nearest_node(global_position))
	else:
		base = candidates[randi_range(0, candidates.size() - 1)]
	_target = _sidewalk(base)


## Desplaza un punto del eje de la calle hacia la acera (lateral, lado fijo).
func _sidewalk(base: Vector3) -> Vector3:
	var to := base - global_position
	to.y = 0.0
	if to.length() < 0.5:
		return base
	var dir := to.normalized()
	var perp := Vector3(-dir.z, 0.0, dir.x)
	return base + perp * (SIDEWALK_OFFSET * _side)


func _snap_to_sidewalk() -> void:
	var off := _target - global_position
	off.y = 0.0
	if off.length() < 0.5:
		return
	var dir := off.normalized()
	var perp := Vector3(-dir.z, 0.0, dir.x)
	global_position += perp * (SIDEWALK_OFFSET * _side)
	_target += perp * (SIDEWALK_OFFSET * _side)


func leave() -> void:
	# El cliente se marcha tras comprar y desaparece al cabo de unos segundos.
	purchased = true
	_leaving = true
	_leave_t = 4.0
	# Gestito de "coger el producto" al recibir la compra.
	if _model != null:
		_gesture_t = 1.2
		Assets.set_locomotion_active(_model, false)
		Assets.play_anim(_model, ["holding-right", "interact-right", "walk"], false, 0.15)
	_pick_target()
