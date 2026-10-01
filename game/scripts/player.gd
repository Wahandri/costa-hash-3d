extends CharacterBody3D
## Jugador en tercera persona. Construye cuerpo y camara por codigo.
## Puede entrar en un vehiculo propio (grupo "vehicles") con el boton ACCION.

@export var walk_speed := 4.5
@export var run_speed := 8.5
@export var jump_velocity := 6.0
@export var look_sensitivity := 0.0028
@export var gamepad_look_speed := 2.2
@export var vehicle_reach := 5.0

const GRAVITY := 22.0
const PITCH_MIN := -1.15
const PITCH_MAX := 0.55
const STAMINA_DRAIN := 26.0
const STAMINA_REGEN := 18.0

var yaw: float = 0.0
var pitch: float = -0.15
var stamina: float = 100.0

var _pivot: Node3D
var _spring: SpringArm3D
var _camera: Camera3D
var _model: Node3D
var _shape: CollisionShape3D
var _vehicle: Node = null
var _hazard_cd: float = 0.0
var _air_max_y: float = 0.0
var _was_floor: bool = true


func _ready() -> void:
	add_to_group("player")
	_build_body()
	_build_camera()
	_place_at_spawn()
	GameState.wanted = Wanted.level


const PLAYER_HEIGHT := 1.68
const MODEL_YAW_OFFSET := 0.0  ## ajuste si el modelo mira al reves

func _build_body() -> void:
	var node := Assets.character("mini", "male", 0)
	if node != null:
		add_child(node)
		Assets.fit_height(node, PLAYER_HEIGHT)
		node.position = Vector3(0, -Assets.min_y(node), 0)
		Assets.enable_locomotion(node)
		_model = node
	else:
		# Fallback: capsula si no hay assets
		var cap := CapsuleMesh.new()
		cap.radius = 0.3
		cap.height = 1.55
		var mesh := MeshInstance3D.new()
		mesh.mesh = cap
		mesh.position = Vector3(0, 0.78, 0)
		add_child(mesh)
		_model = mesh

	var cs := CapsuleShape3D.new()
	cs.radius = 0.3
	cs.height = 1.55
	_shape = CollisionShape3D.new()
	_shape.shape = cs
	_shape.position = Vector3(0, 0.78, 0)
	add_child(_shape)

	# Capas: 1=suelo, 2=jugador, 4=edificios, 8=vehiculos, 16=NPCs
	collision_layer = 2
	collision_mask = 1 | 4 | 8


func _update_anim(moving: bool, sprinting: bool, _speed: float) -> void:
	if _model == null:
		return
	var t := 0.0
	if moving:
		t = 1.0 if sprinting else 0.5
	Assets.set_locomotion(_model, t)


func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 1.5, 0)
	add_child(_pivot)

	_spring = SpringArm3D.new()
	_spring.spring_length = 5.0
	_spring.margin = 0.25
	_spring.collision_mask = 1 | 4 | 8
	_pivot.add_child(_spring)
	_spring.add_excluded_object(get_rid())

	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.far = 5000.0
	_camera.current = true
	_spring.add_child(_camera)


func _place_at_spawn() -> void:
	var wb := get_tree().get_first_node_in_group("world_builder")
	if wb != null and wb.has_method("get_spawn_point"):
		global_position = wb.get_spawn_point() + Vector3(0, 1.0, 0)
	else:
		global_position = Vector3(0, 1.5, 0)


func is_driving() -> bool:
	return _vehicle != null


func force_exit() -> void:
	if _vehicle != null:
		_do_exit()


func _physics_process(delta: float) -> void:
	if _vehicle != null:
		_follow_and_maybe_exit()
		return
	_update_look(delta)
	_update_movement(delta)
	_handle_action()


# --------------------------------------------------------------------------
# A pie
# --------------------------------------------------------------------------

func _update_look(delta: float) -> void:
	var ld := Controls.consume_look_delta()
	yaw -= ld.x * look_sensitivity
	pitch -= ld.y * look_sensitivity

	var la := Controls.look_axis
	yaw -= la.x * gamepad_look_speed * delta
	pitch -= la.y * gamepad_look_speed * delta

	pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
	_pivot.rotation = Vector3(pitch, yaw, 0.0)


func _update_movement(delta: float) -> void:
	var input := Controls.move
	var basis := Basis(Vector3.UP, yaw)
	var dir := Vector3.ZERO
	if Controls.nav_active:
		var to := Controls.nav_target - global_position
		to.y = 0.0
		if to.length() > 1.2:
			dir = to.normalized()
		else:
			Controls.nav_active = false
	elif input.length() > 0.05:
		dir = (basis * Vector3(input.x, 0.0, input.y)).normalized()

	var moving := dir.length() > 0.05
	var sprinting := Controls.run and moving and stamina > 1.0
	var speed := run_speed if sprinting else walk_speed

	if sprinting:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
	else:
		stamina = minf(100.0, stamina + STAMINA_REGEN * delta)

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Controls.consume_jump():
		velocity.y = jump_velocity
	else:
		velocity.y = 0.0

	move_and_slide()

	_check_fall()
	_check_hazards(delta)

	if moving and is_on_floor():
		Audio.play_footstep(delta)

	_update_anim(moving, sprinting, speed)

	if moving and _model != null:
		var target := atan2(dir.x, dir.z) + MODEL_YAW_OFFSET
		_model.rotation.y = lerp_angle(_model.rotation.y, target, 0.2)


## Daño por caida (si el jugador cae desde mas de 4 m).
func _check_fall() -> void:
	if is_on_floor():
		if not _was_floor:
			var fall := _air_max_y - global_position.y
			if fall > 5.0:
				Health.damage((fall - 5.0) * 10.0, "caida")
		_air_max_y = global_position.y
		_was_floor = true
	else:
		_air_max_y = maxf(_air_max_y, global_position.y)
		_was_floor = false


## Daño por atropello: cualquier vehiculo rapido cerca del jugador a pie.
func _check_hazards(delta: float) -> void:
	_hazard_cd = maxf(0.0, _hazard_cd - delta)
	if Health.value <= 0.0:
		return
	for group in ["traffic", "police", "vehicles"]:
		for v in get_tree().get_nodes_in_group(group):
			if not (v is Node3D):
				continue
			var vp := (v as Node3D).global_position
			if global_position.distance_to(vp) > 2.8:
				continue
			# Solo cuenta la velocidad HORIZONTAL (evita daño si un coche cae).
			var spd := 0.0
			if v is VehicleBody3D:
				var lv := (v as VehicleBody3D).linear_velocity
				spd = Vector2(lv.x, lv.z).length()
			elif v is CharacterBody3D:
				var cv := (v as CharacterBody3D).velocity
				spd = Vector2(cv.x, cv.z).length()
			if spd > 6.0 and _hazard_cd <= 0.0:
				_hazard_cd = 1.0
				Health.damage(8.0 + (spd - 6.0) * 3.0, "atropello")
				var push := global_position - vp
				push.y = 0.0
				if push.length() > 0.01:
					velocity += push.normalized() * 3.0
				break


func _handle_action() -> void:
	if not Controls.consume_action():
		return
	# 1) Vender a un cliente cercano
	var cm := get_tree().get_first_node_in_group("clients_manager")
	if cm != null and cm.has_method("nearest_within"):
		var client = cm.nearest_within(3.6)
		if client != null:
			_sell_to(client)
			return
	# 2) Entrar en un vehiculo cercano
	var v := _nearest_vehicle()
	if v != null:
		_do_enter(v)


func _sell_to(client) -> void:
	var res: Dictionary = Economy.sell_to(client.qty_max(), client.risk_factor())
	if bool(res.get("ok", false)):
		GameState.notify("Vendidas %d a %s (+%d EUR)" % [int(res.qty), client.dealer_name(), int(res.earned)])
		client.leave()


func _nearest_vehicle() -> Node:
	var best: Node = null
	var best_d := vehicle_reach * vehicle_reach
	for v in get_tree().get_nodes_in_group("vehicles"):
		if not (v is Node3D):
			continue
		var d := global_position.distance_squared_to((v as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = v
	return best


func has_vehicle_nearby() -> bool:
	return _vehicle != null or _nearest_vehicle() != null


# --------------------------------------------------------------------------
# Conduciendo
# --------------------------------------------------------------------------

func _do_enter(v: Node) -> void:
	_vehicle = v
	if v.has_method("enter"):
		v.enter(self)
	Audio.engine_start(v as Node3D)
	_mount_rider(v)
	visible = false
	_shape.disabled = true
	velocity = Vector3.ZERO


## Sienta al personaje sobre el vehiculo con su animacion (subir a la moto/coche).
func _mount_rider(v: Node) -> void:
	if _model == null:
		return
	if _model.get_parent() != null:
		_model.get_parent().remove_child(_model)
	v.add_child(_model)
	var t := Transform3D()
	if v.has_method("seat_transform"):
		t = v.seat_transform()
	_model.transform = t
	var anim := "sit"
	if v.has_method("rider_anim"):
		anim = str(v.rider_anim())
	Assets.set_locomotion_active(_model, false)
	Assets.play_anim(_model, [anim, "sit", "drive", "idle"], true, 0.15)


func _unmount_rider() -> void:
	if _model == null:
		return
	if _model.get_parent() != self:
		if _model.get_parent() != null:
			_model.get_parent().remove_child(_model)
		add_child(_model)
	_model.position = Vector3(0, -Assets.min_y(_model), 0)
	_model.rotation = Vector3.ZERO


func _follow_and_maybe_exit() -> void:
	var v := _vehicle as Node3D
	if v == null:
		return
	# el jugador viaja oculto dentro del vehiculo
	global_position = v.global_position

	if Controls.consume_action():
		_do_exit()


func _do_exit() -> void:
	var v := _vehicle as Node3D
	if v != null:
		if _vehicle.has_method("exit"):
			_vehicle.exit()
		var side := v.global_transform.basis.x.normalized() * 1.8
		global_position = v.global_position + side + Vector3(0, 1.0, 0)
	_vehicle = null
	Audio.engine_stop()
	_unmount_rider()
	visible = true
	_shape.disabled = false
	_camera.current = true
	velocity = Vector3.ZERO


func get_camera() -> Camera3D:
	return _camera
