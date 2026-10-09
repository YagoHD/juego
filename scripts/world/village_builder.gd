extends RefCounted
class_name VillageBuilder
## Edificios de bloques del pueblo principal (VillageLayout), estampados en la isla por Structures:
## casas de tablones con esquinas de tronco, puerta hacia la plaza, ventanas y tejado a dos aguas;
## la capilla de piedra con su campanario; y las tiendas de lona del campamento de refugiados.
## Todo en voxels (0,5 m). El suelo se allana bajo cada edificio y se despeja encima.

const WALL := 5          # alto de las paredes (2,5 m)


## Levanta todo el pueblo. 'put' es Structures._put (celda, id).
static func build(gen: IslandGenerator, put: Callable) -> void:
	var center := VillageLayout.ISLAND_CENTER * 2.0  # voxels
	for i in VillageLayout.homes().size():
		var at := center + VillageLayout.homes()[i] * 2.0
		_house(gen, put, at, VillageLayout.HOUSE_SIZE * 2.0, center, IslandGenerator.PLANKS, i)
	for place: String in VillageLayout.BUILDINGS:
		var at := center + (VillageLayout.PLACES[place][0] as Vector2) * 2.0
		var size: Vector2 = VillageLayout.BUILDINGS[place] * 2.0
		if place == "chapel":
			_chapel(gen, put, at, size, center)
		else:
			_house(gen, put, at, size, center, IslandGenerator.PLANKS, place.hash())
	var camp := center + (VillageLayout.PLACES["refugee_camp"][0] as Vector2) * 2.0
	for k in 3:
		var angle := k * TAU / 3.0 + 0.4
		_tent(gen, put, camp + Vector2(cos(angle), sin(angle)) * 8.0, k % 2 == 0)


## Zonas que deben quedar sin árboles ni rocas: el pueblo entero.
static func clear_zone() -> Array:
	return [VillageLayout.ISLAND_CENTER * 2.0, VillageLayout.RADIUS * 2.0 + 6.0]


## Casa de w x d voxels centrada en 'at'; la puerta mira hacia 'face'.
static func _house(gen: IslandGenerator, put: Callable, at: Vector2, size: Vector2, face: Vector2, wall_id: int, seed: int) -> void:
	var w := int(size.x)
	var d := int(size.y)
	var x0 := int(at.x) - w / 2
	var z0 := int(at.y) - d / 2
	var base := _level(gen, put, x0, z0, w, d, WALL + w / 2 + 3)
	# Puerta en la pared más cercana a la plaza.
	var to_face := face - at
	var door_side := ""
	if absf(to_face.x) > absf(to_face.y):
		door_side = "e" if to_face.x > 0 else "w"
	else:
		door_side = "s" if to_face.y > 0 else "n"
	for x in w:
		for z in d:
			var edge_x := x == 0 or x == w - 1
			var edge_z := z == 0 or z == d - 1
			put.call(Vector3i(x0 + x, base - 1, z0 + z), IslandGenerator.PLANKS)  # suelo
			if not (edge_x or edge_z):
				continue
			for y in WALL:
				var id := wall_id
				if edge_x and edge_z:
					id = IslandGenerator.WOOD  # esquinas de tronco
				elif y == WALL - 1:
					id = IslandGenerator.WOOD  # viga de arriba
				if _is_door(door_side, x, z, y, w, d) or _is_window(door_side, x, z, y, w, d, edge_x, edge_z):
					id = IslandGenerator.AIR
				put.call(Vector3i(x0 + x, base + y, z0 + z), id)
	# Tejado a dos aguas: la cumbrera va a lo largo del lado más largo; un voladizo de 1 bloque.
	var along_x := w >= d
	var span := d if along_x else w
	var length := w if along_x else d
	var roof := IslandGenerator.DRIFTWOOD if seed % 3 != 0 else IslandGenerator.DEAD_WOOD
	var layers := (span + 2) / 2
	for j in layers + 1:
		var lo := j - 1
		var hi := span - j
		if lo > hi:
			break
		var y := base + WALL + j
		for l in range(-1, length + 1):
			for s in range(lo, hi + 1):
				var outer := s == lo or s == hi or lo + 1 >= hi
				var gable := (l == 0 or l == length - 1) and s > lo and s < hi
				if not outer and not gable:
					continue
				var id := roof if outer else wall_id
				var cell := Vector3i(x0 + l, y, z0 + s) if along_x else Vector3i(x0 + s, y, z0 + l)
				put.call(cell, id)


static func _is_door(side: String, x: int, z: int, y: int, w: int, d: int) -> bool:
	if y >= 4:
		return false
	match side:
		"n": return z == 0 and (x == w / 2 or x == w / 2 - 1)
		"s": return z == d - 1 and (x == w / 2 or x == w / 2 - 1)
		"w": return x == 0 and (z == d / 2 or z == d / 2 - 1)
		"e": return x == w - 1 and (z == d / 2 or z == d / 2 - 1)
	return false


static func _is_window(side: String, x: int, z: int, y: int, w: int, d: int, edge_x: bool, edge_z: bool) -> bool:
	if y != 2 or (edge_x and edge_z):
		return false
	if edge_z and side != "n" and side != "s":
		return x == w / 2
	if edge_x and side != "w" and side != "e":
		return z == d / 2
	if edge_z and ((side == "n" and z == d - 1) or (side == "s" and z == 0)):
		return x == w / 2
	if edge_x and ((side == "w" and x == w - 1) or (side == "e" and x == 0)):
		return z == d / 2
	return false


## Capilla de piedra con campanario en el lado más lejano a la plaza.
static func _chapel(gen: IslandGenerator, put: Callable, at: Vector2, size: Vector2, face: Vector2) -> void:
	_house(gen, put, at, size, face, IslandGenerator.STONE, 3)
	var w := int(size.x)
	var d := int(size.y)
	var x0 := int(at.x) - w / 2
	var z0 := int(at.y) - d / 2
	var back_z := z0 if face.y > at.y else z0 + d - 6  # el campanario, al fondo
	var tx := x0 + w / 2 - 3
	var base := gen.get_ground_height(tx + 3, back_z + 3)
	var top := base + 22
	for x in 6:
		for z in 6:
			for y in range(base - 2, top):
				var edge := x == 0 or x == 5 or z == 0 or z == 5
				var id := IslandGenerator.STONE if edge else IslandGenerator.AIR
				if y >= top - 6 and y < top - 2 and edge and x in [2, 3] or (y >= top - 6 and y < top - 2 and edge and z in [2, 3]):
					id = IslandGenerator.AIR  # los huecos de las campanas
				if y == top - 7 and not edge:
					id = IslandGenerator.PLANKS  # suelo de las campanas
				put.call(Vector3i(tx + x, y, back_z + z), id)
	put.call(Vector3i(tx + 2, top - 8, back_z + 2), IslandGenerator.ROPE_HANGING)  # la cuerda de la campana (la campana, cuando haya arte)
	# Tejado en punta.
	for j in 4:
		for x in range(j - 1, 7 - j):
			for z in range(j - 1, 7 - j):
				put.call(Vector3i(tx + x, top + j, back_z + z), IslandGenerator.DEAD_WOOD)


## Tienda de lona: dos laderas de tela sobre un palo.
static func _tent(gen: IslandGenerator, put: Callable, at: Vector2, along_x: bool) -> void:
	var x0 := int(at.x)
	var z0 := int(at.y)
	var base := _level(gen, put, x0 - 3, z0 - 3, 7, 7, 5)
	for l in range(-3, 4):
		for j in 4:
			for s in [-3 + j, 3 - j]:
				var cell := Vector3i(x0 + l, base + j, z0 + s) if along_x else Vector3i(x0 + s, base + j, z0 + l)
				put.call(cell, IslandGenerator.WOOD if j == 3 else IslandGenerator.CLOTH)


## Allana un rectángulo: suelo a la altura media (rellena con tierra o recorta) y lo despeja
## 'clear' bloques hacia arriba (y uno de margen alrededor). Devuelve la altura del suelo (la
## primera celda libre).
static func _level(gen: IslandGenerator, put: Callable, x0: int, z0: int, w: int, d: int, clear: int) -> int:
	var total := 0
	for x in w:
		for z in d:
			total += gen.get_ground_height(x0 + x, z0 + z)
	var base := roundi(float(total) / float(w * d))
	for x in range(-1, w + 1):
		for z in range(-1, d + 1):
			var ground := gen.get_ground_height(x0 + x, z0 + z)
			for y in range(ground, base):
				put.call(Vector3i(x0 + x, y, z0 + z), IslandGenerator.DIRT)
			for y in range(base, maxi(base + clear, ground)):
				put.call(Vector3i(x0 + x, y, z0 + z), IslandGenerator.AIR)
	return base
