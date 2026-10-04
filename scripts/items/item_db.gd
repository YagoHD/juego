class_name ItemDB
## Catálogo de objetos. Cada objeto tiene un id de texto, un nombre, el bloque que coloca (si es
## un bloque; -1 si no) y cuántos caben en un montón. De momento hay un objeto por cada bloque;
## los objetos que no son bloques (tablones, cuerda, comida...) se añadirán aquí.

const MAX_STACK := 64

## id del objeto -> bloque que coloca.
const BLOCK_ITEMS := {
	"grass": IslandGenerator.GRASS,
	"dirt": IslandGenerator.DIRT,
	"stone": IslandGenerator.STONE,
	"sand": IslandGenerator.SAND,
	"wet_sand": IslandGenerator.WET_SAND,
	"gravel": IslandGenerator.GRAVEL,
	"clay": IslandGenerator.CLAY,
	"mud": IslandGenerator.MUD,
	"snow": IslandGenerator.SNOW,
	"wood": IslandGenerator.WOOD,
	"leaves": IslandGenerator.LEAVES,
	"pine_leaves": IslandGenerator.PINE_LEAVES,
	"corrupt_soil": IslandGenerator.CORRUPT_SOIL,
	"dead_wood": IslandGenerator.DEAD_WOOD,
	"wheat_crop": IslandGenerator.WHEAT,
	"water": IslandGenerator.WATER,
	"chest": IslandGenerator.CHEST,
	"planks": IslandGenerator.PLANKS,
	"cloth": IslandGenerator.CLOTH,
	"mossy_stone": IslandGenerator.MOSSY_STONE,
	"driftwood": IslandGenerator.DRIFTWOOD,
	"workbench": IslandGenerator.WORKBENCH,
}

## Qué objeto suelta cada bloque al romperlo ("" = nada). La hierba suelta tierra, como en
## Minecraft; el agua no se puede romper.
const DROPS := {
	IslandGenerator.GRASS: "dirt",
	IslandGenerator.DIRT: "dirt",
	IslandGenerator.STONE: "stone",
	IslandGenerator.SAND: "sand",
	IslandGenerator.WET_SAND: "wet_sand",
	IslandGenerator.GRAVEL: "gravel",
	IslandGenerator.CLAY: "clay",
	IslandGenerator.MUD: "mud",
	IslandGenerator.STUMP: "wood",  # el tocón da madera
	IslandGenerator.SNOW: "snow",
	IslandGenerator.WOOD: "wood",
	IslandGenerator.LEAVES: "leaves",
	IslandGenerator.PINE_LEAVES: "pine_leaves",
	IslandGenerator.CORRUPT_SOIL: "corrupt_soil",
	IslandGenerator.DEAD_WOOD: "dead_wood",
	IslandGenerator.WHEAT: "wheat",
	IslandGenerator.CHEST: "chest",
	IslandGenerator.PLANKS: "planks",
	IslandGenerator.CLOTH: "cloth",
	IslandGenerator.MOSSY_STONE: "mossy_stone",
	IslandGenerator.DRIFTWOOD: "driftwood",
	IslandGenerator.WORKBENCH: "workbench",
	IslandGenerator.ORE: "green_ore",
	IslandGenerator.LOG_X: "wood",
	IslandGenerator.LOG_Z: "wood",
	IslandGenerator.DEAD_LOG_X: "dead_wood",
	IslandGenerator.DEAD_LOG_Z: "dead_wood",
}

## Objetos que no son bloques. "wear": hueco de equipo donde se lleva; "pockets": huecos de
## barra que añade; "storage": huecos de inventario que añade.
const OTHER_ITEMS := {
	"rope": {"name": "Cuerda", "stack": 64},
	"fiber": {"name": "Fibra", "stack": 64},
	"seeds": {"name": "Semillas", "stack": 64},
	"insect": {"name": "Insecto", "stack": 32},
	"roasted_insect": {"name": "Insecto asado", "stack": 32},
	"roasted_berries": {"name": "Bayas asadas", "stack": 24},
	"roasted_seeds": {"name": "Semillas tostadas", "stack": 64},
	"mushroom": {"name": "Seta", "stack": 32},
	"roasted_mushroom": {"name": "Seta asada", "stack": 32},
	"rock": {"name": "Piedra", "stack": 32},
	"flint": {"name": "Pedernal", "stack": 32},
	"sharp_rock": {"name": "Piedra afilada", "stack": 16},
	"shell": {"name": "Concha", "stack": 32},
	"flower_red": {"name": "Flor roja", "stack": 32},
	"flower_yellow": {"name": "Flor amarilla", "stack": 32},
	"resin": {"name": "Resina", "stack": 32},
	"leaf": {"name": "Hoja", "stack": 64},
	"pine_needles": {"name": "Agujas de pino", "stack": 64},
	"bark": {"name": "Corteza", "stack": 64},
	"board": {"name": "Tabla", "stack": 16},
	"campfire": {"name": "Hoguera", "stack": 4},
	"green_ore": {"name": "Mineral verde", "stack": 32},
	"bedroll": {"name": "Saco de dormir", "stack": 1},
	"raft": {"name": "Balsa", "stack": 1},
	"spear": {"name": "Lanza", "stack": 1},
	"raw_fish": {"name": "Pescado crudo", "stack": 16},
	"cooked_fish": {"name": "Pescado asado", "stack": 16},
	"flatbread": {"name": "Torta de pan", "stack": 16},
	"raw_crab": {"name": "Cangrejo", "stack": 16},
	"cooked_crab": {"name": "Cangrejo asado", "stack": 16},
	"wheat": {"name": "Manojo de trigo", "stack": 32},
	"sticks": {"name": "Palo", "stack": 32},
	"stone_knife": {"name": "Cuchillo de piedra", "stack": 1},
	"stone_axe": {"name": "Hacha de piedra", "stack": 1},
	"stone_pick": {"name": "Pico de piedra", "stack": 1},
	"torch": {"name": "Antorcha", "stack": 16},
	# Se lee con J; al recogerlo no ocupa hueco (va siempre con el personaje).
	"captain_journal": {"name": "Diario del capitán", "stack": 1},
	"berries": {"name": "Bayas silvestres", "stack": 24},
	"shirt": {"name": "Camiseta", "stack": 1, "wear": "shirt", "pockets": 2},
	"pants": {"name": "Pantalón", "stack": 1, "wear": "pants", "pockets": 2},
	"belt": {"name": "Cinturón", "stack": 1, "wear": "belt", "pockets": 2},
	"backpack": {"name": "Mochila de marinero", "stack": 1, "wear": "backpack", "storage": 18},
	"rough_backpack": {"name": "Mochila improvisada", "stack": 1, "wear": "backpack", "storage": 9},
	# Notas: al leerlas (clic derecho) se aprende la receta "teaches".
	"note_belt": {"name": "Nota: cinturón", "stack": 1, "teaches": "belt"},
	"note_backpack": {"name": "Nota: mochila", "stack": 1, "teaches": "rough_backpack"},
	"note_pick": {"name": "Nota: pico", "stack": 1, "teaches": "stone_pick"},
}

static var _icons := {}


static func exists(id: String) -> bool:
	return BLOCK_ITEMS.has(id) or OTHER_ITEMS.has(id)


static func display_name(id: String) -> String:
	if BLOCK_ITEMS.has(id):
		return Blocks.name_of(BLOCK_ITEMS[id])
	if OTHER_ITEMS.has(id):
		return OTHER_ITEMS[id]["name"]
	return id


## Bloque que coloca el objeto, o -1 si no es un bloque.
static func block_of(id: String) -> int:
	return BLOCK_ITEMS.get(id, -1)


static func max_stack(id: String) -> int:
	if OTHER_ITEMS.has(id):
		return OTHER_ITEMS[id]["stack"]
	return MAX_STACK


## Hueco de equipo donde se lleva ("shirt", "pants", "belt", "backpack"), o "" si no se lleva.
static func wear_slot(id: String) -> String:
	return OTHER_ITEMS.get(id, {}).get("wear", "")


## Huecos de barra (bolsillos) que añade al llevarlo puesto.
static func pockets(id: String) -> int:
	return OTHER_ITEMS.get(id, {}).get("pockets", 0)


## Huecos de inventario que añade al llevarlo puesto (la mochila).
static func storage(id: String) -> int:
	return OTHER_ITEMS.get(id, {}).get("storage", 0)


## Receta que enseña al leerlo (las notas), o "".
static func teaches(id: String) -> String:
	return OTHER_ITEMS.get(id, {}).get("teaches", "")


## Cuántas veces más rápido rompe este bloque con este objeto en la mano (1 = como a mano).
static func tool_speed(item_id: String, block_id: int) -> float:
	var woody := [IslandGenerator.WOOD, IslandGenerator.DEAD_WOOD, IslandGenerator.DRIFTWOOD, IslandGenerator.PLANKS, IslandGenerator.CHEST, IslandGenerator.WORKBENCH,
		IslandGenerator.LOG_X, IslandGenerator.LOG_Z, IslandGenerator.DEAD_LOG_X, IslandGenerator.DEAD_LOG_Z, IslandGenerator.STUMP]
	var rocky := [IslandGenerator.STONE, IslandGenerator.MOSSY_STONE, IslandGenerator.ORE]
	var soft := [IslandGenerator.LEAVES, IslandGenerator.PINE_LEAVES, IslandGenerator.CLOTH, IslandGenerator.WHEAT]
	if PrefabLibrary.is_prefab(block_id):  # troncos, hojas y rocas de los árboles y prefabs
		match PrefabLibrary.kind(block_id):
			"wood", "root": woody.append(block_id)
			"leaves": soft.append(block_id)
			"rock": rocky.append(block_id)
	match item_id:
		"stone_pick":
			if rocky.has(block_id):
				return 3.0
		"stone_axe":
			if woody.has(block_id):
				return 4.0
			if soft.has(block_id):
				return 2.0
		"stone_knife":
			if soft.has(block_id):
				return 3.0
			if woody.has(block_id):
				return 1.3
	return 1.0


## Usos de cada herramienta antes de romperse (las que no están aquí no se gastan).
const DURABILITY := {"stone_axe": 80, "stone_pick": 80, "stone_knife": 60, "spear": 40}


static func max_durability(id: String) -> int:
	return DURABILITY.get(id, 0)


## Lo que da un bloque al romperlo: [[id, cantidad], ...]. La decoración del suelo tiene suerte:
## la hierba da fibra casi siempre, a veces semillas y rara vez un insecto; las piedrecitas,
## a veces pedernal.
static func drops_for(block_id: int, rng: RandomNumberGenerator) -> Array:
	var roll := rng.randf()
	if PrefabLibrary.is_prefab(block_id):
		if PrefabLibrary.prefab_of(block_id) == "wheat_a":  # trigo verde: solo devuelve la semilla
			return [["seeds", 1]]
		if PrefabLibrary.prefab_of(block_id) == "wheat_b":  # trigo maduro
			return [["wheat", 2 + int(roll < 0.5)], ["seeds", 1 + int(rng.randf() < 0.5)]]
		var owner := PrefabLibrary.prefab_of(block_id)
		if owner.begins_with("t_berry") and PrefabLibrary.kind(block_id) == "leaves":  # arbusto de bayas
			if roll < 0.7: return [["berries", 1 + int(rng.randf() < 0.5)]]
			return [["fiber", 1]]
		if owner in ["bush", "bush_large", "t_bush_1", "t_bush_2"] and PrefabLibrary.kind(block_id) == "leaves":  # los arbustos dan bayas (o fibra)
			if roll < 0.55: return [["berries", 1 + int(rng.randf() < 0.4)]]
			return [["fiber", 1]] if roll < 0.8 else []
		if owner.begins_with("t_"):  # nuestros árboles: madera, madera seca, hojas, agujas...
			var item := PrefabLibrary.tree_item(block_id)
			if PrefabLibrary.kind(block_id) != "leaves":  # tronco o raíz
				return [[item, 1]]
			return [[item, 1 + int(roll < 0.25)]] if roll < 0.6 else ([["fiber", 1]] if roll < 0.75 else [])
		match PrefabLibrary.kind(block_id):
			"wood": return [["wood", 1]]
			"rock": return [["rock", 1 + int(roll < 0.5)]] if roll > 0.08 else [["flint", 1]]
			"leaves": return [["leaf", 1 + int(roll < 0.25)]] if roll < 0.6 else ([["fiber", 1]] if roll < 0.75 else [])
			"mushroom": return [["mushroom", 1 + int(roll < 0.3)]]
		return []
	match block_id:
		IslandGenerator.TALL_GRASS:
			if roll < 0.68: return [["fiber", 1 + int(rng.randf() < 0.3)]]
			if roll < 0.84: return [["seeds", 1]]
			if roll < 0.92: return [["insect", 1]]
			return []
		IslandGenerator.PEBBLES:
			return [["flint", 1]] if roll < 0.15 else [["rock", 1 + int(rng.randf() < 0.4)]]
		IslandGenerator.GROUND_STICKS:
			return [["sticks", 1 + int(rng.randf() < 0.5)]]
		IslandGenerator.SHELL:
			return [["shell", 1]]
		IslandGenerator.FLOWER_RED:
			return [["flower_red", 1]]
		IslandGenerator.FLOWER_YELLOW:
			return [["flower_yellow", 1]]
	var drop := drop_of(block_id)
	return [] if drop == "" else [[drop, 1]]


## Objeto que se obtiene al romper un bloque ("" si no suelta nada).
static func drop_of(block_id: int) -> String:
	return DROPS.get(block_id, "")


## Objeto que corresponde a un bloque (para el modo creativo), o "".
static func item_of_block(block_id: int) -> String:
	for id in BLOCK_ITEMS:
		if BLOCK_ITEMS[id] == block_id:
			return id
	return ""


## Icono del objeto: la cara de arriba de su bloque, o un dibujo propio si no es un bloque.
static func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var tex: Texture2D
	if BLOCK_ITEMS.has(id):
		var region := AtlasTexture.new()
		region.atlas = BlockTextures.atlas()
		region.region = BlockTextures.icon_region(block_of(id))
		tex = region
	else:
		tex = ImageTexture.create_from_image(ItemPainter.paint(id))
	_icons[id] = tex
	return tex
