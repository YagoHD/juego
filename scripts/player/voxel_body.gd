class_name VoxelBody
## Cuerpo del personaje hecho de cubitos (la mitad de un píxel de skin, ~1,4 cm) en vez de cajas
## lisas: cada parte (cabeza, torso, brazos, piernas) se rellena de cubitos con el color de la skin
## y se le redondean las aristas, así el personaje es menos cuadrado. La capa exterior de la skin
## (pelo, ropa con volumen) son cubitos que sobresalen, con algún bulto al azar en el pelo.
## Mismas piezas y articulaciones que SkinModel: las animaciones no cambian.

## Cubitos por píxel de skin (la skin del náufrago va al doble: 2 = un cubito por píxel suyo).
const PER_PX := 2


## Malla de una caja de lo a hi (metros) rellena de cubitos con los colores de 'image' según los
## rectángulos de cada cara (en píxeles de una skin de 64). round_px: radio del redondeo de las
## aristas verticales (y de todas si round_all). overlay: solo la cáscara con color (pelo, ropa).
static func build(lo: Vector3, hi: Vector3, rects: Dictionary, image: Image, overlay: bool,
		round_px: float, round_all: bool, seed_offset: int) -> ArrayMesh:
	var vs := SkinModel.PIXEL / PER_PX
	var n := Vector3i(maxi(roundi((hi.x - lo.x) / vs), 1), maxi(roundi((hi.y - lo.y) / vs), 1),
		maxi(roundi((hi.z - lo.z) / vs), 1))
	var step := (hi - lo) / Vector3(n)
	var k := float(image.get_width()) / SkinModel.TEXTURE_SIZE
	var r := round_px * PER_PX
	var cells := {}
	for x in n.x:
		for y in n.y:
			for z in n.z:
				var p := Vector3i(x, y, z)
				var dx := mini(x, n.x - 1 - x)
				var dy := mini(y, n.y - 1 - y)
				var dz := mini(z, n.z - 1 - z)
				var shell := dx == 0 or dy == 0 or dz == 0
				if not shell:
					continue  # por dentro no hace falta
				if r > 0.0 and _cut_corner(dx, dy, dz, r, round_all):
					continue
				var face := _face_of(x, y, z, n, dx, dy, dz)
				var c := _sample(image, rects, face, x, y, z, n, k)
				if c.a < 0.5:
					continue
				c.a = 1.0
				cells[p] = c
				# Pelo de la capa exterior: algún mechón que sobresale un cubito más.
				if overlay and face != "bottom" and _hash(p, seed_offset) > 0.72:
					var out := p + _normal_of(face)
					cells[out] = c.lightened(0.05)
	# Las aristas redondeadas dejan huecos por dentro: se tapan con los vecinos de la cáscara.
	if r > 0.0 and not overlay:
		_fill_inside(cells, n)
	return _mesh(cells, lo, step)


static func _cut_corner(dx: int, dy: int, dz: int, r: float, round_all: bool) -> bool:
	# Distancia a la arista vertical (x-z); con round_all, también a las de arriba y abajo.
	var ax := maxf(r - dx - 0.5, 0.0)
	var az := maxf(r - dz - 0.5, 0.0)
	if ax * ax + az * az > r * r:
		return true
	if round_all:
		var ay := maxf(r - dy - 0.5, 0.0)
		if ax * ax + ay * ay > r * r or az * az + ay * ay > r * r:
			return true
	return false


static func _face_of(x: int, y: int, z: int, n: Vector3i, dx: int, dy: int, dz: int) -> String:
	var m := mini(dx, mini(dy, dz))
	if dz == m:
		return "front" if z < n.z - 1 - z else "back"
	if dx == m:
		return "right" if x > n.x - 1 - x else "left"
	return "top" if y > n.y - 1 - y else "bottom"


static func _normal_of(face: String) -> Vector3i:
	match face:
		"front": return Vector3i(0, 0, -1)
		"back": return Vector3i(0, 0, 1)
		"right": return Vector3i(1, 0, 0)
		"left": return Vector3i(-1, 0, 0)
		"top": return Vector3i(0, 1, 0)
	return Vector3i(0, -1, 0)


## Color de la skin para un cubito de una cara (las mismas orientaciones que SkinModel._box_mesh).
static func _sample(image: Image, rects: Dictionary, face: String, x: int, y: int, z: int, n: Vector3i, k: float) -> Color:
	var rect: Rect2 = rects[face]
	var fx := (x + 0.5) / n.x
	var fy := (y + 0.5) / n.y
	var fz := (z + 0.5) / n.z
	var u := 0.0
	var v := 0.0
	match face:
		"front":
			u = 1.0 - fx
			v = 1.0 - fy
		"back":
			u = fx
			v = 1.0 - fy
		"right":
			u = 1.0 - fz
			v = 1.0 - fy
		"left":
			u = fz
			v = 1.0 - fy
		"top":
			u = 1.0 - fx
			v = 1.0 - fz
		"bottom":
			u = 1.0 - fx
			v = fz
	var px := int((rect.position.x + u * rect.size.x) * k)
	var py := int((rect.position.y + v * rect.size.y) * k)
	return image.get_pixel(clampi(px, 0, image.get_width() - 1), clampi(py, 0, image.get_height() - 1))


static func _fill_inside(cells: Dictionary, n: Vector3i) -> void:
	# Cada cubito de la cáscara que quedó sin vecino hacia dentro recibe uno de su color, para que
	# por los huecos de las aristas no se vea el interior vacío.
	var extra := {}
	for p: Vector3i in cells:
		for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var q := p + d
			if q.x < 1 or q.z < 1 or q.x > n.x - 2 or q.z > n.z - 2:
				continue
			if not cells.has(q):
				extra[q] = (cells[p] as Color).darkened(0.1)
	for q: Vector3i in extra:
		cells[q] = extra[q]


static func _hash(p: Vector3i, s: int) -> float:
	var h: int = (p.x * 73856093) ^ (p.y * 19349663) ^ (p.z * 83492791) ^ (s * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xffff) / 65535.0


static func _mesh(cells: Dictionary, origin: Vector3, step: Vector3) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var dirs := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
	var corners := [
		[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
		[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)],
		[Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)],
		[Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)],
		[Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)],
		[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)],
	]
	for p: Vector3i in cells:
		var c: Color = cells[p]
		var base := origin + Vector3(p) * step
		for d in 6:
			if cells.has(p + dirs[d]):
				continue
			var quad: Array = corners[d]
			for i in [0, 2, 1, 0, 3, 2]:
				verts.append(base + (quad[i] as Vector3) * step)
				normals.append(Vector3(dirs[d]))
				colors.append(c)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	if verts.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
