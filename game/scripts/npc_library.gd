extends Node
## NpcLibrary (autoload "Npc"): fabrica personajes con VARIEDAD a partir de la
## libreria de assets (estilos mini y blocky, genero, ropa y roles) y centraliza
## sus animaciones. Asi todos los NPCs salen de la misma biblioteca pero no son
## clones.

# Paleta de ropa (albedo tintado sobre el atlas del personaje).
const CLOTH: Array[Color] = [
	Color("e74c3c"), Color("3498db"), Color("2ecc71"), Color("f1c40f"),
	Color("9b59b6"), Color("e67e22"), Color("1abc9c"), Color("ecf0f1"),
	Color("34495e"), Color("d35400"), Color("7f8c8d"), Color("c0392b"),
]
const BUYER: Array[Color] = [
	Color("ffd166"), Color("ef476f"), Color("06d6a0"), Color("118ab2"), Color("f78c6b"),
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Crea un personaje para un rol. Devuelve Node3D listo para anadir (o null).
func character(role: String = "civil") -> Node3D:
	var style := "mini"
	var gender := ""
	var height := 1.55
	var tint: Color = CLOTH[_rng.randi() % CLOTH.size()]
	var amount := 0.35
	match role:
		"buyer":
			gender = "male" if _rng.randf() < 0.5 else "female"
			tint = BUYER[_rng.randi() % BUYER.size()]
			amount = 0.4
		"cop":
			gender = "male"
			height = 1.62
			tint = Color("243b6b")
			amount = 0.7
		"tourist":
			tint = Color("f2e6c8")
			amount = 0.28
		"worker":
			gender = "male"
			tint = Color("f39c12")
			amount = 0.55
		"kid":
			height = 1.25
		_:
			# civil: mezcla de estilos para dar variedad visual
			if _rng.randf() < 0.7:
				style = "mini"
			else:
				style = "blocky"
	var node := Assets.character(style, gender, -1)
	if node == null:
		return null
	Assets.tint(node, tint, amount)  # seguro fuera del arbol (solo materiales)
	if node.has_meta("asset_id"):
		node.set_meta("npc_id", node.get_meta("asset_id"))
	node.set_meta("npc_role", role)
	node.set_meta("npc_height", height)
	return node


## Ajusta escala y posicion tras anadir el nodo al arbol (necesita transforms).
func apply(node: Node3D) -> void:
	if node == null:
		return
	Assets.fit_height(node, float(node.get_meta("npc_height", 1.55)))
	node.position = Vector3(0, -Assets.min_y(node), 0)


## Velocidad de paseo segun rol.
func walk_speed(role: String) -> float:
	match role:
		"buyer":
			return 1.8
		"kid":
			return 1.9
		"worker":
			return 1.6
		_:
			return 1.45


## Animaciones de locomocion disponibles (idle/walk/sprint en todos los estilos).
func locomotion() -> Array:
	return ["walk", "sprint", "idle"]


## Animacion de "sentarse/tumbarse"/emote aleatoria para dar vida en los ratos
## de espera (los personajes Kenney traen 27-32 clips).
func idle_emote() -> String:
	var opts := ["idle", "idle", "idle", "emote-yes", "emote-no", "interact-right"]
	return opts[_rng.randi() % opts.size()]
