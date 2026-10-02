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
	"snow": IslandGenerator.SNOW,
	"wood": IslandGenerator.WOOD,
	"leaves": IslandGenerator.LEAVES,
	"pine_leaves": IslandGenerator.PINE_LEAVES,
	"corrupt_soil": IslandGenerator.CORRUPT_SOIL,
	"dead_wood": IslandGenerator.DEAD_WOOD,
	"wheat": IslandGenerator.WHEAT,
	"water": IslandGenerator.WATER,
}

## Qué objeto suelta cada bloque al romperlo ("" = nada). La hierba suelta tierra, como en
## Minecraft; el agua no se puede romper.
const DROPS := {
	IslandGenerator.GRASS: "dirt",
	IslandGenerator.DIRT: "dirt",
	IslandGenerator.STONE: "stone",
	IslandGenerator.SAND: "sand",
	IslandGenerator.SNOW: "snow",
	IslandGenerator.WOOD: "wood",
	IslandGenerator.LEAVES: "leaves",
	IslandGenerator.PINE_LEAVES: "pine_leaves",
	IslandGenerator.CORRUPT_SOIL: "corrupt_soil",
	IslandGenerator.DEAD_WOOD: "dead_wood",
	IslandGenerator.WHEAT: "wheat",
}

static var _icons := {}


static func exists(id: String) -> bool:
	return BLOCK_ITEMS.has(id)


static func display_name(id: String) -> String:
	if BLOCK_ITEMS.has(id):
		return Blocks.name_of(BLOCK_ITEMS[id])
	return id


## Bloque que coloca el objeto, o -1 si no es un bloque.
static func block_of(id: String) -> int:
	return BLOCK_ITEMS.get(id, -1)


static func max_stack(_id: String) -> int:
	return MAX_STACK


## Objeto que se obtiene al romper un bloque ("" si no suelta nada).
static func drop_of(block_id: int) -> String:
	return DROPS.get(block_id, "")


## Objeto que corresponde a un bloque (para el modo creativo), o "".
static func item_of_block(block_id: int) -> String:
	for id in BLOCK_ITEMS:
		if BLOCK_ITEMS[id] == block_id:
			return id
	return ""


## Icono del objeto: la cara de arriba de su bloque.
static func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var region := AtlasTexture.new()
	region.atlas = BlockTextures.atlas()
	region.region = BlockTextures.icon_region(block_of(id))
	_icons[id] = region
	return region
