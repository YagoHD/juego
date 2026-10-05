extends IslandGenerator
class_name ShowroomGenerator
## Sala de muestras para revisar el aspecto (main con "--showroom"): un suelo plano y, delante
## del punto de aparición, en fila sobre pedestales, todos los bloques y la decoración; detrás,
## una escalera de hierba (para ver los lados), una pared de bloques y un charco. Carga en
## segundos y la cámara siempre ve lo mismo: las capturas salen comparables.

const FLOOR := SEA_LEVEL + 12       # altura del suelo (lejos del mar: sin cangrejos ni gaviotas)
const ROW_Z := 4                    # distancia de la fila de bloques al punto de aparición
const GAP := 2                      # separación entre muestras
const PER_ROW := 12                 # muestras por fila


## Bloques que se enseñan (en este orden, de izquierda a derecha).
static func samples() -> Array[int]:
	var out: Array[int] = [GRASS, DIRT, SAND, WET_SAND, STONE, MOSSY_STONE, SNOW, CORRUPT_SOIL, ORE, GRAVEL, CLAY, MUD,
		WOOD, PLANKS, DRIFTWOOD, CLOTH, CHEST, WORKBENCH, LOG_X, DEAD_WOOD, WATER,
		TALL_GRASS, FLOWER_RED, FLOWER_YELLOW, PEBBLES, GROUND_STICKS, SHELL,
		SLAB_DOWN, SLAB_UP, SLAB_N, SLAB_E, ROPE_HANGING, SAIL_X, SAIL_Z]
	return out


static func center() -> Vector2i:
	return Structures.spawn_voxel()


func get_ground_height(_wx: int, _wz: int) -> int:
	return FLOOR


func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, _lod: int) -> void:
	var size := out_buffer.get_size()
	var c := center()
	# Suelo: piedra y, encima, una capa de arena clara (fondo neutro, como el de las hojas).
	for x in size.x:
		for z in size.z:
			_fill_run(out_buffer, origin, size, x, z, STONE, origin.y, FLOOR - 1)
			_fill_run(out_buffer, origin, size, x, z, SAND, FLOOR - 1, FLOOR)
	# Un prado a la izquierda (como en la isla: 1 de cada 10 con flores), para ver si se repite.
	for x in range(c.x + 14, c.x + 40):
		for z in range(c.y - 4, c.y + 20):
			_put_at(out_buffer, origin, size, x, FLOOR - 1, z, GRASS_FLOWERS if _hash01(x * 3 + 7, z * 5 + 1) < 0.1 else GRASS)
	var list := samples()
	# Mirando hacia +Z, la X crece hacia la izquierda: se empieza por la derecha para que la
	# fila se lea de izquierda a derecha en el mismo orden que la hoja del concepto.
	var right := c.x + (PER_ROW - 1) * GAP / 2
	for i in list.size():
		var x := right - (i % PER_ROW) * GAP
		var z := c.y + ROW_Z + (i / PER_ROW) * 3  # filas de PER_ROW, una detrás de otra
		var id: int = list[i]
		if Blocks.is_decor(id) or id == CLOTH:
			_put_at(out_buffer, origin, size, x, FLOOR, z, GRASS)  # sobre un bloque de hierba
			_put_at(out_buffer, origin, size, x, FLOOR + 1, z, id)
		else:
			_put_at(out_buffer, origin, size, x, FLOOR, z, id)
	# Escalera de hierba y tierra (para ver los lados con la hierba que cuelga).
	for k in 4:
		for h in k + 1:
			for w in 3:
				_put_at(out_buffer, origin, size, c.x - 8 + k, FLOOR + h, c.y + ROW_Z + 11 + w, DIRT if h < k else GRASS)
	# Pared de piedra, musgo, mineral, tablones y troncos (para ver el relieve en grande).
	var wall := [STONE, MOSSY_STONE, ORE, PLANKS, WOOD, DRIFTWOOD, CORRUPT_SOIL, SNOW]
	for i in wall.size():
		for h in 3:
			_put_at(out_buffer, origin, size, c.x - 2 + i, FLOOR + h, c.y + ROW_Z + 12, wall[i])
	# Fila de árboles de cada tipo, detrás (como la hoja de árboles del concepto).
	var tz := c.y + ROW_Z + 22
	var row := ["t_oak_1", "t_lean_1", "t_giant_1", "t_pine_1", "t_pine_small_1", "t_pine_tier_1", "t_dead_1", "t_bush_1", "t_berry_1"]
	for i in row.size():
		var tx := c.x + 40 - i * 10
		for piece in PrefabLibrary.pieces(PrefabLibrary.index_of(row[i])):
			var p: Vector3i = piece[0]
			_put_at(out_buffer, origin, size, tx + p.x, FLOOR + p.y, tz + p.z, piece[1])
	# Charco de agua de 3x3.
	for x in 3:
		for z in 3:
			_put_at(out_buffer, origin, size, c.x + 9 + x, FLOOR - 1, c.y + ROW_Z + 11 + z, WATER)


func _put_at(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, wx: int, wy: int, wz: int, id: int) -> void:
	var l := Vector3i(wx, wy, wz) - origin
	if l.x < 0 or l.y < 0 or l.z < 0 or l.x >= size.x or l.y >= size.y or l.z >= size.z:
		return
	buffer.set_voxel(id, l.x, l.y, l.z, VoxelBuffer.CHANNEL_TYPE)
