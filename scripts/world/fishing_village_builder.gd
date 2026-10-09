extends RefCounted
class_name FishingVillageBuilder
## El pueblo pesquero destruido (A6, junto al naufragio): casas quemadas sin tejado y con muros
## rotos, escombros, el muelle partido y la casa grande de los Valdés, de piedra, con las pistas del
## ataque (docs/HISTORIA_NOMBRES.md). Lo estampa Structures; las pistas las pone main.gd (Clue).

## Centro del pueblo (metros), sobre el llano que deja el horneador junto a la cala del oeste.
const CENTER := Vector2(-188.0, 64.0)
## Casas: [desplazamiento (m), tamaño (m)]. La primera es la de los Valdés.
const HOUSES := [
	[Vector2(-4, -8), Vector2(7, 6)],
	[Vector2(8, -12), Vector2(4, 4)], [Vector2(12, -2), Vector2(4, 5)], [Vector2(6, 8), Vector2(5, 4)],
	[Vector2(-8, 8), Vector2(4, 4)], [Vector2(-16, 0), Vector2(4, 4)], [Vector2(18, 8), Vector2(4, 4)],
]
const DOCK_DIR := Vector2(-0.82, 0.57)   # el muelle sale hacia la cala (oeste-suroeste)


## Levanta el pueblo. 'put' es Structures._put. Devuelve las pistas: [{fact, cell, kind, text}].
static func build(gen: IslandGenerator, put: Callable) -> Array:
	var clues: Array = []
	var center := CENTER * 2.0
	for i in HOUSES.size():
		var at: Vector2 = center + HOUSES[i][0] * 2.0
		var size: Vector2 = HOUSES[i][1] * 2.0
		var info := _burnt_house(gen, put, at, size, i, i == 0)
		if i == 0:
			# La casa grande: el joyero vacío en el suelo y el escudo de los Valdés en la pared.
			clues.append({"fact": "joyero_vacio", "cell": info["inside"], "kind": "jewel_box",
				"text": "Un joyero de madera fina, abierto y vacío. En el fondo queda un polvo morado que brilla un poco."})
			clues.append({"fact": "escudo_valdes", "cell": info["wall"], "kind": "shield",
				"text": "Un escudo tallado sobre la chimenea: un barco y una V. «Valdés, armadores», dice debajo."})
		elif i == 2:
			put.call(info["door"], IslandGenerator.DEAD_WOOD)  # el tablón pintado sigue en pie
			clues.append({"fact": "emblema_ojo_pesquero", "cell": info["door"], "kind": "eye_door",
				"text": "En la puerta quemada alguien pintó un ojo cerrado, con pintura negra. No es de aquí."})
	_dock(gen, put, center + Vector2(-26, 14))
	return clues


## Casa quemada: muros de piedra abajo y madera quemada arriba, con huecos y sin tejado; dentro,
## vigas caídas. Devuelve celdas útiles para las pistas: dentro, una pared y la puerta.
static func _burnt_house(gen: IslandGenerator, put: Callable, at: Vector2, size: Vector2, seed: int, big: bool) -> Dictionary:
	var w := int(size.x)
	var d := int(size.y)
	var x0 := int(at.x) - w / 2
	var z0 := int(at.y) - d / 2
	var base := VillageBuilder._level(gen, put, x0, z0, w, d, 10)
	var walls := 7 if big else 5
	for x in w:
		for z in d:
			var edge_x := x == 0 or x == w - 1
			var edge_z := z == 0 or z == d - 1
			put.call(Vector3i(x0 + x, base - 1, z0 + z), IslandGenerator.GRAVEL if _hash(x, z, seed) < 0.4 else IslandGenerator.PLANKS)
			if not (edge_x or edge_z):
				if _hash(x, z, seed + 7) < 0.08:  # escombros por el suelo
					put.call(Vector3i(x0 + x, base, z0 + z), IslandGenerator.MOSSY_STONE if big else IslandGenerator.DEAD_WOOD)
				continue
			# Altura rota del muro en este punto (más entero en las esquinas).
			var corner := edge_x and edge_z
			var top := walls if corner else int(2 + _hash(x, z, seed + 3) * (walls - 1))
			for y in top:
				if z == d - 1 and absi(x - w / 2) <= 1 and y < 4:
					continue  # el hueco de la puerta (al sur)
				var id := IslandGenerator.STONE if (y < 2 or big) else IslandGenerator.DEAD_WOOD
				if corner:
					id = IslandGenerator.DEAD_WOOD if not big else IslandGenerator.STONE
				if _hash(x * 3 + y, z, seed + 11) < 0.12:
					continue  # agujeros del fuego
				put.call(Vector3i(x0 + x, base + y, z0 + z), id)
	# Una viga caída en diagonal dentro.
	for k in mini(w, d) - 2:
		put.call(Vector3i(x0 + 1 + k, base + maxi(0, 2 - k / 2), z0 + 1 + k), IslandGenerator.DEAD_WOOD)
	return {"inside": Vector3i(x0 + w / 2, base, z0 + d / 2 - 1), "wall": Vector3i(x0 + w / 2, base + 3, z0 + 1),
		"door": Vector3i(x0 + w / 2 + 2, base + 2, z0 + d - 1)}  # el muro junto a la puerta


## Muelle de tablones sobre postes que sale de la orilla hacia la cala, partido a la mitad.
static func _dock(gen: IslandGenerator, put: Callable, start: Vector2) -> void:
	var dir := DOCK_DIR.normalized()
	var side := dir.orthogonal()
	var deck := IslandGenerator.SEA_LEVEL + 2
	for k in 44:
		if k > 22 and k < 27:
			continue  # el trozo hundido
		for s in range(-2, 2):
			var p := start + dir * float(k) + side * (float(s) + 0.5)
			var cell := Vector3i(floori(p.x), deck, floori(p.y))
			if gen.get_ground_height(cell.x, cell.z) > deck + 1:
				continue  # aún en tierra
			var broken := k > 26 and _hash(k, s, 5) < 0.18
			if not broken:
				put.call(cell, IslandGenerator.PLANKS)
			if k % 5 == 0 and (s == -2 or s == 1):
				for y in range(gen._height_at(cell.x, cell.z), deck + (2 if not broken else 0)):
					put.call(Vector3i(cell.x, y, cell.z), IslandGenerator.WOOD)


static func _hash(x: int, z: int, salt: int) -> float:
	return Structures._hash(x, z, salt)
