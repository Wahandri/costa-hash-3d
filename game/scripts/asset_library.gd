extends Node
## AssetLibrary (autoload "Assets") - libreria central de modelos 3D, props y audio.
##
## Todos los assets son CC0 (Kenney) y se reutilizan desde aqui: personajes,
## vehiculos, mobiliario urbano, barca y sonidos. Ver game/assets/CREDITS.md y
## game/assets/assets_manifest.json.
##
## Las escenas se cargan de forma perezosa y se cachean (PackedScene), de modo que
## instanciar el mismo modelo muchas veces es barato (el recurso se comparte).

const MANIFEST_PATH := "res://game/assets/assets_manifest.json"

var _manifest: Dictionary = {}
var _scenes: Dictionary = {}   ## path -> PackedScene
var _streams: Dictionary = {}  ## path -> AudioStream
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var txt := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		_manifest = parsed
	else:
		push_error("Assets: no se pudo cargar el manifest (%s)" % MANIFEST_PATH)


func _base() -> String:
	return str(_manifest.get("base", "res://game/assets/"))


# --------------------------------------------------------------------------
# Carga con cache
# --------------------------------------------------------------------------

func _scene(rel_path: String) -> PackedScene:
	if rel_path.is_empty():
		return null
	var full := _base() + rel_path
	if _scenes.has(full):
		return _scenes[full]
	if not ResourceLoader.exists(full):
		push_warning("Assets: recurso no encontrado -> %s" % full)
		_scenes[full] = null
		return null
	var ps := load(full) as PackedScene
	_scenes[full] = ps
	return ps


func has_resource(rel_path: String) -> bool:
	return ResourceLoader.exists(_base() + rel_path)


# --------------------------------------------------------------------------
# Instanciacion generica
# --------------------------------------------------------------------------

func _spawn(rel_path: String) -> Node3D:
	var ps := _scene(rel_path)
	if ps == null:
		return null
	var node := ps.instantiate()
	if node is Node3D:
		_prepare(node as Node3D)
		return node as Node3D
	node.queue_free()
	return null


func _prepare(node: Node3D) -> void:
	# Sombras y materiales coherentes en todos los modelos importados.
	_set_shadow(node, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


func _set_shadow(node: Node, mode: int) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = mode
	for c in node.get_children():
		_set_shadow(c, mode)


# --------------------------------------------------------------------------
# Personajes
# --------------------------------------------------------------------------

## Estilo: "mini" (skinned) o "blocky" (ligero). gender: "male"/"female"/"".
func character(style: String = "mini", gender: String = "", index: int = -1) -> Node3D:
	var list: Array = []
	var folder := "characters/mini/"
	if style == "blocky":
		folder = "characters/blocky/"
		list = _manifest.get("characters", {}).get("blocky", [])
	else:
		if gender == "female":
			list = _manifest.get("characters", {}).get("mini_female", [])
		elif gender == "male":
			list = _manifest.get("characters", {}).get("mini_male", [])
		else:
			# cualquiera de los dos
			list = _manifest.get("characters", {}).get("mini_male", []) + _manifest.get("characters", {}).get("mini_female", [])
	if list.is_empty():
		return null
	var name := str(list[index % list.size()]) if index >= 0 else str(list[_rng.randi_range(0, list.size() - 1)])
	var node := _spawn(folder + name + ".glb")
	if node != null:
		node.set_meta("asset_id", name)
		_neutralize_root_motion(node)
	return node


## Quita las pistas de translacion de las animaciones (los clips de Kenney traen
## "root motion", que hacia que el personaje se deslizara del cuerpo fisico).
func _neutralize_root_motion(node: Node) -> void:
	var ap := find_animation_player(node)
	if ap == null:
		return
	for an in ap.get_animation_list():
		var a := ap.get_animation(an)
		if a == null:
			continue
		var i := a.get_track_count() - 1
		while i >= 0:
			if a.track_get_type(i) == Animation.TYPE_POSITION_3D:
				a.remove_track(i)
			i -= 1


## Numero de variantes de personaje (mini o blocky).
func character_count(style: String = "mini", gender: String = "") -> int:
	var c: Dictionary = _manifest.get("characters", {})
	if style == "blocky":
		return (c.get("blocky", []) as Array).size()
	if gender == "female":
		return (c.get("mini_female", []) as Array).size()
	if gender == "male":
		return (c.get("mini_male", []) as Array).size()
	return (c.get("mini_male", []) as Array).size() + (c.get("mini_female", []) as Array).size()


# --------------------------------------------------------------------------
# Vehiculos / barca
# --------------------------------------------------------------------------

func vehicle(name: String = "sedan") -> Node3D:
	var file := str(_manifest.get("vehicles", {}).get(name, ""))
	if file.is_empty():
		return null
	return _spawn("vehicles/%s.glb" % file)


## Moto antigua procedimental (reutilizable, mismo estilo low-poly). Mira a -Z.
func motorcycle() -> Node3D:
	var root := Node3D.new()
	root.name = "Motorcycle"
	var dark := _pmat(Color("14161c"), 0.55)
	var body := _pmat(Color("7c2419"), 0.6)
	var chrome := _pmat(Color("b9c1c9"), 0.28)
	var seat := _pmat(Color("201b17"), 0.85)
	var lamp := _pmat(Color("fff3c4"), 0.2, true)
	# Ruedas
	_pwheel(root, Vector3(0, 0.32, -0.72), 0.32, dark)
	_pwheel(root, Vector3(0, 0.32, 0.72), 0.32, dark)
	# Chasis / deposito / asiento
	_pbox(root, Vector3(0, 0.6, 0.02), Vector3(0.15, 0.34, 1.0), body)
	_pbox(root, Vector3(0, 0.82, -0.2), Vector3(0.26, 0.26, 0.58), body)
	_pbox(root, Vector3(0, 0.88, 0.42), Vector3(0.24, 0.1, 0.5), seat)
	# Horquilla + manillar + faro
	var fork := _pbox(root, Vector3(0, 0.72, -0.6), Vector3(0.1, 0.72, 0.1), chrome)
	fork.rotation_degrees.x = 22.0
	_pbox(root, Vector3(0, 1.02, -0.48), Vector3(0.6, 0.06, 0.06), chrome)
	_psphere(root, Vector3(0, 0.96, -0.62), 0.13, lamp)
	# Escape y guardabarros
	_pbox(root, Vector3(0.18, 0.36, 0.34), Vector3(0.08, 0.08, 0.9), chrome)
	_pbox(root, Vector3(0, 0.52, 0.72), Vector3(0.22, 0.05, 0.5), dark)
	_set_shadow(root, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	return root


func _pmat(c: Color, rough: float, emissive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emissive:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.4
	return m


func _pbox(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _psphere(parent: Node3D, pos: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _pwheel(parent: Node3D, pos: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.12
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = Vector3(0, 0, 90)
	parent.add_child(mi)
	return mi


func watercraft(name: String = "boat") -> Node3D:
	var file := str(_manifest.get("watercraft", {}).get(name, ""))
	if file.is_empty():
		return null
	return _spawn("watercraft/%s.glb" % file)


## Lista de claves de vehiculos disponibles.
func vehicle_names() -> Array:
	return (_manifest.get("vehicles", {}) as Dictionary).keys()


# --------------------------------------------------------------------------
# Mobiliario urbano / landmarks
# --------------------------------------------------------------------------

func prop(name: String) -> Node3D:
	var file := str(_manifest.get("props", {}).get(name, ""))
	if file.is_empty():
		return null
	return _spawn("%s.glb" % file)


func landmark(name: String) -> Node3D:
	var file := str(_manifest.get("landmarks", {}).get(name, ""))
	if file.is_empty():
		return null
	return _spawn("%s.glb" % file)


# --------------------------------------------------------------------------
# Audio
# --------------------------------------------------------------------------

func stream(id: String) -> AudioStream:
	var full := _base() + "audio/" + id + ".ogg"
	if _streams.has(full):
		return _streams[full]
	if not ResourceLoader.exists(full):
		push_warning("Assets: audio no encontrado -> %s" % full)
		_streams[full] = null
		return null
	var s := load(full) as AudioStream
	_streams[full] = s
	return s


## Lista de AudioStream de un grupo ("footsteps", "impact", "click", "jingles").
func streams(key: String) -> Array:
	var group: Variant = _manifest.get("audio", {}).get(key, [])
	var out: Array = []
	if group is Array:
		for id in group:
			var s := stream(str(id))
			if s != null:
				out.append(s)
	elif group is String:
		var s := stream(group)
		if s != null:
			out.append(s)
	return out


func random_stream(key: String) -> AudioStream:
	var list := streams(key)
	if list.is_empty():
		return null
	return list[_rng.randi_range(0, list.size() - 1)]


# --------------------------------------------------------------------------
# Utilidades de animacion y medidas
# --------------------------------------------------------------------------

func find_animation_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var ap := find_animation_player(c)
		if ap != null:
			return ap
	return null


## Reproduce la primera animacion disponible de la lista. Devuelve true si pudo.
## `blend` = tiempo de mezcla (crossfade) para transiciones suaves.
func play_anim(node: Node, names: Array, loop: bool = true, blend: float = 0.2) -> bool:
	var ap := find_animation_player(node)
	if ap == null:
		return false
	for n in names:
		var name := str(n)
		if ap.has_animation(name):
			if ap.current_animation == name and ap.is_playing():
				return true
			var anim := ap.get_animation(name)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			ap.play(name, blend)
			return true
	return false


## Ajusta la velocidad de reproduccion (evita el "patinaje" de pies).
func anim_speed(node: Node, scale: float) -> void:
	var ap := find_animation_player(node)
	if ap != null:
		ap.speed_scale = clampf(scale, 0.3, 2.5)


## Crea un AnimationTree de locomocion (BlendSpace1D idle/walk/sprint) sobre el
## AnimationPlayer del personaje. Permite transiciones suaves sin "tic".
func enable_locomotion(node: Node) -> bool:
	if node == null or node.has_meta("loco_tree"):
		return node != null and node.has_meta("loco_tree")
	var ap := find_animation_player(node)
	if ap == null:
		return false
	var pos := {"idle": 0.0, "walk": 0.5, "sprint": 1.0}
	var bs := AnimationNodeBlendSpace1D.new()
	bs.min_space = 0.0
	bs.max_space = 1.0
	var count := 0
	for n in ["idle", "walk", "sprint"]:
		if ap.has_animation(n):
			var an := AnimationNodeAnimation.new()
			an.animation = n
			bs.add_blend_point(an, float(pos[n]), -1, StringName(n))
			count += 1
	if count == 0:
		return false
	var tree := AnimationNodeBlendTree.new()
	tree.add_node("loco", bs, Vector2.ZERO)
	tree.connect_node("output", 0, "loco")
	var at := AnimationTree.new()
	at.name = "LocoTree"
	at.tree_root = tree
	node.add_child(at)
	at.anim_player = at.get_path_to(ap)
	at.active = true
	at.set("parameters/loco/blend_position", 0.0)
	node.set_meta("loco_tree", at)
	return true


## Fija la mezcla de locomocion (0=parado, 0.5=andar, 1=correr). Con respaldo a
## clips sueltos si no hay AnimationTree.
func set_locomotion(node: Node, t: float) -> void:
	if node == null:
		return
	t = clampf(t, 0.0, 1.0)
	if node.has_meta("loco_tree"):
		var at = node.get_meta("loco_tree")
		if is_instance_valid(at):
			(at as AnimationTree).active = true
			at.set("parameters/loco/blend_position", t)
			return
	var want := "idle"
	if t >= 0.75:
		want = "sprint"
	elif t > 0.05:
		want = "walk"
	play_anim(node, [want, "walk", "idle"], true, 0.18)


## Activa/desactiva el arbol de locomocion (para gestos: sit/drive/emotes).
func set_locomotion_active(node: Node, on: bool) -> void:
	if node != null and node.has_meta("loco_tree"):
		var at = node.get_meta("loco_tree")
		if is_instance_valid(at):
			(at as AnimationTree).active = on


func stop_anim(node: Node) -> void:
	var ap := find_animation_player(node)
	if ap != null:
		ap.stop()


## Altura (eje Y) del modelo instanciado.
func height_of(node: Node3D) -> float:
	return _aabb(node).size.y


## Tamano (AABB) del modelo instanciado.
func size_of(node: Node3D) -> Vector3:
	return _aabb(node).size


## AABB combinada (en mundo) de todos los MeshInstance3D del nodo.
func _aabb(node: Node3D) -> AABB:
	var out := AABB()
	var init := false
	for m in _meshes(node):
		var mi := m as MeshInstance3D
		var local := mi.get_aabb()
		var xf := mi.global_transform
		for i in range(8):
			var p := xf * local.get_endpoint(i)
			if not init:
				out = AABB(p, Vector3.ZERO)
				init = true
			else:
				out = out.expand(p)
	return out


func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out


## Escala el nodo para que mida `target_h` de alto. Devuelve el factor aplicado.
func fit_height(node: Node3D, target_h: float) -> float:
	var h := height_of(node)
	if h <= 0.001:
		return 1.0
	var f := target_h / h
	node.scale = node.scale * f
	return f


## Escala el nodo para que mida `target_z` de largo (eje Z). Devuelve el factor.
func fit_length(node: Node3D, target_z: float) -> float:
	var l := size_of(node).z
	if l <= 0.001:
		return 1.0
	var f := target_z / l
	node.scale = node.scale * f
	return f


## Coordenada Y minima (mundo) del modelo; util para apoyarlo en el suelo.
func min_y(node: Node3D) -> float:
	return _aabb(node).position.y


## AABB local (ignora la transformada del propio nodo raiz).
func _local_aabb(node: Node) -> AABB:
	var out := AABB()
	var init := false
	for m in _meshes(node):
		var mi := m as MeshInstance3D
		var local := mi.get_aabb()
		var xf := mi.transform
		for i in range(8):
			var p := xf * local.get_endpoint(i)
			if not init:
				out = AABB(p, Vector3.ZERO)
				init = true
			else:
				out = out.expand(p)
	return out


## Crea un MultiMeshInstance3D por malla del prop, instanciado en `transforms`.
## `target_height` (m) normaliza la altura del prop (0 = sin normalizar).
## Devuelve un Node3D contenedor (o null si el prop no existe).
func build_scatter(key: String, transforms: Array, target_height: float = 0.0) -> Node3D:
	var proto := prop(key)
	if proto == null or transforms.is_empty():
		if proto != null:
			proto.free()
		return null
	var aabb := _local_aabb(proto)
	var s := 1.0
	if target_height > 0.0 and aabb.size.y > 0.001:
		s = target_height / aabb.size.y
	var base := Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(0, -aabb.position.y * s, 0))

	var holder := Node3D.new()
	holder.name = "Scatter_" + key
	for m in _meshes(proto):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = transforms.size()
		var child := mi.transform
		for i in range(transforms.size()):
			var t: Transform3D = transforms[i]
			mm.set_instance_transform(i, t * base * child)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		holder.add_child(mmi)
	proto.free()
	return holder


## Tinta los materiales clonados de un nodo (variacion de color por NPC/vehiculo).
func tint(node: Node, color: Color, amount: float = 0.5) -> void:
	for m in _meshes(node):
		var mi := m as MeshInstance3D
		var mat := mi.get_active_material(0)
		if mat is StandardMaterial3D:
			var new_mat := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			new_mat.albedo_color = (mat as StandardMaterial3D).albedo_color.lerp(color, amount)
			mi.material_override = new_mat
		elif mat is BaseMaterial3D:
			var new_mat2 := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			new_mat2.albedo_color = (mat as BaseMaterial3D).albedo_color.lerp(color, amount)
			mi.material_override = new_mat2
