extends Node3D
## Sonda temporal: mide modelos de AssetLibrary y valida animaciones.

func _ready() -> void:
	print("== PROBE ==")
	for gender in ["male", "female"]:
		var c := Assets.character("mini", gender, 0)
		add_child(c)
		print("mini/%s height=%.3f size=%s anim=%s walk=%s" % [
			gender, Assets.height_of(c), str(Assets.size_of(c)),
			str(Assets.find_animation_player(c) != null), str(Assets.play_anim(c, ["walk"]))])
	var b := Assets.character("blocky", "", 0)
	add_child(b)
	print("blocky height=%.3f size=%s anim=%s" % [Assets.height_of(b), str(Assets.size_of(b)), str(Assets.find_animation_player(b) != null)])

	for v in ["sedan", "suv", "van", "truck", "police", "taxi", "ambulance"]:
		var n := Assets.vehicle(v)
		if n == null:
			print("vehicle %s -> NULL" % v)
			continue
		add_child(n)
		print("vehicle %-9s size=%s" % [v, str(Assets.size_of(n))])

	for p in ["streetlight", "traffic_light", "tree_large", "tree_small", "dumpster", "cone", "planter", "sign_stop", "crossing", "awning"]:
		var n := Assets.prop(p)
		if n == null:
			print("prop %s -> NULL" % p)
			continue
		add_child(n)
		print("prop %-12s size=%s" % [p, str(Assets.size_of(n))])

	var boat := Assets.watercraft("boat")
	if boat != null:
		add_child(boat)
		print("watercraft boat size=%s" % str(Assets.size_of(boat)))

	print("audio footsteps=%d click=%d jingles=%d" % [
		Assets.streams("footsteps").size(), Assets.streams("click").size(), Assets.streams("jingles").size()])

	_dump_material(Assets.vehicle("sedan"), "sedan")
	_dump_material(Assets.character("mini", "male", 0), "male")
	_dump_material(Assets.character("blocky", "", 0), "blocky")
	print("== PROBE FIN ==")
	get_tree().quit()


func _collect(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect(c, out)


func _dump_material(node: Node, label: String) -> void:
	if node == null:
		print("[%s] null" % label)
		return
	var meshes: Array = []
	_collect(node, meshes)
	for m in meshes:
		var mi := m as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null:
			continue
		for s in range(mesh.get_surface_count()):
			var mat := mi.get_active_material(s)
			if mat == null:
				mat = mesh.surface_get_material(s)
			var info := "class=%s" % (mat.get_class() if mat != null else "NULL")
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				var tex := sm.albedo_texture
				info += " tex=%s vcol=%s albedo=%s" % [str(tex.resource_path if tex else "none"), str(sm.vertex_color_use_as_albedo), str(sm.albedo_color)]
			print("[%s] surf%d %s" % [label, s, info])
	return
