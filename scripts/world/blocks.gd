class_name Blocks
## Catálogo de bloques: colores, nombres y el orden de la barra de bloques.
## Los IDs vienen de IslandGenerator (deben coincidir con IslandBaker.cs y con la librería).

const COLORS := {
	IslandGenerator.GRASS: Color(0.37, 0.65, 0.33),
	IslandGenerator.DIRT: Color(0.55, 0.40, 0.26),
	IslandGenerator.STONE: Color(0.50, 0.50, 0.52),
	IslandGenerator.SAND: Color(0.88, 0.80, 0.56),
	IslandGenerator.SNOW: Color(0.95, 0.96, 0.98),
	IslandGenerator.WOOD: Color(0.45, 0.30, 0.17),
	IslandGenerator.LEAVES: Color(0.24, 0.52, 0.22),
	IslandGenerator.WATER: Color(0.12, 0.45, 0.70, 0.74),
	IslandGenerator.PINE_LEAVES: Color(0.13, 0.33, 0.20),
	IslandGenerator.CORRUPT_SOIL: Color(0.30, 0.22, 0.32),
	IslandGenerator.DEAD_WOOD: Color(0.22, 0.18, 0.17),
	IslandGenerator.WHEAT: Color(0.90, 0.76, 0.30),
	IslandGenerator.CHEST: Color(0.55, 0.37, 0.19),
	IslandGenerator.PLANKS: Color(0.66, 0.50, 0.31),
	IslandGenerator.CLOTH: Color(0.86, 0.82, 0.72),
	IslandGenerator.MOSSY_STONE: Color(0.38, 0.43, 0.34),
	IslandGenerator.DRIFTWOOD: Color(0.40, 0.34, 0.25),
}

const NAMES := {
	IslandGenerator.GRASS: "Hierba",
	IslandGenerator.DIRT: "Tierra",
	IslandGenerator.STONE: "Piedra",
	IslandGenerator.SAND: "Arena",
	IslandGenerator.SNOW: "Nieve",
	IslandGenerator.WOOD: "Madera",
	IslandGenerator.LEAVES: "Hoja",
	IslandGenerator.WATER: "Agua",
	IslandGenerator.PINE_LEAVES: "Hoja de pino",
	IslandGenerator.CORRUPT_SOIL: "Tierra corrupta",
	IslandGenerator.DEAD_WOOD: "Madera muerta",
	IslandGenerator.WHEAT: "Trigo",
	IslandGenerator.CHEST: "Cofre",
	IslandGenerator.PLANKS: "Tablones",
	IslandGenerator.CLOTH: "Tela",
	IslandGenerator.MOSSY_STONE: "Piedra musgosa",
	IslandGenerator.DRIFTWOOD: "Madera de deriva",
}

## Bloques de la barra (teclas 1-9, en este orden).
const HOTBAR: Array[int] = [
	IslandGenerator.GRASS, IslandGenerator.DIRT, IslandGenerator.STONE,
	IslandGenerator.SAND, IslandGenerator.SNOW, IslandGenerator.WOOD,
	IslandGenerator.LEAVES, IslandGenerator.WATER, IslandGenerator.WHEAT,
]

const LAST_ID := IslandGenerator.DRIFTWOOD


## Segundos que se tarda en romper cada bloque a mano (las herramientas lo aceleran, ver
## ItemDB.tool_speed). El agua y los que no están se rompen al momento.
const HARDNESS := {
	IslandGenerator.LEAVES: 0.3, IslandGenerator.PINE_LEAVES: 0.3, IslandGenerator.WHEAT: 0.1,
	IslandGenerator.CLOTH: 0.35, IslandGenerator.SNOW: 0.4, IslandGenerator.SAND: 0.55,
	IslandGenerator.DIRT: 0.6, IslandGenerator.GRASS: 0.7, IslandGenerator.CORRUPT_SOIL: 0.9,
	IslandGenerator.DRIFTWOOD: 1.6, IslandGenerator.DEAD_WOOD: 1.8, IslandGenerator.PLANKS: 1.8,
	IslandGenerator.CHEST: 1.8, IslandGenerator.WOOD: 2.4,
	IslandGenerator.MOSSY_STONE: 2.6, IslandGenerator.STONE: 3.0,
}


static func hardness(id: int) -> float:
	return HARDNESS.get(id, 0.0)


static func color_of(id: int) -> Color:
	return COLORS.get(id, Color.MAGENTA)


static func name_of(id: int) -> String:
	return NAMES.get(id, "?")


## Material con el color del bloque. Si el bloque es translúcido (agua), lo respeta.
static func make_material(id: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var color := color_of(id)
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.08
	return material
