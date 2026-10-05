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


## Coloca las estructuras usando las alturas del generador. Llamar una vez antes de generar.
static func build(gen: IslandGenerator) -> void:
	if _built:
		return
	_built = true
	_by_chunk.clear()
	_chest_loot.clear()
	_build_shipwreck(gen)
	_build_ruins(gen)


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
	# desmontar y aprenderla, nota del pico y materiales).
	var ruin_chest := Vector3i(int(center.x), gen.get_ground_height(int(center.x), int(center.y)), int(center.y))
	_put(ruin_chest, IslandGenerator.CHEST)
	_chest_loot[ruin_chest] = [
		{"id": "backpack", "count": 1}, {"id": "note_pick", "count": 1}, {"id": "rock", "count": 4},
		{"id": "sticks", "count": 4}, {"id": "berries", "count": 6},
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
	var look := center - spawn
	_spawn_yaw = atan2(-look.x, -look.y)  # el jugador mira hacia su -Z


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
