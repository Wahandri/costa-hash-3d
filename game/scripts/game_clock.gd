extends Node
## GameClock (autoload "Clock"): ciclo dia/noche. Mueve el sol y ajusta el cielo,
## la luz ambiental y (via otros managers) la cantidad de gente en la calle.

const HOURS_PER_SECOND := 1.0 / 20.0  ## 1 h de juego cada 20 s reales (dia ≈ 8 min)

signal night_changed(is_night: bool)

var time_of_day: float = 11.0  ## 0..24
var day: int = 1
var paused: bool = false

var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _was_night: bool = false

# Noche "suave": azulada y clara, no negra.
const SKY_DAY := Color("2f6fb5")
const SKY_NIGHT := Color("16213f")
const HOR_DAY := Color("bcd8ee")
const HOR_NIGHT := Color("3a4a6b")
const GROUND_DAY := Color("243b2a")
const GROUND_NIGHT := Color("1a2233")
const SUN_DAY := Color("fff3d8")
const SUN_NIGHT := Color("a9c0ff")


func bind(sun: DirectionalLight3D, env: Environment, sky: ProceduralSkyMaterial) -> void:
	_sun = sun
	_env = env
	_sky = sky
	_apply()


func is_night() -> bool:
	return _sun_elevation() < -2.0


func _sun_elevation() -> float:
	return sin((time_of_day - 6.0) / 24.0 * TAU) * 70.0


func _process(delta: float) -> void:
	if paused:
		return
	var prev := time_of_day
	time_of_day = fmod(time_of_day + delta * HOURS_PER_SECOND, 24.0)
	if time_of_day < prev:  # paso de medianoche
		day += 1
		if GameState != null:
			GameState.day = day
	if _sun != null:
		_apply()
		_maybe_emit_night()


func _maybe_emit_night() -> void:
	var n := is_night()
	if n != _was_night:
		_was_night = n
		night_changed.emit(n)


func _apply() -> void:
	var elev := _sun_elevation()
	var night := clampf(-elev / 12.0, 0.0, 1.0)
	if _sun != null:
		_sun.rotation_degrees = Vector3(-elev, -35.0 + time_of_day / 24.0 * 360.0, 0.0)
		# Noche clara ("leve oscuro") en vez de casi apagada.
		_sun.light_energy = lerpf(1.25, 0.38, night)
		_sun.light_color = SUN_DAY.lerp(SUN_NIGHT, night)
	if _sky != null:
		_sky.sky_top_color = SKY_DAY.lerp(SKY_NIGHT, night)
		_sky.sky_horizon_color = HOR_DAY.lerp(HOR_NIGHT, night)
		_sky.ground_bottom_color = GROUND_DAY.lerp(GROUND_NIGHT, night)
	if _env != null:
		_env.ambient_light_energy = lerpf(1.05, 0.55, night)
