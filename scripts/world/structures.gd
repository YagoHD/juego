class_name Structures
## Estructuras fabricadas a mano que el generador "estampa" en la isla. De momento, el
## naufragio del inicio (ver docs/DESIGN.md, "El naufragio"):
##   - el barco encallado y escorado en la orilla de la bahía del pueblo: casco de tablones con
##     quilla de tronco, cubierta hundida, popa destrozada, agujeros y el palo mayor partido;
##   - en la playa: el mástil caído con la vela tirada en la arena, tablones sueltos y un cofre
##     medio enterrado;
##   - dentro del casco, otro cofre con lo que se salvó.
## El jugador aparece en la playa mirando al barco.
##
## Se construye una sola vez (al crear el generador, en el hilo principal) y luego el
## generador solo copia los voxels del chunk que esté generando.

const AIR := 0

# Medidas del barco (en voxels de 0,5 m).
const SHIP_LENGTH := 44.0
const SHIP_HALF_WIDTH := 6.5
const SHIP_DEPTH := 9.0          # del fondo del casco a la cubierta
const SHIP_ROLL := 0.30          # escora (radianes): el barco está tumbado hacia un lado
const MAST_AT := 0.55            # posición del palo mayor a lo largo del barco (0 popa, 1 proa)

static var _by_chunk := {}       # Vector3i (origen del chunk de 16) -> Array de [Vector3i local, id]
static var _chest_loot := {}     # Vector3i (celda del cofre) -> Array de {"id", "count"}
static var _spawn := Vector2i.ZERO
static var _spawn_yaw := 0.0
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


static func spawn_yaw() -> float:
	return _spawn_yaw


# ------------------------------------------------------------------ el naufragio

static func _build_ruins(gen: IslandGenerator) -> void:
	# Restos de un muro antiguo en la colina del noroeste. La piedra musgosa es
	# cosechable y también se puede usar como bloque de construcción.
	var center := Vector2(-548.0, -691.0)
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

	# Piedras caídas y cubiertas de musgo junto a la base de los muros.
	for i in 20:
		var x := int(center.x + (_hash(i, 5, 83) - 0.5) * 24.0)
		var z := int(center.y + (_hash(i, 6, 83) - 0.5) * 16.0)
		var ground := gen.get_ground_height(x, z)
		if ground > IslandGenerator.SEA_LEVEL and _hash(i, 7, 83) > 0.3:
			_put(Vector3i(x, ground, z), IslandGenerator.MOSSY_STONE)

static func _build_shipwreck(gen: IslandGenerator) -> void:
	# Orilla: desde el pueblo hacia el centro de la bahía, el primer punto que ya es agua.
	var village := Vector2(-560, 607)
	var bay := Vector2(-618, 786)
	var dir := (bay - village).normalized()
	var shore := village
	for step in 400:
		var p := village + dir * step
		if gen.get_ground_height(int(p.x), int(p.y)) <= IslandGenerator.SEA_LEVEL:
			shore = p
			break

	# El barco: algo metido en el agua, de costado a la orilla y con la quilla medio enterrada.
	var center := shore + dir * 9.0
	var yaw := dir.angle() + PI * 0.5 + 0.35
	var base_y := float(IslandGenerator.SEA_LEVEL - 3)
	var ship_basis := Basis(Vector3.UP, -yaw) * Basis(Vector3.RIGHT, SHIP_ROLL)
	var to_local := ship_basis.inverse()
	var origin := Vector3(center.x, base_y, center.y)
	var mast_x := SHIP_LENGTH * MAST_AT
	var reach := int(SHIP_LENGTH * 0.6) + 4
	for x in range(-reach, reach + 1):
		for z in range(-reach, reach + 1):
			for y in range(-6, 22):
				var cell := Vector3i(int(center.x) + x, int(base_y) + y, int(center.y) + z)
				var local := to_local * (Vector3(cell) + Vector3(0.5, 0.5, 0.5) - origin)
				local.x += SHIP_LENGTH * 0.5  # local.x: 0 popa .. SHIP_LENGTH proa
				var id := _ship_voxel(local, cell)
				if id >= 0:
					_put(cell, id)

	# Tres cuadernas partidas que sobresalen de la cubierta: rompen la silueta de caja
	# y hacen que el casco se lea como un barco abierto por el naufragio.
	var rib_positions: Array[float] = [0.24, 0.49, 0.73]
	for rib in 3:
		var rib_x := SHIP_LENGTH * rib_positions[rib]
		for z in range(-4, 5):
			if _hash(rib, z, 53) < 0.22:
				continue
			var rib_local := Vector3(rib_x, SHIP_DEPTH + 0.7 - absf(float(z)) * 0.10, z)
			_put(_ship_cell(rib_local, ship_basis, origin), IslandGenerator.WOOD)

	# El palo mayor está partido y cae sobre la proa en una diagonal irregular.
	for i in 10:
		var spar_local := Vector3(mast_x + i * 0.72, SHIP_DEPTH + 4.2 - i * 0.43, 0.0)
		_put(_ship_cell(spar_local, ship_basis, origin), IslandGenerator.WOOD)

	# Cofre dentro del casco, sobre el fondo, a 2/5 de la eslora.
	var chest_local := Vector3(SHIP_LENGTH * 0.4 - SHIP_LENGTH * 0.5, 1.5, 0.0)
	var hull_chest := Vector3i((ship_basis * chest_local + origin).floor())
	_put(hull_chest, IslandGenerator.CHEST)
	_chest_loot[hull_chest] = [
		{"id": "planks", "count": 24}, {"id": "cloth", "count": 8}, {"id": "rope", "count": 4},
		{"id": "wood", "count": 6}, {"id": "sticks", "count": 4},
		{"id": "stone_knife", "count": 1},
		{"id": "wheat", "count": 5}, {"id": "backpack", "count": 1}, {"id": "shirt", "count": 1},
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
		{"id": "planks", "count": 10}, {"id": "cloth", "count": 3}, {"id": "rope", "count": 2},
		{"id": "chest", "count": 1}, {"id": "pants", "count": 1}, {"id": "belt", "count": 1},
		{"id": "berries", "count": 6},
	]

	# El jugador aparece en la playa, unos metros tierra adentro, mirando al barco.
	var spawn := shore - dir * 14.0
	_spawn = Vector2i(int(spawn.x), int(spawn.y))
	var look := center - spawn
	_spawn_yaw = atan2(-look.x, -look.y)  # el jugador mira hacia su -Z


## Bloque del barco en un punto de su espacio local (x a lo largo, y arriba, z a lo ancho),
## o -1 si ahí no hay barco (se deja el terreno).
static func _ship_voxel(p: Vector3, cell: Vector3i) -> int:
	if p.x < 0.0 or p.x > SHIP_LENGTH or p.y < -0.5:
		return -1
	var t := p.x / SHIP_LENGTH
	var r := absf(p.z)
	var mast_x := SHIP_LENGTH * MAST_AT

	# Palo mayor partido: un trozo de tronco que sale de la cubierta.
	if absf(p.x - mast_x) < 0.7 and r < 0.7 and p.y > SHIP_DEPTH - 1.0 and p.y < SHIP_DEPTH + 5.0:
		return IslandGenerator.WOOD
	if p.y > SHIP_DEPTH + 0.5:
		return -1

	# Casco: más ancho en el centro, en punta en la proa, y redondeado hacia el fondo.
	var half := SHIP_HALF_WIDTH * pow(sin(PI * clampf(t * 0.92 + 0.04, 0.0, 1.0)), 0.55)
	var at_y := half * clampf(sqrt(maxf(p.y, 0.0) / SHIP_DEPTH) * 0.8 + 0.2, 0.0, 1.0)
	if r > at_y + 0.5:
		return -1

	var broken := _hash(cell.x, cell.y * 7 + cell.z, 11)
	if t < 0.16 and broken > 0.35:
		return -1  # popa destrozada
	if p.y < 1.0:
		return IslandGenerator.WOOD if r < 1.0 else IslandGenerator.PLANKS  # quilla y fondo
	if r > at_y - 0.9:
		return -1 if broken > 0.88 else IslandGenerator.PLANKS  # costados, con agujeros
	if p.y > SHIP_DEPTH - 0.5:
		return -1 if broken > 0.55 else IslandGenerator.PLANKS  # cubierta medio hundida
	return AIR  # interior hueco (aunque esté bajo la arena)


static func _ship_cell(local: Vector3, ship_basis: Basis, origin: Vector3) -> Vector3i:
	return Vector3i((ship_basis * local + origin).floor())


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
