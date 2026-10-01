extends Node
## Luces de vehiculo: pilotos emisivos (delante/detras) y, opcionalmente, foco.
## Se encienden de noche. Helpers estaticos: CarLights.attach(...) / set_night(...).


static func attach(parent: Node3D, size: Vector3, with_spot: bool) -> Dictionary:
	var head_mat := _emissive(Color("fff2c0"))
	var tail_mat := _emissive(Color("ff3b30"))
	var data := {"mats": [head_mat, tail_mat], "spot": null}
	var zf := -size.z * 0.5
	var zb := size.z * 0.5
	var y := maxf(size.y * 0.45, 0.35)
	var x := size.x * 0.34
	for sx in [-1.0, 1.0]:
		_add_sphere(parent, Vector3(sx * x, y, zf), 0.13, head_mat)
		_add_sphere(parent, Vector3(sx * x, y, zb), 0.11, tail_mat)
	if with_spot:
		var spot := SpotLight3D.new()
		spot.position = Vector3(0, y + 0.1, zf)
		spot.rotation_degrees = Vector3(-7, 0, 0)
		spot.spot_range = 38.0
		spot.spot_angle = 38.0
		spot.light_energy = 0.0
		spot.shadow_enabled = false
		parent.add_child(spot)
		data["spot"] = spot
	return data


static func set_night(data: Dictionary, on: bool) -> void:
	if data.is_empty():
		return
	for m in data.get("mats", []):
		(m as StandardMaterial3D).emission_energy_multiplier = 2.6 if on else 0.0
	var spot = data.get("spot", null)
	if spot != null and is_instance_valid(spot):
		(spot as SpotLight3D).light_energy = 3.5 if on else 0.0


static func _emissive(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _add_sphere(parent: Node3D, pos: Vector3, r: float, mat: StandardMaterial3D) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
