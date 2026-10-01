extends Node3D
## Construye el blockout low-poly del distrito a partir del plano de diseno
## (blueprint de la herramienta GEO). La geometria se genera al cargar y se
## podra hornear a escena estatica mas adelante (ver PENDIENTES.md).

const TrafficLightScript := preload("res://game/scripts/traffic_light.gd")
const NightGlowScript := preload("res://game/scripts/night_glow.gd")

const SEA_WIDTH := 1500.0
const GROUND_HALF := 2500.0
const GROUND_LAYER := 1
const BUILDING_LAYER := 4

var _spawn := Vector3(0, 1.5, 0)
var _facade_tex: ImageTexture = null
var _world_bounds := Rect2(Vector2(-300.0, -300.0), Vector2(600.0, 600.0))
var _terr_faces := PackedVector3Array()

# Tonos mediterraneos claros (Málaga blanca/crema/arena).
const BUILDING_PALETTE: Array[Color] = [
	Color("efe9dd"), Color("f5f1e8"), Color("e3dccb"),
	Color("ecdcc0"), Color("ded6c6"), Color("e9e2d4"), Color("d8cfbd"),
]


func _ready() -> void:
	add_to_group("world_builder")
	var data := _load_blueprint()
	if data.is_empty():
		push_error("WorldBuilder: no se pudo cargar el blueprint")
		return
	var t0 := Time.get_ticks_msec()
	Terrain.configure(data.get("terrain", {}))
	_world_bounds = _compute_bounds(data)
	_build_terrain()
	_build_parks(data.get("parks", []))
	_build_water(data.get("water", []))
	_build_sea(data.get("coastline", []))
	_build_rivers(data.get("rivers", []))
	_build_stairs(data.get("stairs", []))
	_build_roads(data.get("roads", []))
	_build_road_details(data.get("roads", []))
	_build_buildings(data.get("buildings", []))
	_build_landmarks(data.get("landmarks", []))
	_build_props(data)
	_compute_spawn(data.get("roads", []))
	print("[WorldBuilder] construido en %d ms" % (Time.get_ticks_msec() - t0))


func _load_blueprint() -> Dictionary:
	var slug := GameState.district_slug
	if slug.is_empty():
		slug = "centro"
	var path := "res://game/data/blueprint_%s.json" % slug
	if not FileAccess.file_exists(path):
		path = "res://game/data/blueprint_centro.json"
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


func get_spawn_point() -> Vector3:
	return _spawn


# --------------------------------------------------------------------------
# Materiales
# --------------------------------------------------------------------------

func _flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _vertex_color_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Textura procedural de fachada (rejilla de ventanas). Se multiplica por el color
## del edificio (vertex colors). Evita depender de texturas externas.
func _facade_texture() -> ImageTexture:
	if _facade_tex != null:
		return _facade_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var floor_h := 16
	var wall := Color(1.0, 0.97, 0.92)
	var win := Color(0.52, 0.62, 0.74)
	var frame := Color(0.85, 0.85, 0.88)
	for y in range(size):
		for x in range(size):
			var in_floor := (y % floor_h) < 11
			var wx := x % 16
			var wy := y % floor_h
			var c := wall
			if in_floor and wx >= 4 and wx <= 12 and wy >= 3 and wy <= 9:
				c = win
			elif in_floor and (wx == 3 or wx == 13):
				c = frame
			img.set_pixel(x, y, c)
	_facade_tex = ImageTexture.create_from_image(img)
	return _facade_tex


func _building_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _facade_texture()
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.11, 0.11, 0.11)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.92
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _commit(st: SurfaceTool, mat: Material, name: String) -> MeshInstance3D:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	return mi


# --------------------------------------------------------------------------
# Suelo y colision
# --------------------------------------------------------------------------

const GROUND_MARGIN := 220.0

func _compute_bounds(data: Dictionary) -> Rect2:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	var any := false
	for key in ["roads", "buildings", "parks", "water"]:
		for it in data.get(key, []):
			for p in it.get("pts", []):
				if p is Array and (p as Array).size() >= 2:
					var v := Vector2(float(p[0]), float(p[1]))
					mn = Vector2(minf(mn.x, v.x), minf(mn.y, v.y))
					mx = Vector2(maxf(mx.x, v.x), maxf(mx.y, v.y))
					any = true
	if not any:
		return Rect2(Vector2(-GROUND_HALF, -GROUND_HALF), Vector2(GROUND_HALF * 2.0, GROUND_HALF * 2.0))
	mn -= Vector2(GROUND_MARGIN, GROUND_MARGIN)
	mx += Vector2(GROUND_MARGIN, GROUND_MARGIN)
	return Rect2(mn, mx - mn)


## Terreno con el relieve real (malla DEM del blueprint) + colision trimesh.
func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if Terrain.is_ready:
		for iy in range(Terrain.ny - 1):
			for ix in range(Terrain.nx - 1):
				var p00 := _terr_pt(ix, iy)
				var p10 := _terr_pt(ix + 1, iy)
				var p01 := _terr_pt(ix, iy + 1)
				var p11 := _terr_pt(ix + 1, iy + 1)
				_terr_tri(st, p00, p10, p11)
				_terr_tri(st, p00, p11, p01)
	else:
		_add_quad_xz(st, _world_bounds.position, _world_bounds.end, 0.0)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = _terrain_material()
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = GROUND_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	if Terrain.is_ready and _terr_faces.size() >= 3:
		var tri := ConcavePolygonShape3D.new()
		tri.set_faces(_terr_faces)
		tri.backface_collision = true
		cs.shape = tri
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(_world_bounds.size.x, 4.0, _world_bounds.size.y)
		cs.shape = box
		cs.position = Vector3(_world_bounds.get_center().x, -2.0, -_world_bounds.get_center().y)
	body.add_child(cs)
	add_child(body)

	# Plancha base grande (evita ver "vacio" al borde del terreno).
	var base := SurfaceTool.new()
	base.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad_xz(base, Vector2(-3000, -3000), Vector2(3000, 3000), -3.0)
	_commit(base, _flat_material(Color("20281f")), "BasePlane")


func _terr_pt(ix: int, iy: int) -> Vector3:
	var x := Terrain.x0 + float(ix) * Terrain.sx
	var yb := Terrain.y0 + float(iy) * Terrain.sy
	return Vector3(x, Terrain.height_at_bp(x, yb), -yb)


func _terr_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for v in [a, b, c]:
		st.set_color(_terr_color(v.y))
		st.add_vertex(v)
	# Caras para la colision trimesh (mas fiable que mesh.get_faces()).
	_terr_faces.append(a); _terr_faces.append(b); _terr_faces.append(c)


func _terr_color(h: float) -> Color:
	# Terreno urbano seco (tierra/arena) que se aclara con la altura: asi se leen
	# las cuestas y el asfalto/acera destacan sobre el.
	var t := clampf(h / 80.0, 0.0, 1.0)
	return Color("6b6452").lerp(Color("8a8168"), t)


func _terrain_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# --------------------------------------------------------------------------
# Elementos del plano
# --------------------------------------------------------------------------

func _build_parks(items: Array) -> void:
	if items.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it in items:
		_add_fill(st, _to_pts(it["pts"]), 0.12)
	_commit(st, _flat_material(Color("2e7d43")), "Parks")


func _build_water(items: Array) -> void:
	if items.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it in items:
		_add_fill(st, _to_pts(it["pts"]), 0.2)
	_commit(st, _flat_material(Color("1f5fa8")), "Water")


func _build_sea(coastlines: Array) -> void:
	if coastlines.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it in coastlines:
		var pts := _to_pts(it["pts"])
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var d := b - a
			if d.length() < 0.01:
				continue
			var right := Vector2(d.y, -d.x).normalized() * SEA_WIDTH
			var a0 := Vector3(a.x, 0.06, -a.y)
			var b0 := Vector3(b.x, 0.06, -b.y)
			var a1 := Vector3(a.x + right.x, 0.06, -(a.y + right.y))
			var b1 := Vector3(b.x + right.x, 0.06, -(b.y + right.y))
			st.add_vertex(a0); st.add_vertex(a1); st.add_vertex(b1)
			st.add_vertex(a0); st.add_vertex(b1); st.add_vertex(b0)
	_commit(st, _flat_material(Color("17518f")), "Sea")


func _build_rivers(items: Array) -> void:
	if items.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it in items:
		_add_ribbon(st, _to_pts(it["pts"]), 10.0, 0.16)
	_commit(st, _flat_material(Color("2f7fd6")), "Rivers")


## Escaleras (steps de OSM): pasillo + peldaños transversales, sobre el terreno.
func _build_stairs(items: Array) -> void:
	if items.is_empty():
		return
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_r := SurfaceTool.new(); st_r.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it in items:
		var pts := _to_pts(it["pts"])
		if pts.size() < 2:
			continue
		_add_ribbon(st, pts, 2.4, 0.18)
		_add_steps_rungs(st_r, pts, 2.4, 0.205)
	_commit(st, _flat_material(Color("9aa0a6")), "Stairs")
	_commit(st_r, _flat_material(Color("6f757c")), "StairRungs")


func _add_steps_rungs(st: SurfaceTool, pts: PackedVector2Array, width: float, off: float) -> void:
	var hw := width * 0.5
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		var L := d.length()
		if L < 0.01:
			continue
		var dir := d / L
		var nrm := Vector2(-dir.y, dir.x)
		var dist := 0.0
		while dist < L:
			var p := a + dir * dist
			var a0 := p + nrm * hw
			var a1 := p - nrm * hw
			var b0 := p + dir * 0.24 + nrm * hw
			var b1 := p + dir * 0.24 - nrm * hw
			st.add_vertex(_wv(a0.x, a0.y, off)); st.add_vertex(_wv(a1.x, a1.y, off)); st.add_vertex(_wv(b1.x, b1.y, off))
			st.add_vertex(_wv(a0.x, a0.y, off)); st.add_vertex(_wv(b1.x, b1.y, off)); st.add_vertex(_wv(b0.x, b0.y, off))
			dist += 1.0


func _build_roads(items: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it in items:
		var width := _road_width(str(it.get("class", "residential")))
		_add_ribbon(st, _to_pts(it["pts"]), width, 0.05)
	_commit(st, _flat_material(Color("2f3238")), "Roads")


func _build_road_details(items: Array) -> void:
	var st_side := SurfaceTool.new(); st_side.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_curb := SurfaceTool.new(); st_curb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_line := SurfaceTool.new(); st_line.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it in items:
		var pts := _to_pts(it["pts"])
		var cls := str(it.get("class", "residential"))
		var hw := _road_width(cls) * 0.5
		# Aceras claras a ambos lados (contraste con el asfalto).
		_add_ribbon_offset(st_side, pts, 2.7, hw + 1.35, 0.08)
		_add_ribbon_offset(st_side, pts, 2.7, -(hw + 1.35), 0.08)
		# Bordillos (banda mas oscura y elevada = escalon acera/calzada).
		_add_ribbon_offset(st_curb, pts, 0.5, hw + 0.2, 0.15)
		_add_ribbon_offset(st_curb, pts, 0.5, -(hw + 0.2), 0.15)
		# Linea central discontinua (blanca) en vias principales.
		if cls in ["primary", "primary_link", "secondary", "secondary_link", "tertiary", "tertiary_link"]:
			_add_dashed(st_line, pts, 0.18, 0.0, 0.1, 3.0, 4.5)
	_commit(st_side, _flat_material(Color("c4c0b4")), "Sidewalks")
	_commit(st_curb, _flat_material(Color("4f4d47")), "Curbs")
	_commit(st_line, _flat_material(Color("e8e6df")), "RoadLines")


func _add_ribbon_offset(st: SurfaceTool, pts: PackedVector2Array, width: float, offset: float, off: float) -> void:
	var hw := width * 0.5
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		if d.length() < 0.01:
			continue
		var nrm := Vector2(-d.y, d.x).normalized()
		var c := nrm * offset
		var a0 := _wv(a.x + c.x + nrm.x * hw, a.y + c.y + nrm.y * hw, off)
		var a1 := _wv(a.x + c.x - nrm.x * hw, a.y + c.y - nrm.y * hw, off)
		var b0 := _wv(b.x + c.x + nrm.x * hw, b.y + c.y + nrm.y * hw, off)
		var b1 := _wv(b.x + c.x - nrm.x * hw, b.y + c.y - nrm.y * hw, off)
		st.add_vertex(a0); st.add_vertex(a1); st.add_vertex(b1)
		st.add_vertex(a0); st.add_vertex(b1); st.add_vertex(b0)


func _add_dashed(st: SurfaceTool, pts: PackedVector2Array, width: float, offset: float, off: float, dash: float, gap: float) -> void:
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		var L := d.length()
		if L < 0.01:
			continue
		var dir := d / L
		var nrm := Vector2(-dir.y, dir.x)
		var dist := 0.0
		while dist < L:
			var seg := minf(dash, L - dist)
			var p0 := a + dir * dist
			var p1 := a + dir * (dist + seg)
			var c0 := nrm * (offset + width * 0.5)
			var c1 := nrm * (offset - width * 0.5)
			st.add_vertex(_wv(p0.x + c0.x, p0.y + c0.y, off))
			st.add_vertex(_wv(p0.x + c1.x, p0.y + c1.y, off))
			st.add_vertex(_wv(p1.x + c1.x, p1.y + c1.y, off))
			st.add_vertex(_wv(p0.x + c0.x, p0.y + c0.y, off))
			st.add_vertex(_wv(p1.x + c1.x, p1.y + c1.y, off))
			st.add_vertex(_wv(p1.x + c0.x, p1.y + c0.y, off))
			dist += dash + gap


func _build_buildings(items: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var body := StaticBody3D.new()
	body.name = "BuildingsBody"
	body.collision_layer = BUILDING_LAYER
	body.collision_mask = 0

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260928

	for it in items:
		var pts := _to_pts(it["pts"])
		if pts.size() < 3:
			continue
		var area := _polygon_area(pts)
		if area < 12.0:
			continue
		var id := int(it.get("id", 0))
		var base_y := _footprint_base(pts)
		# Altura real por plantas (building:levels); respaldo por area.
		var levels := float(it.get("levels", -1.0))
		var h := levels * 3.2 if levels > 0.0 else _height_for(area, id)
		h = clampf(h, 3.0, 60.0)
		# Color real de fachada si existe; si no, paleta.
		var col: Variant = _hex_color(str(it.get("colour", "")))
		if col == null:
			col = (BUILDING_PALETTE[abs(id) % BUILDING_PALETTE.size()]).darkened(rng.randf_range(0.0, 0.12))
		var rs := str(it.get("roof_shape", ""))
		var pitched := rs in ["gabled", "skillion", "mansard", "hipped", "pyramidal", "round"]
		var roof: Variant = _hex_color(str(it.get("roof_colour", "")))
		if roof == null:
			roof = Color("a2543a") if pitched else (col as Color).lightened(0.08)
		_add_prism(st, pts, base_y, h, col as Color, roof as Color)
		if pitched:
			_add_roof(st, pts, base_y + h, roof as Color, rs)
		_add_building_collision(body, pts, base_y, h)

	_commit(st, _building_material(), "Buildings")
	add_child(body)


func _road_width(cls: String) -> float:
	match cls:
		"motorway", "motorway_link", "trunk", "trunk_link":
			return 16.0
		"primary", "primary_link":
			return 13.0
		"secondary", "secondary_link":
			return 10.0
		"tertiary", "tertiary_link":
			return 8.0
		"pedestrian":
			return 6.0
		"service":
			return 4.5
		_:
			return 6.5


func _height_for(area: float, id: int) -> float:
	var r := float(abs(id * 2654435761) % 1000) / 1000.0
	var h := 6.0 + sqrt(maxf(area, 1.0)) * 0.55
	return clampf(h * (0.7 + r * 0.9), 5.0, 55.0)


## Base del edificio: minimo de terreno bajo la huella, un poco enterrada.
func _footprint_base(pts: PackedVector2Array) -> float:
	var mn := INF
	for p in pts:
		mn = minf(mn, Terrain.height_at_bp(p.x, p.y))
	if mn == INF:
		mn = 0.0
	return mn - 0.4


## Color a partir de hex ("RRGGBB" o "#RRGGBB"). Devuelve null si no es valido.
func _hex_color(s: String) -> Variant:
	s = s.strip_edges().lstrip("#")
	if s.length() != 6:
		return null
	if not s.is_valid_hex_number(false):
		return null
	return Color(s)


func _add_building_collision(body: StaticBody3D, pts: PackedVector2Array, base_y: float, h: float) -> void:
	# Colision convexa (mucho mas fiel que una caja AABB: no invade la calzada).
	if pts.size() < 3:
		return
	var points := PackedVector3Array()
	for p in pts:
		points.append(Vector3(p.x, base_y, -p.y))
		points.append(Vector3(p.x, base_y + h, -p.y))
	if points.size() < 4:
		return
	var shape := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	convex.points = points
	shape.shape = convex
	body.add_child(shape)


# --------------------------------------------------------------------------
# Landmarks reales (iglesia donde hay iglesia, salud donde hay salud, etc.)
# --------------------------------------------------------------------------

const LM_COLOR := {
	"church": Color("c9b48c"), "health": Color("f2f2f2"), "pharmacy": Color("f2f2f2"),
	"school": Color("d9b26a"), "market": Color("d98a4a"), "police": Color("3b5b9c"),
	"townhall": Color("c9b48c"), "fire": Color("c0392b"), "library": Color("cbb994"),
	"bank": Color("8fa1b3"), "post": Color("e2b93b"), "fuel": Color("8fa1b3"),
	"community": Color("cdb892"), "hotel": Color("d9c6a6"), "museum": Color("c2b291"),
	"supermarket": Color("6aa84f"), "sports": Color("4a9c6d"),
}

func _build_landmarks(items: Array) -> void:
	if items.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it in items:
		var kind := str(it.get("kind", ""))
		var cx := float(it.get("x", 0.0))
		var cy := float(it.get("y", 0.0))
		var gy := Terrain.height_at_bp(cx, cy)
		_lm_geometry(st, cx, cy, gy, kind)
		# Sin letreros: el edificio se distingue por su forma/color (fidelidad visual).
		var holder := Node3D.new()
		holder.name = "LM_" + kind
		holder.position = Vector3(cx, gy, -cy)
		holder.add_to_group("landmarks")
		holder.set_meta("kind", kind)
		add_child(holder)
	_commit(st, _vertex_color_material(), "Landmarks")


func _lm_geometry(st: SurfaceTool, cx: float, cy: float, gy: float, kind: String) -> void:
	var col: Color = LM_COLOR.get(kind, Color("cccccc"))
	match kind:
		"church":
			_box(st, cx, cy, gy, 14.0, 10.0, 11.0, col)
			_box(st, cx, cy - 6.5, gy, 4.5, 4.5, 18.0, col.darkened(0.05))
			_box(st, cx, cy - 6.5, gy + 18.0, 0.6, 0.6, 2.6, Color("ffffff"))
			_box(st, cx, cy - 6.5, gy + 18.6, 1.8, 0.5, 0.5, Color("ffffff"))
		"health", "pharmacy":
			_box(st, cx, cy, gy, 16.0, 12.0, 9.0, col)
			_box(st, cx, cy - 6.2, gy + 6.0, 0.7, 0.7, 2.4, Color("e23b3b"))
			_box(st, cx, cy - 6.2, gy + 6.6, 2.2, 0.7, 0.7, Color("e23b3b"))
		"school":
			_box(st, cx, cy, gy, 22.0, 14.0, 8.0, col)
			_box(st, cx, cy, gy + 8.0, 4.0, 4.0, 6.0, col.darkened(0.1))
		"market":
			_box(st, cx, cy, gy + 0.1, 22.0, 16.0, 0.3, Color("9a8f7c"))
			for i in range(4):
				var sx := cx - 7.0 + float(i) * 4.6
				_box(st, sx, cy, gy + 0.3, 3.0, 3.0, 2.2, Color("d98a4a"))
		"police", "fire":
			_box(st, cx, cy, gy, 15.0, 12.0, 9.0, col)
		"supermarket":
			_box(st, cx, cy, gy, 26.0, 18.0, 7.0, col)
		"sports":
			_box(st, cx, cy, gy + 0.05, 34.0, 22.0, 0.25, Color("3f8f57"))
			_box(st, cx + 12.0, cy, gy, 6.0, 6.0, 5.0, col)
		_:
			_box(st, cx, cy, gy, 13.0, 11.0, 8.0, col)


## Caja axis-aligned (coords de plano) asentada en y0. Caras con una sola normal
## gracias a generate_normals del SurfaceTool.
func _box(st: SurfaceTool, cx: float, cy: float, y0: float, w: float, d: float, h: float, col: Color) -> void:
	var x0 := cx - w * 0.5
	var x1 := cx + w * 0.5
	var z0 := -(cy - d * 0.5)
	var z1 := -(cy + d * 0.5)
	var y1 := y0 + h
	st.set_color(col)
	# suelo y techo
	_quad(st, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1))
	_quad(st, Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0))
	# paredes
	_quad(st, Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y0, z0))
	_quad(st, Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(x0, y0, z1))
	_quad(st, Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(x0, y0, z0))
	_quad(st, Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1))


# --------------------------------------------------------------------------
# Mobiliario urbano (props) con MultiMesh (barato en web/movil)
# --------------------------------------------------------------------------

const PROP_STEP := 46.0
const LIGHT_MAX := 280
const TREE_MAX := 170
const TLIGHT_MAX := 70

## Colision simple (cilindros en un solo StaticBody) para props sin malla fisica:
## evita que el jugador/NPCs atraviesen farolas, arboles y semaforos.
func _add_prop_collision(transforms: Array, radius: float, height: float) -> void:
	if transforms.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "PropCollision"
	body.collision_layer = BUILDING_LAYER
	body.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	for t in transforms:
		var cs := CollisionShape3D.new()
		cs.shape = shape
		var p: Vector3 = (t as Transform3D).origin
		cs.position = Vector3(p.x, p.y + height * 0.5, p.z)
		body.add_child(cs)
	add_child(body)


func _build_props(data: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	_scatter_streetlights(data.get("roads", []))
	_scatter_sidewalk_props(data.get("roads", []))
	_scatter_trees(data.get("parks", []))
	_scatter_traffic_lights()
	print("[WorldBuilder] props en %d ms" % (Time.get_ticks_msec() - t0))


## Jardineras, contenedores y señales repartidos por las aceras (dan vida al
## recorrido). MultiMesh por tipo + colision simple.
func _scatter_sidewalk_props(roads: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31415
	_add_sidewalk_prop("planter", _sidewalk_points(roads, 70.0, 1.6, 130, rng), 1.2, 0.5, 1.0, "Planters")
	_add_sidewalk_prop("dumpster", _sidewalk_points(roads, 120.0, 1.9, 55, rng), 1.5, 0.6, 1.2, "Dumpsters")
	_add_sidewalk_prop("sign_street", _sidewalk_points(roads, 95.0, 0.9, 80, rng), 2.6, 0.12, 2.4, "Signs")


func _add_sidewalk_prop(key: String, transforms: Array, target_h: float, col_r: float, col_h: float, node_name: String) -> void:
	if transforms.is_empty():
		return
	var node := Assets.build_scatter(key, transforms, target_h)
	if node != null:
		node.name = node_name
		add_child(node)
	_add_prop_collision(transforms, col_r, col_h)


## Puntos a lo largo de las calles, desplazados a la acera (lado alterno).
func _sidewalk_points(roads: Array, step: float, extra: float, cap: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var side := 1.0
	for r in roads:
		if out.size() >= cap:
			break
		var pts := _to_pts(r.get("pts", []))
		var width := _road_width(str(r.get("class", "residential")))
		var acc := 0.0
		for i in range(pts.size() - 1):
			if out.size() >= cap:
				break
			var a := pts[i]
			var b := pts[i + 1]
			var d := b - a
			var L := d.length()
			if L < 0.01:
				continue
			var dir := d / L
			var nrm := Vector2(-dir.y, dir.x)
			var traveled := 0.0
			while (L - traveled) + acc >= step:
				var need := step - acc
				traveled += need
				var p := a + dir * traveled
				var off := nrm * (width * 0.5 + extra) * side
				var px := p.x + off.x
				var py := p.y + off.y
				out.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)),
					Vector3(px, _ty(px, py, 0.0), -py)))
				side = -side
				acc = 0.0
			acc += (L - traveled)
	return out


func _scatter_streetlights(roads: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var transforms: Array = []
	var side := 1.0
	for r in roads:
		if transforms.size() >= LIGHT_MAX:
			break
		var pts := _to_pts(r.get("pts", []))
		var width := _road_width(str(r.get("class", "residential")))
		var acc := 0.0
		for i in range(pts.size() - 1):
			if transforms.size() >= LIGHT_MAX:
				break
			var a := pts[i]
			var b := pts[i + 1]
			var d := b - a
			var L := d.length()
			if L < 0.01:
				continue
			var dir := d / L
			var nrm := Vector2(-dir.y, dir.x)
			var traveled := 0.0
			while (L - traveled) + acc >= PROP_STEP:
				var need := PROP_STEP - acc
				traveled += need
				var p := a + dir * traveled
				var off := nrm * (width * 0.5 + 0.7) * side
				var pos := Vector3(p.x + off.x, _ty(p.x + off.x, p.y + off.y, 0.0), -(p.y + off.y))
				var yaw := atan2(dir.x, dir.y) + (PI if side < 0.0 else 0.0)
				transforms.append(Transform3D(Basis(Vector3.UP, yaw), pos))
				side = -side
				acc = 0.0
			acc += (L - traveled)
	if not transforms.is_empty():
		var node := Assets.build_scatter("streetlight", transforms, 6.0)
		if node != null:
			node.name = "Streetlights"
			add_child(node)
		# Farolas encendidas de noche (resplandor emisivo).
		var glow := NightGlowScript.new()
		glow.name = "StreetGlow"
		add_child(glow)
		glow.build(transforms, 5.4, 0.55, Color("ffe6a0"))
		_add_prop_collision(transforms, 0.18, 6.0)


func _scatter_trees(parks: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var big: Array = []
	var small: Array = []
	for pk in parks:
		if big.size() + small.size() >= TREE_MAX:
			break
		var pts := _to_pts(pk.get("pts", []))
		if pts.size() < 3:
			continue
		var area := _polygon_area(pts)
		if area < 80.0:
			continue
		var count := int(clampf(area / 900.0, 1.0, 10.0))
		var bb := _bounds(pts)
		for _k in range(count):
			if big.size() + small.size() >= TREE_MAX:
				break
			var p := Vector2(rng.randf_range(bb.position.x, bb.end.x), rng.randf_range(bb.position.y, bb.end.y))
			if not Geometry2D.is_point_in_polygon(p, pts):
				continue
			var pos := Vector3(p.x, _ty(p.x, p.y, 0.0), -p.y)
			var yaw := rng.randf_range(0.0, TAU)
			var tr := Transform3D(Basis(Vector3.UP, yaw), pos)
			if rng.randf() < 0.6:
				big.append(tr)
			else:
				small.append(tr)
	if not big.is_empty():
		var nb := Assets.build_scatter("tree_large", big, 8.0)
		if nb != null:
			nb.name = "TreesLarge"
			add_child(nb)
		_add_prop_collision(big, 0.3, 3.0)
	if not small.is_empty():
		var ns := Assets.build_scatter("tree_small", small, 5.0)
		if ns != null:
			ns.name = "TreesSmall"
			add_child(ns)
		_add_prop_collision(small, 0.25, 2.5)


func _scatter_traffic_lights() -> void:
	if not RoadGraph.loaded:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777
	var container := Node3D.new()
	container.name = "TrafficLights"
	add_child(container)
	var transforms: Array = []
	var count := 0
	for i in range(RoadGraph.adj.size()):
		if count >= TLIGHT_MAX:
			break
		if (RoadGraph.adj[i] as Array).size() < 3:
			continue
		var p := RoadGraph.pts[i]
		var tl := TrafficLightScript.new()
		container.add_child(tl)
		var tlx := p.x + rng.randf_range(1.2, 2.2)
		var tly := p.y + rng.randf_range(1.2, 2.2)
		var pos := Vector3(tlx, _ty(tlx, tly, 0.0), -tly)
		tl.position = pos
		tl.rotation.y = rng.randf_range(0.0, TAU)
		transforms.append(Transform3D(Basis(), pos))
		count += 1
	_add_prop_collision(transforms, 0.15, 4.0)


func _bounds(pts: PackedVector2Array) -> Rect2:
	var mn := pts[0]
	var mx := pts[0]
	for p in pts:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	return Rect2(mn, mx - mn)


# --------------------------------------------------------------------------
# Primitivas
# --------------------------------------------------------------------------

func _add_quad_xz(st: SurfaceTool, a: Vector2, b: Vector2, y: float) -> void:
	st.add_vertex(Vector3(a.x, y, -a.y))
	st.add_vertex(Vector3(b.x, y, -a.y))
	st.add_vertex(Vector3(b.x, y, -b.y))
	st.add_vertex(Vector3(a.x, y, -a.y))
	st.add_vertex(Vector3(b.x, y, -b.y))
	st.add_vertex(Vector3(a.x, y, -b.y))


## Altura del terreno (plano) + offset vertical, en el mundo.
func _ty(x: float, yb: float, off: float) -> float:
	return Terrain.height_at_bp(x, yb) + off


func _add_fill(st: SurfaceTool, pts: PackedVector2Array, off: float) -> void:
	var tris := Geometry2D.triangulate_polygon(pts)
	if tris.is_empty():
		tris = _fan_indices(pts.size())
	var i := 0
	while i + 2 < tris.size():
		var p0 := pts[tris[i]]
		var p1 := pts[tris[i + 1]]
		var p2 := pts[tris[i + 2]]
		st.add_vertex(Vector3(p0.x, _ty(p0.x, p0.y, off), -p0.y))
		st.add_vertex(Vector3(p1.x, _ty(p1.x, p1.y, off), -p1.y))
		st.add_vertex(Vector3(p2.x, _ty(p2.x, p2.y, off), -p2.y))
		i += 3


func _add_ribbon(st: SurfaceTool, pts: PackedVector2Array, width: float, off: float) -> void:
	var hw := width * 0.5
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		if d.length() < 0.01:
			continue
		var nrm := Vector2(-d.y, d.x).normalized() * hw
		var a0 := _wv(a.x + nrm.x, a.y + nrm.y, off)
		var a1 := _wv(a.x - nrm.x, a.y - nrm.y, off)
		var b0 := _wv(b.x + nrm.x, b.y + nrm.y, off)
		var b1 := _wv(b.x - nrm.x, b.y - nrm.y, off)
		st.add_vertex(a0); st.add_vertex(a1); st.add_vertex(b1)
		st.add_vertex(a0); st.add_vertex(b1); st.add_vertex(b0)


## Vertice del mundo en coords de plano (x, yb) con altura de terreno + offset.
func _wv(x: float, yb: float, off: float) -> Vector3:
	return Vector3(x, _ty(x, yb, off), -yb)


func _add_prism(st: SurfaceTool, pts: PackedVector2Array, base_y: float, height: float, color: Color, roof: Color) -> void:
	var n := pts.size()
	var top := base_y + height
	for i in range(n):
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var a0 := Vector3(a.x, base_y, -a.y)
		var b0 := Vector3(b.x, base_y, -b.y)
		var a1 := Vector3(a.x, top, -a.y)
		var b1 := Vector3(b.x, top, -b.y)
		st.set_color(color)
		st.add_vertex(a0); st.add_vertex(b0); st.add_vertex(b1)
		st.add_vertex(a0); st.add_vertex(b1); st.add_vertex(a1)

	var tris := Geometry2D.triangulate_polygon(pts)
	if tris.is_empty():
		tris = _fan_indices(n)
	var i2 := 0
	while i2 + 2 < tris.size():
		var p0 := pts[tris[i2]]
		var p1 := pts[tris[i2 + 1]]
		var p2 := pts[tris[i2 + 2]]
		st.set_color(roof)
		st.add_vertex(Vector3(p0.x, top, -p0.y))
		st.add_vertex(Vector3(p1.x, top, -p1.y))
		st.add_vertex(Vector3(p2.x, top, -p2.y))
		i2 += 3


## Tejado inclinado sobre la huella (a partir de roof:shape real de OSM).
func _add_roof(st: SurfaceTool, pts: PackedVector2Array, top_y: float, color: Color, shape: String) -> void:
	var bb := _bounds(pts)
	var w := bb.size.x
	var d := bb.size.y
	if w < 2.0 or d < 2.0:
		return
	var rh := clampf(minf(w, d) * 0.32, 0.8, 3.2)
	var x0 := bb.position.x
	var y0 := bb.position.y
	var x1 := bb.position.x + w
	var y1 := bb.position.y + d
	var c0 := Vector3(x0, top_y, -y0)
	var c1 := Vector3(x1, top_y, -y0)
	var c2 := Vector3(x1, top_y, -y1)
	var c3 := Vector3(x0, top_y, -y1)
	st.set_color(color)
	if shape in ["hipped", "pyramidal", "round"]:
		var apex := Vector3((x0 + x1) * 0.5, top_y + rh, -(y0 + y1) * 0.5)
		_tri(st, c0, c1, apex)
		_tri(st, c1, c2, apex)
		_tri(st, c2, c3, apex)
		_tri(st, c3, c0, apex)
		return
	# A dos aguas: cumbrera a lo largo del eje mas largo.
	if d >= w:
		var cx := (x0 + x1) * 0.5
		var r0 := Vector3(cx, top_y + rh, -y0)
		var r1 := Vector3(cx, top_y + rh, -y1)
		_quad(st, c0, r0, r1, c3)   # faldon oeste
		_quad(st, c1, c2, r1, r0)   # faldon este
		_tri(st, c0, c1, r0)        # hastial norte
		_tri(st, c3, r1, c2)        # hastial sur
	else:
		var cy := (y0 + y1) * 0.5
		var s0 := Vector3(x0, top_y + rh, -cy)
		var s1 := Vector3(x1, top_y + rh, -cy)
		_quad(st, c0, c1, s1, s0)   # faldon norte
		_quad(st, c3, s0, s1, c2)   # faldon sur
		_tri(st, c0, s0, c3)        # hastial oeste
		_tri(st, c1, c2, s1)        # hastial este


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)


func _fan_indices(n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(1, n - 1):
		out.append(0); out.append(i); out.append(i + 1)
	return out


func _polygon_area(pts: PackedVector2Array) -> float:
	var area := 0.0
	var n := pts.size()
	for i in range(n):
		var a := pts[i]
		var b := pts[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	return absf(area) * 0.5


func _to_pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		if p is Array and (p as Array).size() >= 2:
			out.append(Vector2(float(p[0]), float(p[1])))
	return out


# --------------------------------------------------------------------------
# Punto de aparicion: vertice de calle mas cercano al centro
# --------------------------------------------------------------------------

func _compute_spawn(roads: Array) -> void:
	var best := INF
	var best_pt := Vector2.ZERO
	for r in roads:
		for p in r.get("pts", []):
			var v := Vector2(float(p[0]), float(p[1]))
			var d := v.length_squared()
			if d < best:
				best = d
				best_pt = v
	if best < INF:
		_spawn = Vector3(best_pt.x, Terrain.height_at_bp(best_pt.x, best_pt.y) + 1.0, -best_pt.y)
