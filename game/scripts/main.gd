extends Node3D
## Escena principal: monta entorno, mundo, jugador y HUD.

const WorldBuilderScript := preload("res://game/scripts/world_builder.gd")
const PlayerScript := preload("res://game/scripts/player.gd")
const VehicleScript := preload("res://game/scripts/vehicle.gd")
const PoliceScript := preload("res://game/scripts/police.gd")
const ClientsScript := preload("res://game/scripts/clients.gd")
const PhoneUiScript := preload("res://game/scripts/phone_ui.gd")
const TouchControlsScript := preload("res://game/scripts/touch_controls.gd")
const TrafficScript := preload("res://game/scripts/traffic.gd")
const PedestriansScript := preload("res://game/scripts/pedestrians.gd")
const MinimapScript := preload("res://game/scripts/minimap.gd")
const MapScreenScript := preload("res://game/scripts/map_screen.gd")

var _environment: Environment
var _sun: DirectionalLight3D
var _sky_mat: ProceduralSkyMaterial


func _ready() -> void:
	if GameState.is_new_game():
		Economy.start_new_game()

	# El grafo de calles debe corresponder al distrito actual (tambien al viajar).
	RoadGraph.load_for(GameState.district_slug)

	add_to_group("main")
	_setup_environment()
	_setup_light()

	var world := WorldBuilderScript.new()
	world.name = "WorldBuilder"
	add_child(world)

	var player := PlayerScript.new()
	player.name = "Player"
	add_child(player)

	var spawn := world.get_spawn_point()
	_spawn_vehicle(GameState.garage_vehicle(), "Vehicle", spawn + Vector3(2.5, 1.0, 2.2))

	var police := PoliceScript.new()
	police.name = "Police"
	add_child(police)

	var traffic := TrafficScript.new()
	traffic.name = "Traffic"
	add_child(traffic)

	var peds := PedestriansScript.new()
	peds.name = "Pedestrians"
	add_child(peds)

	var clients := ClientsScript.new()
	clients.name = "Clients"
	add_child(clients)

	var ui := TouchControlsScript.new()
	ui.name = "TouchControls"
	add_child(ui)

	var minimap := MinimapScript.new()
	minimap.name = "Minimap"
	add_child(minimap)

	var map := MapScreenScript.new()
	map.name = "MapScreen"
	add_child(map)

	var phone := PhoneUiScript.new()
	phone.name = "PhoneUI"
	add_child(phone)

	Quality.apply_to(self)


func _spawn_vehicle(kind: String, node_name: String, pos: Vector3) -> void:
	var v := VehicleScript.new()
	v.name = node_name
	v.vtype = kind
	add_child(v)
	v.global_position = pos


## El mecanico trae el vehiculo propio a la posicion del jugador (previo pago).
func deliver_vehicle(kind: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var pos := Vector3(0, 1.0, 0)
	if player is Node3D:
		var base := (player as Node3D).global_position
		if RoadGraph.loaded:
			# En la calzada mas cercana, a un lado del jugador.
			pos = RoadGraph.node_world(RoadGraph.nearest_node(base)) + Vector3(1.5, 1.0, 0)
		else:
			pos = base + Vector3(2.0, 1.0, 0)
	var old := get_node_or_null("Vehicle")
	if old != null:
		old.queue_free()
	_spawn_vehicle(kind, "Vehicle", pos)
	var vname := str(Economy.vehicle_by_id(kind).get("name", kind))
	GameState.notify("El mecanico te ha traido: %s" % vname)


## Reemplaza el vehiculo propio aparcado por otro tipo (garaje).
func replace_player_vehicle(kind: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("force_exit"):
		player.force_exit()
	var old := get_node_or_null("Vehicle")
	var pos := Vector3.ZERO
	if old != null and old is Node3D:
		pos = (old as Node3D).global_position
		old.queue_free()
	else:
		var wb := get_node_or_null("WorldBuilder")
		pos = (wb.get_spawn_point() if wb != null else Vector3.ZERO) + Vector3(3.5, 1.0, 2.5)
	_spawn_vehicle(kind, "Vehicle", pos)


func _setup_environment() -> void:
	var env := Environment.new()

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2f6fb5")
	sky_mat.sky_horizon_color = Color("bcd8ee")
	sky_mat.ground_bottom_color = Color("243b2a")
	sky_mat.ground_horizon_color = Color("9db4c0")
	sky.sky_material = sky_mat
	_sky_mat = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0

	env.fog_enabled = true
	env.fog_light_color = Color("cfe0ef")
	env.fog_density = 0.0012
	env.fog_sun_scatter = 0.15
	env.fog_aerial_perspective = 0.4

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	_environment = env


func _setup_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.15
	sun.light_color = Color("fff3d8")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 240.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	sun.light_angular_distance = 1.0
	add_child(sun)
	_sun = sun
	Clock.bind(sun, _environment, _sky_mat)


## Ajusta la calidad grafica (llamado desde el preset de calidad).
func apply_quality(preset: int) -> void:
	# 0 = bajo, 1 = medio, 2 = alto
	if _sun != null:
		_sun.shadow_enabled = preset >= 1
	if _environment != null:
		_environment.fog_enabled = preset >= 1
		_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC if preset >= 1 else Environment.TONE_MAPPER_LINEAR
