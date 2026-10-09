class_name Structures
## Estructuras fabricadas a mano que el generador "estampa" en la isla. De momento, el
## naufragio del inicio (ver docs/DESIGN.md, "El naufragio"):
##   - el barco roto y encallado en la orilla de la bahía del pueblo, hecho de cubitos pequeños
##     (WreckModel; main.gd lo coloca donde dice micro_wreck());
##   - dentro, en la popa, un cofre con materiales (nada fabricado);
##   - restos por la arena que se desmontan a golpes (debris(); los pone Salvage).
## El jugador aparece en la playa mirando al barco.
##
## Se construye una sola vez (al crear el generador, en el hilo principal) y luego el
## generador solo copia los voxels del chunk que esté generando.

const AIR := 0

static var _by_chunk := {}       # Vector3i (origen del chunk de 16) -> Array de [Vector3i local, id]
static var _chest_loot := {}     # Vector3i (celda del cofre) -> Array de {"id", "count"}
static var _spawn := Vector2i.ZERO
static var _spawn_yaw := 0.0
static var _ship := Vector2i.ZERO  # centro del barco naufragado (voxels x, z)
static var _ruins := Vector2i(-274, -345)
static var _built := false
static var _clear: Array = []    # [Vector2 centro, radio] (voxels): sin árboles ni rocas
static var _clues: Array = []    # pistas de la historia: [{fact, cell (voxel), kind, text}] (main.gd pone los Clue)
static var _lights: Array = []   # linternas de los faros (voxels)


## Coloca las estructuras usando las alturas del generador. Llamar una vez antes de generar.
static func build(gen: IslandGenerator) -> void:
	if _built:
		return
	_built = true
	_by_chunk.clear()
	_chest_loot.clear()
	_clear.clear()
	_build_shipwreck(gen)
	_build_ruins(gen)
	_build_bridges(gen)
	# Lugares del mapa beta1: el pueblo principal, el pesquero destruido, faros, atalayas,
	# ruinas y minas. Sin árboles ni rocas encima.
	_clear.append(VillageBuilder.clear_zone())
	_clear.append([FishingVillageBuilder.CENTER * 2.0, 50.0])
	_clear.append_array(PlacesBuilder.clear_zones())
	VillageBuilder.build(gen, _put)
	_clues = FishingVillageBuilder.build(gen, _put)
	_lights = PlacesBuilder.build(gen, _put)


## Pistas de la historia puestas en los lugares (las crea main.gd con ClueModels).
static func clues() -> Array:
	return _clues


## Dónde van las luces de los faros (voxels).
static func lights() -> Array:
	return _lights


## ¿Hay que dejar esta columna sin árboles ni rocas? (junto al sitio de aparecer, los puentes...)
static func is_clear(wx: int, wz: int) -> bool:
	var p := Vector2(wx, wz)
	for zone: Array in _clear:
		if p.distance_squared_to(zone[0]) < zone[1] * zone[1]:
			return true
	return false


## Escribe en el buffer los voxels de estructuras que caen dentro de este chunk.
static func stamp(buffer: VoxelBuffer, origin: Vector3i) -> void:
	var list: Array = _by_chunk.get(origin, [])
	for entry in list:
		var p: Vector3i = entry[0]
		buffer.set_voxel(entry[1], p.x, p.y, p.z, VoxelBuffer.CHANNEL_TYPE)


## Botín inicial de un cofre de estructura (vacío si el cofre no es de ninguna).
static func loot_for_chest(cell: Vector3i) -> Array:
	return _chest_loot.get(cell, [])


## Dónde aparece el jugador (columna en voxels) y hacia dónde mira (radianes).
## Dónde va el barco de cubitos (en voxels: x, altura del fondo, z) y su giro.
static var _micro_wreck := Vector3.ZERO
static var _micro_wreck_yaw := 0.0
static var _debris: Array = []  # restos de la playa: [nombre, tipo, x, z, giro] (voxels)


static func debris() -> Array:
	return _debris


static func micro_wreck() -> Vector3:
	return _micro_wreck


static func micro_wreck_yaw() -> float:
	return _micro_wreck_yaw


static func spawn_voxel() -> Vector2i:
	return _spawn


## Centro del barco naufragado (x, z en voxels), para el mapa del diario.
static func ship_voxel() -> Vector2i:
	return _ship


static func ruins_voxel() -> Vector2i:
	return _ruins


static func spawn_yaw() -> float:
	return _spawn_yaw


# ------------------------------------------------------------------ el naufragio

static func _build_ruins(gen: IslandGenerator) -> void:
	# Restos de un muro antiguo en la colina del noroeste. La piedra musgosa es
	# cosechable y también se puede usar como bloque de construcción.
	var center := Vector2(-274.0, -345.0)
	for row in 2:
		var z := int(center.y) + (row * 2 - 1) * 5
		for i in 15:
			var x := int(center.x) - 7 + i
			if _hash(i, row, 71) < (0.18 if i % 5 != 0 else 0.55):
				continue  # huecos de derrumbe, con algún extremo más roto
			var ground := gen.get_ground_height(x, z)
			if ground <= IslandGenerator.SEA_LEVEL:
				continue
			var height := 1 + int(_hash(i, row, 73) * 5.0)
			for y in height:
				if y > 2 and _hash(i, y, row + 79) < 0.28:
					continue
				_put(Vector3i(x, ground + y, z), IslandGenerator.MOSSY_STONE)

	# Un cofre entre los muros: lo que dejó alguien que vivió aquí antes (mochila de marinero para
	# desmontar y aprenderla, nota del pico y materiales) y la armadura de los antiguos.
	var ruin_chest := Vector3i(int(center.x), gen.get_ground_height(int(center.x), int(center.y)), int(center.y))
	_put(ruin_chest, IslandGenerator.CHEST)
	_chest_loot[ruin_chest] = [
		{"id": "backpack", "count": 1}, {"id": "note_pick", "count": 1}, {"id": "rock", "count": 4},
		{"id": "sticks", "count": 4}, {"id": "berries", "count": 6},
		{"id": "ancient_helm", "count": 1}, {"id": "ancient_cuirass", "count": 1}, {"id": "ancient_greaves", "count": 1},
		{"id": "ancient_boots", "count": 1}, {"id": "ancient_gauntlets", "count": 1},
	]

	# Piedras caídas y cubiertas de musgo junto a la base de los muros.
	for i in 20:
		var x := int(center.x + (_hash(i, 5, 83) - 0.5) * 24.0)
		var z := int(center.y + (_hash(i, 6, 83) - 0.5) * 16.0)
		var ground := gen.get_ground_height(x, z)
		if ground > IslandGenerator.SEA_LEVEL and _hash(i, 7, 83) > 0.3:
			_put(Vector3i(x, ground, z), IslandGenerator.MOSSY_STONE)

static func _build_shipwreck(gen: IslandGenerator) -> void:
	# Orilla: desde el pueblo hacia el centro de la bahía, el primer punto que ya es agua.
	var village := Vector2(-280, 303)
	var bay := Vector2(-309, 393)
	var dir := (bay - village).normalized()
	var shore := village
	for step in 400:
		var p := village + dir * step
		if gen.get_ground_height(int(p.x), int(p.y)) <= IslandGenerator.SEA_LEVEL:
			shore = p
			break
	var along := dir.orthogonal()  # a lo largo de la orilla

	# El barco de cubitos (WreckModel; lo pone main.gd), encallado en la orilla y a lo largo de
	# ella: medio en la arena mojada, medio en el agua.
	var center := shore + dir * 2.0
	_ship = Vector2i(center)
	var stern := center - along * (WreckModel.LENGTH / float(MicroVoxels.RES) * 0.5)
	var keel := gen.get_ground_height(int(center.x), int(center.y)) + 1
	_micro_wreck = Vector3(stern.x, keel, stern.y)
	_micro_wreck_yaw = atan2(-along.y, along.x)

	# Cofre dentro del barco, en la popa (lo que se salvó: materiales, nada fabricado).
	var inside := stern + along * 4.0
	var ih := gen.get_ground_height(int(inside.x), int(inside.y))
	var ship_chest := Vector3i(int(inside.x), maxi(ih + 1, IslandGenerator.SEA_LEVEL), int(inside.y))
	_put(ship_chest, IslandGenerator.CHEST)
	_chest_loot[ship_chest] = [
		{"id": "cloth", "count": 4}, {"id": "fiber", "count": 6}, {"id": "sticks", "count": 4},
		{"id": "rock", "count": 3}, {"id": "berries", "count": 4},
		{"id": "note_belt", "count": 1}, {"id": "note_backpack", "count": 1},
	]

	# Restos por la arena (Salvage; los pone main.gd): [nombre, tipo, x, z, giro].
	_debris.clear()
	var kinds := ["plank", "plank", "planks", "crate", "plank", "barrel", "log", "cloth", "plank",
		"crate", "planks", "plank", "log", "cloth", "plank", "barrel"]
	for i in kinds.size():
		var a := (_hash(i, 1, 5) - 0.5) * 34.0
		var inland := 2.0 + _hash(i, 2, 5) * 9.0
		var p := shore + along * a - dir * inland
		_debris.append(["resto_%d" % i, kinds[i], p.x, p.y, _hash(i, 3, 5) * TAU])

	# El jugador aparece en la playa, unos metros tierra adentro, mirando al barco.
	var spawn := shore - dir * 14.0
	_spawn = Vector2i(int(spawn.x), int(spawn.y))
	_clear.append([Vector2(_spawn), 12.0])
	var look := center - spawn
	_spawn_yaw = atan2(-look.x, -look.y)  # el jugador mira hacia su -Z


# ------------------------------------------------------------------ puentes

const PLACES_FILE := "res://assets/island/lugares.json"  # lo escribe tools/hornear_isla.py


## Lugares que el horneador sacó del mapa (rutas por los caminos, puentes...).
static func places() -> Dictionary:
	if not FileAccess.file_exists(PLACES_FILE):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACES_FILE))
	return value if value is Dictionary else {}


## Puentes de madera donde los caminos cruzan los ríos: tablero de tablones de una orilla a la
## otra, a la altura de la orilla más alta (con un escalón de media losa en la otra), barandilla de
## postes y pasamanos, y pilares hasta el fondo del cauce.
static func _build_bridges(gen: IslandGenerator) -> void:
	for bridge: Dictionary in places().get("bridges", []):
		var center := Vector2(float(bridge["x"]), float(bridge["z"])) * 2.0  # metros -> voxels
		var river := Vector2(float(bridge["river"][0]), float(bridge["river"][1])).normalized()
		var across := river.orthogonal()
		var half := float(bridge["half_width"]) * 2.0 + 6.0  # el cauce y 3 m de orilla a cada lado
		var a := center - across * half
		var b := center + across * half
		_clear.append([center, half + 10.0])
		var water := gen.get_ground_height(int(center.x), int(center.y))
		var deck := maxi(maxi(gen.get_ground_height(int(a.x), int(a.y)), gen.get_ground_height(int(b.x), int(b.y))), water + 2) - 1
		# Todas las celdas cuyo centro cae en el rectángulo del tablero (2 m de ancho): así no
		# quedan huecos aunque el puente vaya en diagonal.
		var reach := int(ceil(half)) + 2
		for cx in range(floori(center.x) - reach, floori(center.x) + reach + 1):
			for cz in range(floori(center.y) - reach, floori(center.y) + reach + 1):
				var rel := Vector2(cx + 0.5, cz + 0.5) - center
				var along := rel.dot(across)
				var side := rel.dot(river)
				if absf(along) > half or absf(side) > 2.0:
					continue
				var cell := Vector3i(cx, deck, cz)
				var ground := gen.get_ground_height(cx, cz)
				if ground > deck + 1:
					continue  # la orilla ya es más alta: ahí se entra caminando
				_put(cell, IslandGenerator.PLANKS)
				for up in range(1, 4):
					_put(cell + Vector3i(0, up, 0), IslandGenerator.AIR)
				var edge := absf(side) > 1.2
				var on_water := absf(along) < half - 5.0
				var post := absf(fposmod(along, 2.0) - 1.0) < 0.36  # un poste cada 2 m
				if edge and on_water:
					if post:
						_put(cell + Vector3i.UP, IslandGenerator.WOOD)
						_put(cell + Vector3i(0, 2, 0), IslandGenerator.WOOD)
						var bed := _bed_height(gen, cx, cz)  # y su pilar hasta el fondo
						for y in range(bed, deck):
							_put(Vector3i(cx, y, cz), IslandGenerator.WOOD)
					else:
						_put(cell + Vector3i(0, 2, 0), IslandGenerator.SLAB_DOWN)  # pasamanos
				# En la orilla, relleno de tierra bajo el tablero (que no quede colgando).
				if not on_water:
					for y in range(ground, deck):
						_put(Vector3i(cx, y, cz), IslandGenerator.DIRT)
		# Escaleras de bajada en la orilla más baja: un peldaño por bloque hasta el suelo.
		for side_sign: float in [-1.0, 1.0]:
			for k in range(1, 12):
				var step := deck - k
				var any := false
				var mid := center + across * side_sign * (half + float(k))
				for cx in range(floori(mid.x) - 3, floori(mid.x) + 4):
					for cz in range(floori(mid.y) - 3, floori(mid.y) + 4):
						var rel := Vector2(cx + 0.5, cz + 0.5) - center
						var along := rel.dot(across) * side_sign
						if along <= half + float(k) - 1.0 or along > half + float(k) or absf(rel.dot(river)) > 2.0:
							continue
						var ground := gen.get_ground_height(cx, cz)
						if ground > step:
							continue
						any = true
						var cell := Vector3i(cx, step, cz)
						_put(cell, IslandGenerator.PLANKS)
						for y in range(ground, step):
							_put(Vector3i(cx, y, cz), IslandGenerator.DIRT)
						for up in range(1, 4):
							_put(cell + Vector3i(0, up, 0), IslandGenerator.AIR)
				if not any:
					break


## Altura del fondo del cauce (el suelo, sin contar el agua) en coordenadas de voxel.
static func _bed_height(gen: IslandGenerator, x: int, z: int) -> int:
	return gen._height_at(x, z)


static func _put(cell: Vector3i, id: int) -> void:
	var chunk := Vector3i(floori(cell.x / 16.0) * 16, floori(cell.y / 16.0) * 16, floori(cell.z / 16.0) * 16)
	if not _by_chunk.has(chunk):
		_by_chunk[chunk] = []
	(_by_chunk[chunk] as Array).append([cell - chunk, id])


static func _hash(x: int, z: int, salt: int) -> float:
	var h: int = (x * 73856093) ^ (z * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0
