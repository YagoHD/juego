extends IslandGenerator
class_name ShowroomGenerator
## Sala de muestras para revisar el aspecto (main con "--showroom"): un suelo plano y, delante
## del punto de aparición, en fila sobre pedestales, todos los bloques y la decoración; detrás,
## una escalera de hierba (para ver los lados), una pared de bloques y un charco. Carga en
## segundos y la cámara siempre ve lo mismo: las capturas salen comparables.

const FLOOR := SEA_LEVEL + 12       # altura del suelo (lejos del mar: sin cangrejos ni gaviotas)
const ROW_Z := 6                    # distancia de la fila de bloques al punto de aparición
const GAP := 2                      # separación entre muestras


## Bloques que se enseñan (en este orden, de izquierda a derecha).
static func samples() -> Array[int]:
	var out: Array[int] = [GRASS, DIRT, SAND, STONE, MOSSY_STONE, SNOW, CORRUPT_SOIL, ORE,
		WOOD, PLANKS, DRIFTWOOD, CLOTH, CHEST, WORKBENCH, LOG_X, DEAD_WOOD, WATER,
		TALL_GRASS, FLOWER_RED, FLOWER_YELLOW, PEBBLES, GROUND_STICKS, SHELL]
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
	var list := samples()
	# Mirando hacia +Z, la X crece hacia la izquierda: se empieza por la derecha para que la
	# fila se lea de izquierda a derecha en el mismo orden que la hoja del concepto.
	var right := c.x + (list.size() - 1) * GAP / 2
	for i in list.size():
		var x := right - i * GAP
		var z := c.y + ROW_Z
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
				_put_at(out_buffer, origin, size, c.x - 8 + k, FLOOR + h, c.y + ROW_Z + 5 + w, DIRT if h < k else GRASS)
	# Pared de piedra, musgo, mineral, tablones y troncos (para ver el relieve en grande).
	var wall := [STONE, MOSSY_STONE, ORE, PLANKS, WOOD, DRIFTWOOD, CORRUPT_SOIL, SNOW]
	for i in wall.size():
		for h in 3:
			_put_at(out_buffer, origin, size, c.x - 2 + i, FLOOR + h, c.y + ROW_Z + 6, wall[i])
	# Charco de agua de 3x3.
	for x in 3:
		for z in 3:
			_put_at(out_buffer, origin, size, c.x + 9 + x, FLOOR - 1, c.y + ROW_Z + 5 + z, WATER)


func _put_at(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, wx: int, wy: int, wz: int, id: int) -> void:
	var l := Vector3i(wx, wy, wz) - origin
	if l.x < 0 or l.y < 0 or l.z < 0 or l.x >= size.x or l.y >= size.y or l.z >= size.z:
		return
	buffer.set_voxel(id, l.x, l.y, l.z, VoxelBuffer.CHANNEL_TYPE)
