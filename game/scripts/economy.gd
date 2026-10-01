extends Node
## Economia: producto, precios, compra/venta, mejoras y banda. Autoload.
## Datos en game/data/economy.json.

const DATA_PATH := "res://game/data/economy.json"

var products: Array = []
var ranks: Array = []
var upgrades: Array = []
var dealers: Array = []
var vehicles: Array = []
var placa_units: int = 20
var start_money: int = 150
var start_posturas: int = 15

var _passive_acc: float = 0.0
var _sell_mult: Dictionary = {}   ## id -> multiplicador de precio de venta
var _event_cd: float = 45.0


func _ready() -> void:
	_load()
	for p in products:
		_sell_mult[str(p.get("id", ""))] = 1.0


## Precio de venta con el multiplicador dinamico de mercado.
func sell_price_for(id: String) -> int:
	var p := product_by_id(id)
	if p.is_empty():
		return 0
	var base := float(p.get("sell", 5)) * float(_sell_mult.get(id, 1.0)) * zone_mult()
	return maxi(1, int(round(base)))


func zone_mult() -> float:
	match GameState.district_slug:
		"centro":
			return 1.1
		"pedregalejo":
			return 0.95
		_:
			return 1.0


func _market_tick(delta: float) -> void:
	# Deriva suave del mercado.
	for p in products:
		var id := str(p.get("id", ""))
		var m := float(_sell_mult.get(id, 1.0))
		m += randf_range(-0.08, 0.08) * delta
		_sell_mult[id] = clampf(m, 0.65, 1.6)
	# Eventos de calle que alteran el precio de venta.
	_event_cd -= delta
	if _event_cd <= 0.0:
		_event_cd = randf_range(40.0, 70.0)
		_trigger_event()


func _trigger_event() -> void:
	if products.is_empty():
		return
	var p: Dictionary = products[randi() % products.size()]
	var id := str(p.get("id", ""))
	var name := str(p.get("name", id))
	var up := randf() < 0.5
	_sell_mult[id] = clampf(float(_sell_mult.get(id, 1.0)) * (1.35 if up else 0.7), 0.5, 2.0)
	var msg := ("Se demanda %s: precio AL ALZA" % name) if up else ("Bajon de %s: precio a la baja" % name)
	GameState.notify(msg)
	Audio.play_confirm()


func _load() -> void:
	var txt := FileAccess.get_file_as_string(DATA_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Economy: datos no disponibles")
		return
	var d: Dictionary = parsed
	placa_units = int(d.get("placa_units", 20))
	start_money = int(d.get("start_money", 150))
	start_posturas = int(d.get("start_posturas", 15))
	products = d.get("products", [])
	ranks = d.get("ranks", [])
	upgrades = d.get("upgrades", [])
	dealers = d.get("dealers", [])
	vehicles = d.get("vehicles", [])


func start_new_game() -> void:
	GameState.money = start_money
	GameState.posturas = start_posturas
	GameState.product_id = "hash"
	if Health != null:
		Health.reset()
	GameState.money_changed.emit(GameState.money)
	GameState.inventory_changed.emit(GameState.posturas)


# --------------------------------------------------------------------------
# Producto y precios
# --------------------------------------------------------------------------

func product_by_id(id: String) -> Dictionary:
	for p in products:
		if str(p.get("id", "")) == id:
			return p
	return {}


func current_product() -> Dictionary:
	var p := product_by_id(GameState.product_id)
	if p.is_empty() and not products.is_empty():
		return products[0]
	return p


func set_product(id: String) -> bool:
	var p := product_by_id(id)
	if p.is_empty() or GameState.rank() < int(p.get("rank", 1)):
		return false
	GameState.product_id = id
	GameState.notify("Producto: %s" % str(p.get("name", id)))
	return true


func sell_price() -> int:
	var id := str(current_product().get("id", "hash"))
	var base := sell_price_for(id)
	if GameState.upgrades.get("labia1", false):
		base += 1
	if GameState.upgrades.get("labia2", false):
		base += 2
	return maxi(1, base)


func buy_price() -> int:
	return int(current_product().get("buy", 3))


func placa_cost() -> int:
	return buy_price() * placa_units


func heat_mult() -> float:
	var m := float(current_product().get("heat", 1.0))
	var sigilo := 0.0
	if GameState.upgrades.get("pitillo", false):
		sigilo += 0.3
	if GameState.upgrades.get("vigia", false):
		sigilo += 0.6
	# El respeto del barrio reduce el calor (hasta -30%).
	var respeto_cut := clampf(GameState.respeto / 1500.0, 0.0, 0.3)
	return m * (1.0 - minf(sigilo, 0.85)) * (1.0 - respeto_cut)


# --------------------------------------------------------------------------
# Compra / venta
# --------------------------------------------------------------------------

func buy_placa() -> bool:
	var cost := placa_cost()
	if GameState.money < cost:
		GameState.notify("No tienes dinero para una placa (%d EUR)" % cost)
		return false
	GameState.add_money(-cost)
	GameState.set_posturas(GameState.posturas + placa_units)
	GameState.notify("Placa comprada: +%d posturas" % placa_units)
	return true


func sell_to(qty_wanted: int, risk: float) -> Dictionary:
	var qty := mini(qty_wanted, GameState.posturas)
	if qty <= 0:
		GameState.notify("No tienes posturas")
		return {"ok": false}
	var price := sell_price()
	var earned := price * qty
	GameState.set_posturas(GameState.posturas - qty)
	GameState.add_money(earned)
	var heat := 1.2 * float(qty) * maxf(risk, 0.2) * heat_mult()
	Wanted.add_heat(heat)
	GameState.add_xp(qty * 2)
	GameState.respeto += float(qty) * 0.5  # reputacion de barrio
	Missions.add_progress(float(qty))
	return {"ok": true, "qty": qty, "earned": earned, "heat": heat}


# --------------------------------------------------------------------------
# Mejoras
# --------------------------------------------------------------------------

func upgrade_by_id(id: String) -> Dictionary:
	for u in upgrades:
		if str(u.get("id", "")) == id:
			return u
	return {}


func has_upgrade(id: String) -> bool:
	return bool(GameState.upgrades.get(id, false))


func buy_upgrade(id: String) -> bool:
	var u := upgrade_by_id(id)
	if u.is_empty() or has_upgrade(id):
		return false
	if GameState.rank() < int(u.get("rank", 1)):
		GameState.notify("Rango insuficiente para %s" % str(u.get("name", id)))
		return false
	var cost := int(u.get("cost", 0))
	if GameState.money < cost:
		GameState.notify("No tienes dinero para %s" % str(u.get("name", id)))
		return false
	GameState.add_money(-cost)
	GameState.upgrades[id] = true
	GameState.notify("Mejora: %s" % str(u.get("name", id)))
	return true


# --------------------------------------------------------------------------
# Garaje: compra y seleccion de vehiculos
# --------------------------------------------------------------------------

func vehicle_by_id(id: String) -> Dictionary:
	for v in vehicles:
		if str(v.get("id", "")) == id:
			return v
	return {}


func buy_vehicle(id: String) -> bool:
	var v := vehicle_by_id(id)
	if v.is_empty():
		return false
	if GameState.owns_vehicle(id):
		GameState.set_garage_vehicle(id)
		GameState.notify("Vehiculo seleccionado: %s" % str(v.get("name", id)))
		return true
	if GameState.rank() < int(v.get("rank", 1)):
		GameState.notify("Rango insuficiente para %s" % str(v.get("name", id)))
		Audio.play_error()
		return false
	var cost := int(v.get("cost", 0))
	if GameState.money < cost:
		GameState.notify("No tienes dinero para %s (%d EUR)" % [str(v.get("name", id)), cost])
		Audio.play_error()
		return false
	GameState.add_money(-cost)
	GameState.add_vehicle(id)
	GameState.set_garage_vehicle(id)
	Audio.play_confirm()
	GameState.notify("Comprado: %s" % str(v.get("name", id)))
	return true


# --------------------------------------------------------------------------
# Banda (ingreso pasivo): vende posturas sola, sin calor
# --------------------------------------------------------------------------

func passive_rate() -> float:
	var rate := 0.0
	if has_upgrade("primillo"):
		rate += 0.3
	if has_upgrade("moto"):
		rate += 1.0
	return rate


func _process(delta: float) -> void:
	_market_tick(delta)
	var rate := passive_rate()
	if rate <= 0.0 or GameState.posturas <= 0:
		return
	_passive_acc += rate * delta
	if _passive_acc >= 1.0:
		var units := int(_passive_acc)
		_passive_acc -= float(units)
		var qty := mini(units, GameState.posturas)
		if qty > 0:
			GameState.set_posturas(GameState.posturas - qty)
			GameState.add_money(sell_price() * qty)
			GameState.add_xp(qty)
			GameState.respeto += float(qty) * 0.2


# --------------------------------------------------------------------------
# Rangos
# --------------------------------------------------------------------------

func rank_name(n: int) -> String:
	for r in ranks:
		if int(r.get("n", 0)) == n:
			return str(r.get("name", ""))
	return ""


func next_rank_xp() -> int:
	var cur := GameState.rank()
	for r in ranks:
		if int(r.get("n", 0)) == cur + 1:
			return int(r.get("xp", 0))
	return -1


func rank_progress() -> float:
	var cur := GameState.rank()
	var next_xp := next_rank_xp()
	if next_xp < 0:
		return 1.0
	var cur_xp := 0
	for r in ranks:
		if int(r.get("n", 0)) == cur:
			cur_xp = int(r.get("xp", 0))
	var span := next_xp - cur_xp
	if span <= 0:
		return 1.0
	return clampf(float(GameState.xp - cur_xp) / float(span), 0.0, 1.0)
