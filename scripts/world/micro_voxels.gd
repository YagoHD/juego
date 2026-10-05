class_name MicroVoxels
## Modelos hechos de cubitos pequeños (8 por bloque: unos 6 cm), como los del arte conceptual
## "posible": el barco naufragado, cajas, barriles, troncos... Un modelo es un diccionario
## Vector3i (posición del cubito) -> Color; build_mesh() lo convierte en una malla con solo las
## caras que se ven (las que dan a un hueco) y con el color de cada cubito en los vértices.

const RES := 8  # cubitos por bloque en cada lado


## Malla del modelo; size = medida de un cubito en metros.
static func build_mesh(cells: Dictionary, size: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var dirs := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
	# Esquinas de cada cara (en sentido contrario a las agujas del reloj visto desde fuera; los
	# triángulos van al revés, que es la cara de delante en Godot).
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
		var base := Vector3(p) * size
		for d in 6:
			if cells.has(p + dirs[d]):
				continue
			var n := Vector3(dirs[d])
			var quad: Array = corners[d]
			for k in [0, 2, 1, 0, 3, 2]:
				verts.append(base + (quad[k] as Vector3) * size)
				normals.append(n)
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


static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.92
	return m


## Nodo con el modelo y su choque (una caja por columna sería caro: se usa la malla tal cual).
static func make_node(cells: Dictionary, size: float, with_collision := true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = build_mesh(cells, size)
	node.material_override = material()
	if with_collision and node.mesh.get_surface_count() > 0:
		node.create_trimesh_collision()
	return node


# ------------------------------------------------------------------ piezas sencillas

## Variación de tono de un cubito (pintado a mano: cada uno un pelín distinto).
static func jitter(c: Color, p: Vector3i, amount := 0.06) -> Color:
	var h: int = (p.x * 73856093) ^ (p.y * 19349663) ^ (p.z * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	var n := float(h & 0xff) / 255.0 - 0.5
	return c.lightened(n * amount * 2.0) if n > 0.0 else c.darkened(-n * amount * 2.0)


static func hash01(p: Vector3i) -> float:
	var h: int = (p.x * 92837111) ^ (p.y * 689287499) ^ (p.z * 283923481)
	h = (h ^ (h >> 15)) * 2246822519
	return float(h & 0xffff) / 65535.0


## Caja de tablones con cantoneras oscuras (size en cubitos).
static func crate(size: Vector3i, wood: Color) -> Dictionary:
	var cells := {}
	for x in size.x:
		for y in size.y:
			for z in size.z:
				var edge := int(x == 0 or x == size.x - 1) + int(y == 0 or y == size.y - 1) + int(z == 0 or z == size.z - 1)
				if edge == 0:
					continue  # hueca por dentro
				var p := Vector3i(x, y, z)
				var c := wood
				if edge >= 2:
					c = wood.darkened(0.35)  # cantoneras
				elif y % 4 == 0:
					c = wood.darkened(0.22)  # junta entre tablas
				cells[p] = jitter(c, p, 0.08)
	return cells


## Barril: cilindro con flejes de hierro.
static func barrel(radius: float, height: int, wood: Color) -> Dictionary:
	var cells := {}
	var iron := Color(0.28, 0.27, 0.27)
	var r := int(ceil(radius)) + 1
	for y in height:
		var bulge := radius + 0.9 * sin(PI * float(y) / float(height - 1))
		for x in range(-r - 1, r + 2):
			for z in range(-r - 1, r + 2):
				var d := sqrt(float(x * x + z * z))
				var p := Vector3i(x, y, z)
				if d > bulge:
					continue
				if d < bulge - 1.5 and y > 0 and y < height - 1:
					continue
				var hoop := y == 2 or y == height - 3 or y == height / 2
				var c := iron if hoop and d > bulge - 1.5 else wood
				if not hoop and (int(atan2(float(z), float(x)) * 4.0) % 2 == 0):
					c = c.darkened(0.08)  # duelas
				cells[p] = jitter(c, p, 0.07)
	return cells


## Tronco tumbado a lo largo de X con corteza y anillos en las puntas.
static func log_x(length: int, radius: float, bark: Color, core: Color) -> Dictionary:
	var cells := {}
	var r := int(ceil(radius))
	for x in length:
		for y in range(-r, r + 1):
			for z in range(-r, r + 1):
				var d := sqrt(float(y * y + z * z))
				if d > radius:
					continue
				var p := Vector3i(x, y + r, z)
				var end := x == 0 or x == length - 1
				var c: Color
				if end:
					c = core.darkened(0.18) if int(d) % 2 == 0 else core  # anillos
					if d > radius - 1.0:
						c = bark
				else:
					c = bark if d > radius - 1.2 else core
				cells[p] = jitter(c, p, 0.1)
	return cells


## Tabla suelta a lo largo de X (algo combada y con una punta rota).
static func plank(length: int, wood: Color) -> Dictionary:
	var cells := {}
	var broken := 3 + int(hash01(Vector3i(length, 1, 2)) * 5.0)
	for x in length:
		var bend := int(1.5 * sin(PI * float(x) / length))
		for z in 5:
			if x > length - broken and z > 4 - (x - (length - broken)):
				continue  # punta astillada
			for y in 2:
				var p := Vector3i(x, y + bend, z)
				var c := wood.darkened(0.2) if (y == 1 and (x % 9 == 0)) else wood
				cells[p] = jitter(c, p, 0.09)
	return cells


## Montón de tablas cruzadas.
static func plank_pile(wood: Color) -> Dictionary:
	var cells := {}
	for i in 4:
		var board := plank(26 + i * 4, wood.lerp(Color(0.35, 0.3, 0.25), 0.15 * i))
		var angle := (i * 0.9) - 1.3
		for p: Vector3i in board:
			var v := Vector2(p.x - 14, p.z - 2).rotated(angle)
			var q := Vector3i(roundi(v.x), p.y + i * 2, roundi(v.y))
			cells[q] = board[p]
	return cells


## Tela de vela tirada en la arena, arrugada y con un borde roto.
static func cloth(size: Vector2i, color: Color) -> Dictionary:
	var cells := {}
	for x in size.x:
		for z in size.y:
			var edge := mini(mini(x, size.x - 1 - x), mini(z, size.y - 1 - z))
			if edge == 0 and hash01(Vector3i(x, 0, z)) > 0.55:
				continue
			var y := int(1.6 * (sin(x * 0.35) + cos(z * 0.45 + x * 0.1)) + 1.6)
			var p := Vector3i(x, y, z)
			var c := color if hash01(Vector3i(x / 3, 1, z / 3)) < 0.8 else color.darkened(0.15)
			cells[p] = jitter(c, p, 0.04)
	return cells
