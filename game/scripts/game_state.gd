extends Node
## Estado global de la partida. Autoload.

signal money_changed(value: int)
signal notification(text: String)
signal inventory_changed(posturas: int)
signal xp_changed(xp: int, rank: int)

const DEFAULT_DISTRICT_SLUG := "nuevamalaga"
const DEFAULT_DISTRICT_NAME := "Nueva Malaga"
const AUTOSAVE_EVERY := 30.0

var player_name: String = ""
var money: int = 0
var posturas: int = 0
var xp: int = 0
var respeto: float = 0.0
var day: int = 1
var wanted: int = 0
var product_id: String = "hash"
var upgrades: Dictionary = {}
var owned_vehicles: Array = ["moto"]
var garage_vehicle_id: String = "moto"
var district_slug: String = DEFAULT_DISTRICT_SLUG
var district_name: String = DEFAULT_DISTRICT_NAME
var playtime: float = 0.0

var _autosave_acc: float = 0.0
var _last_rank: int = 1


func _ready() -> void:
	load_game()
	_last_rank = rank()
	# Mantiene GameState.wanted en sincronia con las estrellas reales.
	Wanted.level_changed.connect(func(l: int) -> void: wanted = l)


## Fija el nivel de busqueda (lo llama la policia al arrestar/escapar).
func set_wanted(value: int) -> void:
	wanted = clampi(value, 0, 5)


func _process(delta: float) -> void:
	playtime += delta
	_autosave_acc += delta
	if _autosave_acc >= AUTOSAVE_EVERY:
		_autosave_acc = 0.0
		save_game(false)


func is_new_game() -> bool:
	return not SaveManager.has_save()


# --------------------------------------------------------------------------
# Garaje
# --------------------------------------------------------------------------

func garage_vehicle() -> String:
	return garage_vehicle_id if garage_vehicle_id != "" else "moto"


func owns_vehicle(id: String) -> bool:
	return owned_vehicles.has(id)


func add_vehicle(id: String) -> void:
	if not owned_vehicles.has(id):
		owned_vehicles.append(id)


func set_garage_vehicle(id: String) -> bool:
	if not owns_vehicle(id):
		return false
	garage_vehicle_id = id
	return true


func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	money_changed.emit(money)


func set_posturas(value: int) -> void:
	posturas = maxi(0, value)
	inventory_changed.emit(posturas)


func add_xp(amount: int) -> void:
	xp = maxi(0, xp + amount)
	var r := rank()
	xp_changed.emit(xp, r)
	if r > _last_rank:
		_last_rank = r
		notify("Subes de rango: %s" % Economy.rank_name(r))


func rank() -> int:
	if Economy == null or Economy.ranks.is_empty():
		return 1
	var best := 1
	for entry in Economy.ranks:
		if xp >= int(entry.get("xp", 0)):
			best = int(entry.get("n", 1))
	return best


func notify(text: String) -> void:
	notification.emit(text)


func to_dict() -> Dictionary:
	return {
		"version": 3,
		"player_name": player_name,
		"money": money,
		"posturas": posturas,
		"xp": xp,
		"respeto": respeto,
		"day": day,
		"wanted": wanted,
		"product_id": product_id,
		"upgrades": upgrades,
		"owned_vehicles": owned_vehicles,
		"garage_vehicle_id": garage_vehicle_id,
		"district_slug": district_slug,
		"district_name": district_name,
		"playtime": playtime,
		"health": Health.value if Health != null else 100.0,
		"time_of_day": Clock.time_of_day if Clock != null else 11.0,
		"clock_day": Clock.day if Clock != null else 1,
		"mission_index": Missions.active_index if Missions != null else -1,
		"mission_progress": Missions.active_progress if Missions != null else 0.0,
	}


func save_game(notify_save: bool = true) -> void:
	var ok := SaveManager.save_data(to_dict())
	if notify_save:
		print("[GameState] guardado: ", ok)


func load_game() -> void:
	var data := SaveManager.load_data()
	if data.is_empty():
		return
	if int(data.get("version", 1)) < 3:
		# Guardado antiguo (distrito/economia cambiados): se empieza de cero.
		SaveManager.clear()
		return
	player_name = str(data.get("player_name", player_name))
	money = int(data.get("money", money))
	posturas = int(data.get("posturas", posturas))
	xp = int(data.get("xp", xp))
	respeto = float(data.get("respeto", respeto))
	day = int(data.get("day", day))
	wanted = int(data.get("wanted", wanted))
	product_id = str(data.get("product_id", product_id))
	upgrades = data.get("upgrades", upgrades)
	owned_vehicles = data.get("owned_vehicles", owned_vehicles)
	garage_vehicle_id = str(data.get("garage_vehicle_id", garage_vehicle_id))
	district_slug = str(data.get("district_slug", district_slug))
	district_name = str(data.get("district_name", district_name))
	playtime = float(data.get("playtime", playtime))
	if Clock != null:
		Clock.time_of_day = float(data.get("time_of_day", Clock.time_of_day))
		Clock.day = int(data.get("clock_day", Clock.day))
	day = Clock.day if Clock != null else int(data.get("day", day))
	if Health != null:
		Health.value = clampf(float(data.get("health", 100.0)), 1.0, 100.0)
	Wanted.set_level(wanted)


func reset() -> void:
	SaveManager.clear()
	player_name = ""
	money = 0
	posturas = 0
	xp = 0
	respeto = 0.0
	day = 1
	wanted = 0
	product_id = "hash"
	upgrades = {}
	owned_vehicles = ["moto"]
	garage_vehicle_id = "moto"
	district_slug = DEFAULT_DISTRICT_SLUG
	district_name = DEFAULT_DISTRICT_NAME
	playtime = 0.0
	_last_rank = 1
	if Clock != null:
		Clock.day = 1
		Clock.time_of_day = 11.0
	if Health != null:
		Health.reset()
	Wanted.set_level(0)
