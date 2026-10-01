extends Node
## Grafo de calles horneado (del plano GEO). Navegacion de IA con A*. Autoload.
## Coordenadas del grafo en metros (x=este, y=norte); el mundo usa (x, y, -y_grafo).

const DEFAULT_SLUG := "centro"

var slug: String = DEFAULT_SLUG
var pts: PackedVector2Array = PackedVector2Array()
var adj: Array = []          ## Array[Array[Dictionary{to:int, w:float}]]
var loaded: bool = false


func _ready() -> void:
	load_for(GameState.district_slug)


func load_for(s: String) -> void:
	slug = s if not s.is_empty() else DEFAULT_SLUG
	pts = PackedVector2Array()
	adj = []
	loaded = false
	var path := "res://game/data/road_graph_%s.json" % slug
	if not FileAccess.file_exists(path):
		slug = DEFAULT_SLUG
		path = "res://game/data/road_graph_%s.json" % slug
	_load(path)


func _load(path: String) -> void:
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("RoadGraph: no se encontro el grafo (%s)" % path)
		return
	var d: Dictionary = parsed
	var nodes: Array = d.get("nodes", [])
	pts.resize(nodes.size())
	adj.resize(nodes.size())
	for i in range(adj.size()):
		adj[i] = []
	for n in nodes:
		var id := int(n["id"])
		var p: Array = n["p"]
		pts[id] = Vector2(float(p[0]), float(p[1]))
	for e in d.get("edges", []):
		var a := int(e["a"])
		var b := int(e["b"])
		var w := float(e.get("len", pts[a].distance_to(pts[b])))
		adj[a].append({"to": b, "w": w})
		# Las vias de sentido unico solo permiten a -> b.
		if not bool(e.get("oneway", false)):
			adj[b].append({"to": a, "w": w})
	loaded = true
	print("[RoadGraph:%s] %d nodos, %d aristas" % [slug, pts.size(), _edge_count()])


func _edge_count() -> int:
	var total := 0
	for a in adj:
		total += a.size()
	return total / 2


func world_to_bp(pos: Vector3) -> Vector2:
	return Vector2(pos.x, -pos.z)


func node_world(i: int) -> Vector3:
	var p := pts[i]
	return Vector3(p.x, Terrain.height_at_bp(p.x, p.y) + 0.3, -p.y)


func nearest_node(pos: Vector3) -> int:
	if not loaded:
		return -1
	var p := world_to_bp(pos)
	var best := -1
	var best_d := INF
	for i in range(pts.size()):
		var d := p.distance_squared_to(pts[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func find_path(from: int, to: int) -> PackedInt32Array:
	if not loaded or from < 0 or to < 0 or from >= pts.size() or to >= pts.size():
		return PackedInt32Array()
	if from == to:
		return PackedInt32Array([from])

	var open: Array[int] = [from]
	var came: Dictionary = {}
	var g: Dictionary = {from: 0.0}
	var f: Dictionary = {from: pts[from].distance_to(pts[to])}
	var closed: Dictionary = {}

	while not open.is_empty():
		var bi := 0
		for i in range(1, open.size()):
			if float(f.get(open[i], INF)) < float(f.get(open[bi], INF)):
				bi = i
		var current: int = open[bi]
		if current == to:
			return _reconstruct(came, current)
		open.remove_at(bi)
		closed[current] = true

		for edge in adj[current]:
			var nb: int = int(edge["to"])
			if closed.has(nb):
				continue
			var tentative := float(g.get(current, INF)) + float(edge["w"])
			if tentative < float(g.get(nb, INF)):
				came[nb] = current
				g[nb] = tentative
				f[nb] = tentative + pts[nb].distance_to(pts[to])
				if not open.has(nb):
					open.append(nb)
	return PackedInt32Array()


func _reconstruct(came: Dictionary, current: int) -> PackedInt32Array:
	var path := PackedInt32Array([current])
	while came.has(current):
		current = int(came[current])
		path.insert(0, current)
	return path
