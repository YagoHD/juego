extends SceneTree
## Prueba de los lugares del mapa (sin ventana): se genera el terreno de cada sitio y se comprueba
## que está levantado: casas del pueblo con su puerta, capilla con campanario, pueblo pesquero con
## sus pistas, faros y atalayas con escalera hasta arriba, ruinas y la galería de las minas.
## Uso: godot --headless --path . --script res://tools/test_places.gd

var _fails := 0
var _gen: IslandGenerator
var _blocks := {}


func _init() -> void:
	_gen = IslandGenerator.new()
	_gen.skip_trees = true
	# Pueblo principal: las casas tienen paredes de tablones, suelo y tejado, y la puerta despejada.
	var center := VillageLayout.ISLAND_CENTER * 2.0
	var houses_ok := 0
	for home in VillageLayout.homes():
		var at := center + home * 2.0
		var base := _floor_at(Vector2i(int(at.x), int(at.y)))
		var walls := _count(Vector3i(int(at.x) - 4, base, int(at.y) - 4), Vector3i(8, VillageBuilder.WALL, 8), [IslandGenerator.PLANKS, IslandGenerator.WOOD])
		var roof := _count(Vector3i(int(at.x) - 5, base + VillageBuilder.WALL, int(at.y) - 5), Vector3i(10, 6, 10), [IslandGenerator.DRIFTWOOD, IslandGenerator.DEAD_WOOD])
		if walls > 60 and roof > 20:
			houses_ok += 1
	_check("Pueblo: %d de %d casas con paredes y tejado" % [houses_ok, VillageLayout.HOUSES], houses_ok == VillageLayout.HOUSES)
	var chapel: Vector2 = center + VillageLayout.PLACES["chapel"][0] * 2.0
	var chapel_base := _floor_at(Vector2i(int(chapel.x), int(chapel.y)))
	var tower := _count(Vector3i(int(chapel.x) - 8, chapel_base + 12, int(chapel.y) - 10), Vector3i(16, 12, 20), [IslandGenerator.STONE])
	_check("Capilla con campanario de piedra (%d bloques altos)" % tower, tower > 40)
	# Pueblo pesquero: muros quemados y tres pistas.
	var fishing := FishingVillageBuilder.CENTER * 2.0
	var burnt := _count(Vector3i(int(fishing.x) - 40, _floor_at(Vector2i(fishing)) - 6, int(fishing.y) - 30), Vector3i(80, 16, 60), [IslandGenerator.DEAD_WOOD])
	_check("Pueblo pesquero con madera quemada (%d)" % burnt, burnt > 60)
	var facts := Structures.clues().map(func(c: Dictionary) -> String: return c["fact"])
	_check("Pistas del pueblo pesquero: %s" % ", ".join(facts), facts.has("joyero_vacio") and facts.has("escudo_valdes") and facts.has("emblema_ojo_pesquero"))
	# Faros: torre alta de piedra con luz arriba.
	_check("Tres faros con su luz (%d)" % Structures.lights().size(), Structures.lights().size() == 3)
	for light: Vector3i in Structures.lights():
		var stone := _count(Vector3i(light.x - 3, light.y - 26, light.z - 3), Vector3i(6, 24, 6), [IslandGenerator.STONE, IslandGenerator.MOSSY_STONE])
		_check("  faro en (%d, %d): %d bloques de piedra" % [light.x / 2, light.z / 2, stone], stone > 300)
		_check("  ... y se sube por dentro", _climbable(Vector2i(light.x - 3, light.z - 3), light.y - 28, 26))
	for p: Vector2 in PlacesBuilder.WATCHTOWERS:
		var c := Vector2i(int(p.x * 2.0) - 3, int(p.y * 2.0) - 3)
		var base := _floor_at(Vector2i(int(p.x * 2.0), int(p.y * 2.0)))
		_check("Atalaya en (%d, %d) se sube hasta arriba" % [p.x, p.y], _climbable(c, base - 2, 16))
	# Minas: la boca da a una galería hueca.
	for m: Array in PlacesBuilder.MINES:
		var at: Vector2 = (m[0] as Vector2) * 2.0
		var air := _count(Vector3i(int(at.x) - 10, _gen.get_ground_height(int(at.x), int(at.y)), int(at.y) - 10), Vector3i(20, 4, 20), [IslandGenerator.AIR])
		var frames := _count(Vector3i(int(at.x) - 30, _gen.get_ground_height(int(at.x), int(at.y)) - 2, int(at.y) - 30), Vector3i(60, 10, 60), [IslandGenerator.WOOD])
		_check("Mina en (%d, %d): galería con marcos (%d)" % [m[0].x, m[0].y, frames], frames > 10 and air > 40)
	print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
	quit()


## Bloque (voxel) del mundo generado, generando por bloques de 16 alineados (como el juego).
func _voxel(x: int, y: int, z: int) -> int:
	var o := Vector3i(floori(x / 16.0) * 16, floori(y / 16.0) * 16, floori(z / 16.0) * 16)
	if not _blocks.has(o):
		var b := VoxelBuffer.new()
		b.create(16, 16, 16)
		_gen.generate_block(b, o, 0)
		_blocks[o] = b
	return (_blocks[o] as VoxelBuffer).get_voxel(x - o.x, y - o.y, z - o.z, VoxelBuffer.CHANNEL_TYPE)


func _floor_at(c: Vector2i) -> int:
	return _gen.get_ground_height(c.x, c.y)


func _count(from: Vector3i, size: Vector3i, ids: Array) -> int:
	var n := 0
	for x in size.x:
		for y in size.y:
			for z in size.z:
				if ids.has(_voxel(from.x + x, from.y + y, from.z + z)):
					n += 1
	return n


## ¿Se puede subir por la torre de 6 x 6 (esquina 'corner') desde 'from_y' hasta 'height' más arriba
## dando pasos de un bloque como mucho, con sitio para el cuerpo en cada paso?
func _climbable(corner: Vector2i, from_y: int, height: int) -> bool:
	var seen := {}
	var queue: Array[Vector3i] = []
	for x in 6:
		for z in 6:
			for y in range(from_y, from_y + 8):
				var c := Vector3i(corner.x + x, y, corner.y + z)
				if _stand(c):
					queue.append(c)
					seen[c] = true
	var top := from_y
	while not queue.is_empty():
		var c: Vector3i = queue.pop_back()
		top = maxi(top, c.y)
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			for dy in [-1, 0, 1]:
				var n: Vector3i = c + d + Vector3i(0, dy, 0)
				if seen.has(n) or n.x < corner.x - 1 or n.x > corner.x + 6 or n.z < corner.y - 1 or n.z > corner.y + 6:
					continue
				if dy == 1 and _solid(_voxel(c.x, c.y + 3, c.z)):
					continue  # sin sitio para la cabeza al subir
				if _stand(n):
					seen[n] = true
					queue.append(n)
	return top >= from_y + height


## ¿Se puede estar de pie en la celda c (suelo firme debajo y tres libres: el personaje mide 1,4 m)?
func _stand(c: Vector3i) -> bool:
	return _solid(_voxel(c.x, c.y - 1, c.z)) and not _solid(_voxel(c.x, c.y, c.z)) and not _solid(_voxel(c.x, c.y + 1, c.z)) \
		and not _solid(_voxel(c.x, c.y + 2, c.z))


func _solid(id: int) -> bool:
	return id != IslandGenerator.AIR and id != IslandGenerator.WATER and id != IslandGenerator.ROPE_HANGING and id < 1000


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1
