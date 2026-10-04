class_name Structures
## Estructuras fabricadas a mano que el generador "estampa" en la isla. De momento, el
## naufragio del inicio (ver docs/DESIGN.md, "El naufragio"):
##   - el barco entero pero encallado en la orilla de la bahía del pueblo (ver Shipwreck): casco
##     curvo, camarote, mástiles con vela y una cuerda colgando, bodega con escalera, alguna rotura;
##   - en la playa: la punta del trinquete caída con su vela tirada en la arena, tablones sueltos
##     y un cofre medio enterrado;
##   - en la bodega, otro cofre con lo que se salvó.
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

	# El barco entero, encallado en la orilla y alineado con ella (ver Shipwreck).
	var ship := Shipwreck.new()
	ship.build()
	var shore_dir := dir.orthogonal()
	var along_x := absf(shore_dir.x) >= absf(shore_dir.y)
	var sgn := signf(shore_dir.x if along_x else shore_dir.y)
	# Un poco hacia el agua y hacia la popa: así la proa no se mete en la ladera de la bahía.
	var bow := Vector2(sgn, 0) if along_x else Vector2(0, sgn)
	var center := shore + dir * 6.0 - bow * 6.0
	_ship = Vector2i(center)
	var base_y := IslandGenerator.SEA_LEVEL - 2
	for p: Vector3i in ship.cells:
		var cell := _ship_to_world(p, center, base_y, along_x, sgn)
		_put(cell, _ship_block(ship.cells[p], along_x, sgn))
	_chest_loot[_ship_to_world(ship.hold_chest, center, base_y, along_x, sgn)] = [
		# Casi nada: lo que se salvó del agua. El resto lo irá trayendo el mar.
		{"id": "cloth", "count": 3}, {"id": "note_backpack", "count": 1}, {"id": "shirt", "count": 1},
		{"id": "berries", "count": 4},
	]

	# En la playa: el mástil caído hacia tierra, con la vela tirada al lado.
	var mast_dir := -dir.rotated(0.5)
	var mast_start := shore - dir * 2.0
	for i in 18:
		var p := mast_start + mast_dir * i
		var h := gen.get_ground_height(int(p.x), int(p.y))
		_put(Vector3i(int(p.x), h, int(p.y)), IslandGenerator.WOOD)
	var sail_center := mast_start + mast_dir * 11.0 + mast_dir.orthogonal() * 3.5
	for sx in range(-4, 5):
		var half_span := 3 - int(abs(sx) / 2)
		for sz in range(-half_span, half_span + 1):
			if _hash(sx, sz, 7) > (0.68 if abs(sz) == half_span else 0.88):
				continue  # vela rota: le faltan trozos
			var p := sail_center + mast_dir * sx + mast_dir.orthogonal() * sz
			var h := gen.get_ground_height(int(p.x), int(p.y))
			_put(Vector3i(int(p.x), h, int(p.y)), IslandGenerator.CLOTH)

	# Restos en pequeños grupos, con huecos entre ellos, en vez de tablones aislados en fila.
	for i in 9:
		var along := (_hash(i, 1, 3) - 0.5) * 38.0
		var inland := _hash(i, 2, 3) * 10.0
		for piece in 3:
			var p := shore + dir.orthogonal() * (along + (_hash(i, piece, 31) - 0.5) * 4.0) \
				- dir * (inland + (_hash(i, piece, 37) - 0.5) * 3.0)
			var h := gen.get_ground_height(int(p.x), int(p.y))
			if h > IslandGenerator.SEA_LEVEL:
				var debris_id := IslandGenerator.DRIFTWOOD if _hash(i, piece, 41) > 0.55 else IslandGenerator.PLANKS
				_put(Vector3i(int(p.x), h, int(p.y)), debris_id)

	# Cofre medio enterrado en la arena.
	var buried := shore - dir * 6.0 + dir.orthogonal() * 7.0
	var bh := gen.get_ground_height(int(buried.x), int(buried.y))
	var beach_chest := Vector3i(int(buried.x), bh - 1, int(buried.y))
	_put(beach_chest, IslandGenerator.CHEST)
	_chest_loot[beach_chest] = [
		{"id": "chest", "count": 1}, {"id": "note_belt", "count": 1}, {"id": "rope", "count": 1},
	]

	# El jugador aparece en la playa, unos metros tierra adentro, mirando al barco.
	var spawn := shore - dir * 14.0
	_spawn = Vector2i(int(spawn.x), int(spawn.y))
	var look := center - spawn
	_spawn_yaw = atan2(-look.x, -look.y)  # el jugador mira hacia su -Z


## Celda del mundo de un punto del barco (x de popa a proa, z de lado a lado), girado para
## quedar a lo largo de la orilla.
static func _ship_to_world(p: Vector3i, center: Vector2, base_y: int, along_x: bool, sgn: float) -> Vector3i:
	var lx := p.x - Shipwreck.LENGTH / 2
	var s := int(sgn)
	if along_x:
		return Vector3i(int(center.x) + lx * s, base_y + p.y, int(center.y) + p.z * s)
	return Vector3i(int(center.x) - p.z * s, base_y + p.y, int(center.y) + lx * s)


## El bloque del barco ya girado: las medias losas, troncos tumbados y velas cambian de lado.
static func _ship_block(value: Variant, along_x: bool, sgn: float) -> int:
	var s := int(sgn)
	if value is String:
		var side: String = String(value).trim_prefix("slab:")
		if side == "-y":
			return IslandGenerator.SLAB_DOWN
		var local_z := -1 if side == "-z" else 1
		var world := Vector3i(0, 0, local_z * s) if along_x else Vector3i(-local_z * s, 0, 0)
		match world:
			Vector3i(0, 0, -1): return IslandGenerator.SLAB_N
			Vector3i(0, 0, 1): return IslandGenerator.SLAB_S
			Vector3i(-1, 0, 0): return IslandGenerator.SLAB_W
		return IslandGenerator.SLAB_E
	var id: int = value
	if not along_x:
		match id:
			IslandGenerator.LOG_Z: return IslandGenerator.LOG_X
			IslandGenerator.SAIL_X: return IslandGenerator.SAIL_Z
	return id


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
