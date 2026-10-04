class_name TreeParts
## Piezas de nuestros árboles (robles, pinos, muertos...): hechas con los mismos colores lisos y
## cubitos que los árboles de Kenney (tools/bake_prefabs.gd las crea en el prefab "tree_parts"),
## para que todos los árboles de la isla parezcan del mismo juego. Hojas enteras y con los bordes
## redondeados (la piel de la copa), tronco fino (de pie y tumbado) y tronco grueso.

enum { LEAF, LEAF_ROUND, PINE, PINE_ROUND, TRUNK, TRUNK_X, TRUNK_Z, DEAD, DEAD_X, DEAD_Z, THICK }

const PREFAB := "tree_parts"
const COUNT := 11

static var _first := -1


## Id de bloque de una pieza.
static func id(part: int) -> int:
	if _first < 0:
		_first = PrefabLibrary.first_id(PREFAB)
	return _first + part


## Qué pieza es este bloque (o -1 si no es una pieza de árbol nuestra).
static func part_of(block_id: int) -> int:
	if _first < 0:
		_first = PrefabLibrary.first_id(PREFAB)
	if _first < 0 or block_id < _first or block_id >= _first + COUNT:
		return -1
	return block_id - _first


static func is_dead(block_id: int) -> bool:
	return part_of(block_id) in [DEAD, DEAD_X, DEAD_Z]


static func is_pine(block_id: int) -> bool:
	return part_of(block_id) in [PINE, PINE_ROUND]


## El objeto que da al romperse.
static func item_of(block_id: int) -> String:
	match part_of(block_id):
		LEAF, LEAF_ROUND: return "leaves"
		PINE, PINE_ROUND: return "pine_leaves"
		DEAD, DEAD_X, DEAD_Z: return "dead_wood"
	return "wood"

