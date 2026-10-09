extends RefCounted
class_name PlacesBuilder
## Los lugares sueltos del mapa beta1 (docs/mapa_isla/MIGRACION_BETA.md), de bloques: faros,
## atalayas, ruinas de los antiguos y minas. Lo estampa Structures. Coordenadas en metros.

const LIGHTHOUSES := [Vector2(-213, 10), Vector2(-178, -107), Vector2(-213, 206)]
const WATCHTOWERS := [Vector2(-34, -85), Vector2(72, 96)]
## Ruinas: [centro, tamaño (m), con altar]. El templo del bosque, las del noreste y la de la playa.
const RUINS := [[Vector2(10, 19), Vector2(14, 10), true], [Vector2(198, -106), Vector2(9, 7), false],
	[Vector2(-57, 154), Vector2(6, 5), false]]
## Minas: [boca (m), largo de la galería (m), de Bermudo]. La de Bermudo, en la montaña (G5).
const MINES := [[Vector2(158, 40), 22.0, true], [Vector2(17, -128), 9.0, false], [Vector2(207, -85), 9.0, false],
	[Vector2(138, 108), 9.0, false], [Vector2(46, 189), 9.0, false]]


## Zonas sin árboles ni rocas: [centro (voxels), radio (voxels)].
static func clear_zones() -> Array:
	var out: Array = []
	for p: Vector2 in LIGHTHOUSES + WATCHTOWERS:
		out.append([p * 2.0, 12.0])
	for r: Array in RUINS:
		out.append([(r[0] as Vector2) * 2.0, (r[1] as Vector2).length() + 6.0])
	for m: Array in MINES:
		out.append([(m[0] as Vector2) * 2.0, 10.0])
	return out


## Levanta todo. Devuelve los puntos de luz (faros, voxels) para que main.gd ponga sus lámparas.
static func build(gen: IslandGenerator, put: Callable) -> Array:
	var lights: Array = []
	for p: Vector2 in LIGHTHOUSES:
		lights.append(_lighthouse(gen, put, p * 2.0))
	for p: Vector2 in WATCHTOWERS:
		_watchtower(gen, put, p * 2.0)
	for i in RUINS.size():
		_ruin(gen, put, RUINS[i][0] * 2.0, RUINS[i][1] * 2.0, RUINS[i][2], i)
	for m: Array in MINES:
		_mine(gen, put, (m[0] as Vector2) * 2.0, float(m[1]) * 2.0, bool(m[2]))
	return lights


## Faro: torre de piedra de 3 x 3 m con escalera de caracol dentro, balcón de tablones arriba y
## la linterna (la luz la pone main.gd). Devuelve dónde va la luz.
static func _lighthouse(gen: IslandGenerator, put: Callable, at: Vector2) -> Vector3i:
	var x0 := int(at.x) - 3
	var z0 := int(at.y) - 3
	var base := VillageBuilder._level(gen, put, x0, z0, 6, 6, 4)
	var height := 26
	var ring := _ring(6)
	for y in height:
		for c: Vector2i in _square(6):
			var edge := c.x == 0 or c.x == 5 or c.y == 0 or c.y == 5
			var id := IslandGenerator.STONE if edge else IslandGenerator.AIR
			if edge and c.x in [2, 3] and c.y == 5 and y < 4:
				id = IslandGenerator.AIR  # la puerta
			if edge and (y / 3) % 2 == 1 and y % 3 == 0 and (c.x == 0 or c.x == 5) and c.y in [2, 3]:
				id = IslandGenerator.AIR  # ventanucos
			if y % 8 >= 6 and edge and not (c.x in [0, 5] and c.y in [0, 5]):
				id = IslandGenerator.MOSSY_STONE if id != IslandGenerator.AIR else id  # franjas
			put.call(Vector3i(x0 + c.x, base + y, z0 + c.y), id)
		# Escalera de caracol: un peldaño por altura dando vueltas por dentro.
		var step: Vector2i = ring[y % ring.size()]
		put.call(Vector3i(x0 + 1 + step.x, base + y, z0 + 1 + step.y), IslandGenerator.PLANKS)
	# Balcón y linterna (con el hueco por donde llega la escalera).
	var hole := _stair_hole(ring, height)
	for x in range(-1, 7):
		for z in range(-1, 7):
			if not hole.has(Vector2i(x, z)):
				put.call(Vector3i(x0 + x, base + height, z0 + z), IslandGenerator.PLANKS)
			if x == -1 or x == 6 or z == -1 or z == 6:
				put.call(Vector3i(x0 + x, base + height + 1, z0 + z), IslandGenerator.SLAB_DOWN)
	# La linterna, de 3 x 3 en la esquina contraria a la llegada de la escalera.
	for y in range(1, 5):
		for c: Vector2i in _square(3):
			var corner := (c.x == 0 or c.x == 2) and (c.y == 0 or c.y == 2)
			put.call(Vector3i(x0 + 2 + c.x, base + height + y, z0 + 2 + c.y), IslandGenerator.WOOD if corner else IslandGenerator.AIR)
	for c: Vector2i in _square(3):
		put.call(Vector3i(x0 + 2 + c.x, base + height + 5, z0 + 2 + c.y), IslandGenerator.DEAD_WOOD)
	return Vector3i(x0 + 3, base + height + 2, z0 + 3)


## Atalaya de madera: cuatro troncos, escalera de tablones por dentro y plataforma con barandilla.
static func _watchtower(gen: IslandGenerator, put: Callable, at: Vector2) -> void:
	var x0 := int(at.x) - 3
	var z0 := int(at.y) - 3
	var base := VillageBuilder._level(gen, put, x0, z0, 6, 6, 4)
	var height := 16
	var ring := _ring(6)
	for y in height:
		for c: Vector2i in [Vector2i(0, 0), Vector2i(5, 0), Vector2i(0, 5), Vector2i(5, 5)]:
			put.call(Vector3i(x0 + c.x, base + y, z0 + c.y), IslandGenerator.WOOD)
		var step: Vector2i = ring[y % ring.size()]
		put.call(Vector3i(x0 + 1 + step.x, base + y, z0 + 1 + step.y), IslandGenerator.PLANKS)
		if y % 6 == 5:  # tirantes en cruz
			for k in range(1, 5):
				put.call(Vector3i(x0 + k, base + y, z0), IslandGenerator.WOOD)
				put.call(Vector3i(x0 + k, base + y, z0 + 5), IslandGenerator.WOOD)
	var hole := _stair_hole(ring, height)  # por donde se sube
	for c: Vector2i in _square(6):
		var edge := c.x == 0 or c.x == 5 or c.y == 0 or c.y == 5
		if not hole.has(c):
			put.call(Vector3i(x0 + c.x, base + height, z0 + c.y), IslandGenerator.PLANKS)
		if edge:
			put.call(Vector3i(x0 + c.x, base + height + 1, z0 + c.y), IslandGenerator.SLAB_DOWN)
	# Tejadillo sobre cuatro postes.
	for c: Vector2i in [Vector2i(0, 0), Vector2i(5, 0), Vector2i(0, 5), Vector2i(5, 5)]:
		for y in range(1, 5):
			put.call(Vector3i(x0 + c.x, base + height + y, z0 + c.y), IslandGenerator.WOOD)
	for j in 3:
		for x in range(j - 1, 7 - j):
			for z in range(j - 1, 7 - j):
				put.call(Vector3i(x0 + x, base + height + 5 + j, z0 + z), IslandGenerator.DRIFTWOOD)


## Ruina de los antiguos: un patio de losas con columnas rotas, restos de muro y, en el templo, un
## altar en medio.
static func _ruin(gen: IslandGenerator, put: Callable, at: Vector2, size: Vector2, altar: bool, seed: int) -> void:
	var w := int(size.x)
	var d := int(size.y)
	var x0 := int(at.x) - w / 2
	var z0 := int(at.y) - d / 2
	var base := VillageBuilder._level(gen, put, x0, z0, w, d, 3)
	for x in w:
		for z in d:
			var h := _hash(x, z, seed)
			put.call(Vector3i(x0 + x, base - 1, z0 + z), IslandGenerator.MOSSY_STONE if h < 0.35 else IslandGenerator.STONE)
			var edge := x == 0 or x == w - 1 or z == 0 or z == d - 1
			var column := x % 4 == 1 and z % 4 == 1 and not edge
			if column or (edge and h < 0.45):
				var top := int(1 + _hash(x, z, seed + 9) * (10 if column else 4))
				for y in top:
					put.call(Vector3i(x0 + x, base + y, z0 + z), IslandGenerator.MOSSY_STONE if _hash(x, y, seed + z) < 0.4 else IslandGenerator.STONE)
	if altar:
		for x in range(-1, 2):
			for z in range(-1, 1):
				put.call(Vector3i(x0 + w / 2 + x, base, z0 + d / 2 + z), IslandGenerator.STONE)
				put.call(Vector3i(x0 + w / 2 + x, base + 1, z0 + d / 2 + z), IslandGenerator.SLAB_DOWN)


## Mina: boca con marco de troncos en la ladera y una galería recta hacia dentro del monte, con
## marcos cada 2 m y vetas de mineral en las paredes. La de Bermudo acaba en un derrumbe.
static func _mine(gen: IslandGenerator, put: Callable, at: Vector2, length: float, bermudo: bool) -> void:
	# Hacia dentro: cuesta arriba (hacia donde sube el terreno).
	var best := Vector2.RIGHT
	var best_rise := -1000
	for k in 16:
		var dir := Vector2.from_angle(k * TAU / 16.0)
		var rise := gen.get_ground_height(int(at.x + dir.x * 12), int(at.y + dir.y * 12)) - gen.get_ground_height(int(at.x), int(at.y))
		if rise > best_rise:
			best_rise = rise
			best = dir
	var side := best.orthogonal()
	var floor_y := gen.get_ground_height(int(at.x), int(at.y))
	var n := int(length)
	for k in range(-3, n):
		for s in range(-2, 2):
			var p := at + best * float(k) + side * (float(s) + 0.5)
			var cx := floori(p.x)
			var cz := floori(p.y)
			put.call(Vector3i(cx, floor_y - 1, cz), IslandGenerator.GRAVEL if k >= 0 else IslandGenerator.DIRT)
			for y in 5:
				put.call(Vector3i(cx, floor_y + y, cz), IslandGenerator.AIR)
			var frame := k >= 0 and k % 4 == 0
			if frame and (s == -2 or s == 1):
				for y in 5:
					put.call(Vector3i(cx, floor_y + y, cz), IslandGenerator.WOOD)
			if frame:
				put.call(Vector3i(cx, floor_y + 4, cz), IslandGenerator.WOOD)
			# Vetas en las paredes (un bloque más allá del borde).
			if k > 2 and (s == -2 or s == 1) and _hash(k, s, int(at.x)) < 0.25:
				var out := side * (-1.0 if s == -2 else 1.0)
				var wall := p + out
				put.call(Vector3i(floori(wall.x), floor_y + 1 + int(_hash(k, s, 3) * 3.0), floori(wall.y)), IslandGenerator.ORE)
	if bermudo:
		# El derrumbe: piedras y grava cerrando la galería del brillo.
		for k in range(n - 4, n):
			for s in range(-2, 2):
				var p := at + best * float(k) + side * (float(s) + 0.5)
				for y in 5:
					if _hash(k * 5 + y, s, 41) < 0.85 - y * 0.1:
						put.call(Vector3i(floori(p.x), floor_y + y, floori(p.y)), IslandGenerator.GRAVEL if (k + y) % 3 == 0 else IslandGenerator.STONE)


static func _square(n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in n:
		for z in n:
			out.append(Vector2i(x, z))
	return out


## Recorrido de la escalera de caracol por dentro de una torre de n x n (n - 2 de hueco).
static func _ring(n: int) -> Array[Vector2i]:
	var m := n - 2
	var out: Array[Vector2i] = []
	for x in m:
		out.append(Vector2i(x, 0))
	for z in range(1, m):
		out.append(Vector2i(m - 1, z))
	for x in range(m - 2, -1, -1):
		out.append(Vector2i(x, m - 1))
	for z in range(m - 2, 0, -1):
		out.append(Vector2i(0, z))
	return out


## Las celdas del suelo de arriba (en la torre de n x n, desde su esquina) que quedan sobre los
## últimos peldaños: ahí no se pone suelo, para poder subir.
static func _stair_hole(ring: Array[Vector2i], height: int) -> Dictionary:
	var hole := {}
	for k in range(1, 6):  # los últimos peldaños y uno más: el personaje mide 3 bloques
		hole[ring[(height - k) % ring.size()] + Vector2i(1, 1)] = true
	return hole


static func _hash(x: int, z: int, salt: int) -> float:
	return Structures._hash(x, z, salt)
