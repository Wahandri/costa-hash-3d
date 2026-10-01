extends CharacterBody3D
## Peaton de ambiente con maquina de estados (referencia: re3 PedAI):
## WALK (pasea) / IDLE (para) / FLEE (huye de policia o del jugador buscado)
## / CHAT (se para a "charlar" cerca de otro peaton). Mismo estilo (mini) que el resto.

enum State { WALK, IDLE, FLEE, CHAT }

const RUN_SPEED := 5.0
const GRAVITY := 24.0
const ARRIVE := 1.5
const MODEL_YAW_OFFSET := 0.0
const THREAT_RANGE := 22.0
const SIDEWALK_OFFSET := 3.8  ## m desde el eje de la calle hasta la acera

var _side: float = 1.0
var _walk_speed: float = 1.45
var _emote_t: float = 0.0

var _state: int = State.WALK
var _target: Vector3 = Vector3.ZERO
var _timer: float = 0.0
var _think: float = 0.0
var _flee_from: Vector3 = Vector3.ZERO
var _model: Node3D
var _stuck_t: float = 0.0


func _ready() -> void:
	add_to_group("pedestrians")
	collision_layer = 16
	collision_mask = 1 | 4 | 8
	_side = 1.0 if randf() < 0.5 else -1.0
	_build()
	_pick_target()
	_snap_to_sidewalk()
	_state = State.WALK


func _build() -> void:
	var role := _pick_role()
	_walk_speed = Npc.walk_speed(role)
	_model = Npc.character(role)
	if _model == null:
		return
	add_child(_model)
	Npc.apply(_model)
	Assets.enable_locomotion(_model)


func _pick_role() -> String:
	var r := randf()
	if r < 0.12:
		return "tourist"
	if r < 0.20:
		return "worker"
	if r < 0.28:
		return "kid"
	return "civil"

	var shape := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.28
	cs.height = 1.5
	shape.shape = cs
	shape.position = Vector3(0, 0.75, 0)
	add_child(shape)


func _physics_process(delta: float) -> void:
	_think -= delta
	if _think <= 0.0:
		_think = 0.4
		_evaluate_threat()
	_update_state(delta)
	_move(delta)


# --------------------------------------------------------------------------
# IA
# --------------------------------------------------------------------------

func _evaluate_threat() -> void:
	if _state == State.FLEE and _timer > 0.0:
		return
	var danger := Vector3.ZERO
	var found := false
	for p in get_tree().get_nodes_in_group("police"):
		if p is Node3D:
			var d := (p as Node3D).global_position - global_position
			if d.length() < THREAT_RANGE:
				danger = d
				found = true
				break
	if not found and Wanted.level >= 2:
		var player := get_tree().get_first_node_in_group("player")
		if player is Node3D:
			var d := (player as Node3D).global_position - global_position
			if d.length() < THREAT_RANGE:
				danger = d
				found = true
	if found:
		_start_flee(-danger.normalized() if danger.length() > 0.01 else Vector3.RIGHT)


func _start_flee(dir: Vector3) -> void:
	_state = State.FLEE
	_timer = randf_range(3.0, 6.0)
	_flee_from = dir
	_pick_flee_target(dir)


func _pick_flee_target(dir: Vector3) -> void:
	var p := global_position + dir * randf_range(30.0, 60.0)
	if RoadGraph.loaded:
		_target = RoadGraph.node_world(RoadGraph.nearest_node(p))
	else:
		_target = p


func _update_state(delta: float) -> void:
	match _state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.WALK
				_pick_target()
		State.CHAT:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.WALK
				_pick_target()
		State.FLEE:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.WALK
				_pick_target()
		State.WALK:
			if global_position.distance_to(_target) < ARRIVE:
				if randf() < 0.35:
					_state = State.CHAT if _near_other_ped() else State.IDLE
					_timer = randf_range(1.2, 3.0)
					# Emote ocasional (charla/saludo) para dar vida.
					if _state == State.CHAT and _model != null:
						_emote_t = 1.6
						Assets.play_anim(_model, ["interact-right", "emote-yes", "idle"], false, 0.2)
				else:
					_pick_target()


func _near_other_ped() -> bool:
	for o in get_tree().get_nodes_in_group("pedestrians"):
		if o != self and o is Node3D:
			if (o as Node3D).global_position.distance_to(global_position) < 4.0:
				return true
	return false


# --------------------------------------------------------------------------
# Movimiento
# --------------------------------------------------------------------------

func _move(delta: float) -> void:
	var speed := RUN_SPEED if _state == State.FLEE else _walk_speed
	if _state == State.IDLE or _state == State.CHAT:
		velocity.x = 0.0
		velocity.z = 0.0
		if _emote_t > 0.0:
			_emote_t -= delta
		else:
			_set_anim("idle")
	else:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.6:
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			var dir := to.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_set_anim("sprint" if _state == State.FLEE else "walk")
			if _model != null:
				_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z) + MODEL_YAW_OFFSET, 0.18)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var before := global_position
	move_and_slide()

	if _state == State.WALK or _state == State.FLEE:
		var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
		if moved < 0.02:
			_stuck_t += delta
			if _stuck_t > 1.0:
				_stuck_t = 0.0
				_pick_target()
		else:
			_stuck_t = 0.0


func _set_anim(state: String) -> void:
	if _model == null:
		return
	var t := 0.0
	if state == "sprint":
		t = 1.0
	elif state == "walk":
		t = 0.5
	Assets.set_locomotion(_model, t)


func _pick_target() -> void:
	if not RoadGraph.loaded:
		_target = global_position
		return
	var base := Vector3.ZERO
	var candidates: Array[Vector3] = []
	for i in range(RoadGraph.pts.size()):
		var p := RoadGraph.node_world(i)
		if p.distance_to(global_position) < 40.0:
			candidates.append(p)
	if candidates.is_empty():
		base = RoadGraph.node_world(RoadGraph.nearest_node(global_position))
	else:
		base = candidates[randi() % candidates.size()]
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


## Coloca al peaton en la acera al aparecer.
func _snap_to_sidewalk() -> void:
	var off := _target - global_position
	off.y = 0.0
	if off.length() < 0.5:
		return
	var dir := off.normalized()
	var perp := Vector3(-dir.z, 0.0, dir.x)
	global_position += perp * (SIDEWALK_OFFSET * _side)
	_target += perp * (SIDEWALK_OFFSET * _side)
