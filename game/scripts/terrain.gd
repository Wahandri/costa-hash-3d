extends Node
## Terrain (autoload): relieve real de la zona a partir del grid DEM del blueprint.
## Coordenadas del plano (x=este, y=norte) en metros; el mundo usa (x, y, -y_plano).
## El punto mas bajo se normaliza a ~2 m (base) para que el suelo empiece en 0.

var nx: int = 0
var ny: int = 0
var x0: float = 0.0
var y0: float = 0.0
var sx: float = 1.0
var sy: float = 1.0
var base: float = 0.0
var is_ready: bool = false

var _h: PackedFloat32Array = PackedFloat32Array()


func configure(t: Dictionary) -> void:
	is_ready = false
	nx = int(t.get("nx", 0))
	ny = int(t.get("ny", 0))
	x0 = float(t.get("x0", 0.0))
	y0 = float(t.get("y0", 0.0))
	sx = float(t.get("step_x", 1.0))
	sy = float(t.get("step_y", 1.0))
	_h = PackedFloat32Array(t.get("h", []))
	if nx >= 2 and ny >= 2 and _h.size() >= nx * ny:
		is_ready = true
		var mn: float = _h[0]
		for v in _h:
			mn = minf(mn, v)
		base = mn - 2.0


func height_at_bp(x: float, yb: float) -> float:
	if not is_ready:
		return 0.0
	var fx := clampf((x - x0) / sx, 0.0, float(nx - 1))
	var fy := clampf((yb - y0) / sy, 0.0, float(ny - 1))
	var ix := clampi(int(floor(fx)), 0, nx - 2)
	var iy := clampi(int(floor(fy)), 0, ny - 2)
	var tx := fx - float(ix)
	var ty := fy - float(iy)
	var h00 := _h[iy * nx + ix]
	var h10 := _h[iy * nx + ix + 1]
	var h01 := _h[(iy + 1) * nx + ix]
	var h11 := _h[(iy + 1) * nx + ix + 1]
	var a := lerpf(h00, h10, tx)
	var b := lerpf(h01, h11, tx)
	return lerpf(a, b, ty) - base


func height_at_world(x: float, z: float) -> float:
	return height_at_bp(x, -z)


func span() -> Vector2:
	if not is_ready:
		return Vector2(600.0, 600.0)
	return Vector2(sx * (nx - 1), sy * (ny - 1))
