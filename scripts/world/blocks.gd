class_name Blocks
## Catálogo de bloques: colores, nombres y el orden de la barra de bloques.
## Los IDs vienen de IslandGenerator (deben coincidir con IslandBaker.cs y con la librería).

const COLORS := {
	IslandGenerator.GRASS: Color(0.37, 0.65, 0.33),
	IslandGenerator.DIRT: Color(0.55, 0.40, 0.26),
	IslandGenerator.STONE: Color(0.50, 0.50, 0.52),
	IslandGenerator.SAND: Color(0.88, 0.80, 0.56),
	IslandGenerator.WET_SAND: Color(0.72, 0.58, 0.32),
	IslandGenerator.GRAVEL: Color(0.55, 0.53, 0.52),
	IslandGenerator.CLAY: Color(0.78, 0.40, 0.20),
	IslandGenerator.MUD: Color(0.40, 0.27, 0.16),
	IslandGenerator.STUMP: Color(0.47, 0.30, 0.16),
	IslandGenerator.SLAB_DOWN: Color(0.66, 0.50, 0.31), IslandGenerator.SLAB_UP: Color(0.66, 0.50, 0.31),
	IslandGenerator.SLAB_N: Color(0.66, 0.50, 0.31), IslandGenerator.SLAB_S: Color(0.66, 0.50, 0.31),
	IslandGenerator.SLAB_W: Color(0.66, 0.50, 0.31), IslandGenerator.SLAB_E: Color(0.66, 0.50, 0.31),
	IslandGenerator.ROPE_HANGING: Color(0.72, 0.60, 0.38),
	IslandGenerator.SAIL_X: Color(0.86, 0.82, 0.72), IslandGenerator.SAIL_Z: Color(0.86, 0.82, 0.72),
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
	IslandGenerator.WORKBENCH: Color(0.6, 0.44, 0.26),
	IslandGenerator.LOG_X: Color(0.45, 0.30, 0.17),
	IslandGenerator.LOG_Z: Color(0.45, 0.30, 0.17),
	IslandGenerator.DEAD_LOG_X: Color(0.22, 0.18, 0.17),
	IslandGenerator.DEAD_LOG_Z: Color(0.22, 0.18, 0.17),
	IslandGenerator.TALL_GRASS: Color(0.36, 0.6, 0.25),
	IslandGenerator.FLOWER_RED: Color(0.8, 0.2, 0.2),
	IslandGenerator.FLOWER_YELLOW: Color(0.92, 0.8, 0.25),
	IslandGenerator.PEBBLES: Color(0.55, 0.55, 0.55),
	IslandGenerator.GROUND_STICKS: Color(0.45, 0.32, 0.18),
	IslandGenerator.SHELL: Color(0.95, 0.86, 0.78),
	IslandGenerator.ORE: Color(0.45, 0.6, 0.48),
}

const NAMES := {
	IslandGenerator.GRASS: "Hierba",
	IslandGenerator.DIRT: "Tierra",
	IslandGenerator.STONE: "Piedra",
	IslandGenerator.SAND: "Arena",
	IslandGenerator.WET_SAND: "Arena mojada",
	IslandGenerator.GRAVEL: "Grava",
	IslandGenerator.CLAY: "Arcilla",
	IslandGenerator.MUD: "Barro",
	IslandGenerator.STUMP: "Tocón",
	IslandGenerator.SLAB_DOWN: "Media losa de tablones", IslandGenerator.SLAB_UP: "Media losa de tablones",
	IslandGenerator.SLAB_N: "Media losa de tablones", IslandGenerator.SLAB_S: "Media losa de tablones",
	IslandGenerator.SLAB_W: "Media losa de tablones", IslandGenerator.SLAB_E: "Media losa de tablones",
	IslandGenerator.ROPE_HANGING: "Cuerda colgante",
	IslandGenerator.SAIL_X: "Vela", IslandGenerator.SAIL_Z: "Vela",
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
	IslandGenerator.WORKBENCH: "Mesa de trabajo",
	IslandGenerator.LOG_X: "Tronco caído",
	IslandGenerator.LOG_Z: "Tronco caído",
	IslandGenerator.DEAD_LOG_X: "Tronco seco caído",
	IslandGenerator.DEAD_LOG_Z: "Tronco seco caído",
	IslandGenerator.TALL_GRASS: "Hierba alta",
	IslandGenerator.FLOWER_RED: "Flor roja",
	IslandGenerator.FLOWER_YELLOW: "Flor amarilla",
	IslandGenerator.PEBBLES: "Piedras sueltas",
	IslandGenerator.GROUND_STICKS: "Palos",
	IslandGenerator.SHELL: "Concha",
	IslandGenerator.ORE: "Veta de mineral verde",
}

## Bloques de la barra (teclas 1-9, en este orden).
const HOTBAR: Array[int] = [
	IslandGenerator.GRASS, IslandGenerator.DIRT, IslandGenerator.STONE,
	IslandGenerator.SAND, IslandGenerator.SNOW, IslandGenerator.WOOD,
	IslandGenerator.LEAVES, IslandGenerator.WATER, IslandGenerator.WHEAT,
]

const LAST_ID := IslandGenerator.SAIL_Z



## Medias losas de tablones y la caja que ocupa cada una (espacio 0..1 del bloque).
const SLABS := {
	IslandGenerator.SLAB_DOWN: AABB(Vector3.ZERO, Vector3(1, 0.5, 1)),
	IslandGenerator.SLAB_UP: AABB(Vector3(0, 0.5, 0), Vector3(1, 0.5, 1)),
	IslandGenerator.SLAB_N: AABB(Vector3.ZERO, Vector3(1, 1, 0.5)),
	IslandGenerator.SLAB_S: AABB(Vector3(0, 0, 0.5), Vector3(1, 1, 0.5)),
	IslandGenerator.SLAB_W: AABB(Vector3.ZERO, Vector3(0.5, 1, 1)),
	IslandGenerator.SLAB_E: AABB(Vector3(0.5, 0, 0), Vector3(0.5, 1, 1)),
}
## Láminas y cuerdas (finas): la caja que ocupan.
const THIN := {
	IslandGenerator.ROPE_HANGING: AABB(Vector3(0.44, 0, 0.44), Vector3(0.12, 1, 0.12)),
	IslandGenerator.SAIL_X: AABB(Vector3(0.47, 0, 0), Vector3(0.06, 1, 1)),
	IslandGenerator.SAIL_Z: AABB(Vector3(0, 0, 0.47), Vector3(1, 1, 0.06)),
}

## Agua de cualquier tipo (fuente, cayendo o corriendo).
static func is_water(id: int) -> bool:
	return id == IslandGenerator.WATER or (id >= IslandGenerator.WATER_FALL and id <= IslandGenerator.WATER_FLOW_1 + 6)

## Cosas pequeñas del suelo: no son cubos, no chocan y se recogen con la mano al momento.
const DECOR := [IslandGenerator.TALL_GRASS, IslandGenerator.FLOWER_RED, IslandGenerator.FLOWER_YELLOW,
	IslandGenerator.PEBBLES, IslandGenerator.GROUND_STICKS, IslandGenerator.SHELL]


static func is_decor(id: int) -> bool:
	return DECOR.has(id) or PrefabLibrary.is_soft(id)


## Segundos que se tarda en romper cada bloque a mano (las herramientas lo aceleran, ver
## ItemDB.tool_speed). El agua y los que no están se rompen al momento.
const HARDNESS := {
	IslandGenerator.LEAVES: 0.3, IslandGenerator.PINE_LEAVES: 0.3, IslandGenerator.WHEAT: 0.1,
	IslandGenerator.CLOTH: 0.35, IslandGenerator.SNOW: 0.4, IslandGenerator.SAND: 0.55,
	IslandGenerator.WET_SAND: 0.6, IslandGenerator.GRAVEL: 0.7, IslandGenerator.CLAY: 0.75, IslandGenerator.MUD: 0.5, IslandGenerator.STUMP: 2.4,
	IslandGenerator.SLAB_DOWN: 1.0, IslandGenerator.SLAB_UP: 1.0, IslandGenerator.SLAB_N: 1.0, IslandGenerator.SLAB_S: 1.0,
	IslandGenerator.SLAB_W: 1.0, IslandGenerator.SLAB_E: 1.0, IslandGenerator.ROPE_HANGING: 0.3,
	IslandGenerator.SAIL_X: 0.35, IslandGenerator.SAIL_Z: 0.35,
	IslandGenerator.DIRT: 0.6, IslandGenerator.GRASS: 0.7, IslandGenerator.CORRUPT_SOIL: 0.9,
	IslandGenerator.DRIFTWOOD: 1.6, IslandGenerator.DEAD_WOOD: 1.8, IslandGenerator.PLANKS: 1.8,
	IslandGenerator.CHEST: 1.8, IslandGenerator.WORKBENCH: 1.8, IslandGenerator.WOOD: 2.4,
	IslandGenerator.LOG_X: 2.4, IslandGenerator.LOG_Z: 2.4, IslandGenerator.DEAD_LOG_X: 1.8, IslandGenerator.DEAD_LOG_Z: 1.8,
	IslandGenerator.TALL_GRASS: 0.05, IslandGenerator.FLOWER_RED: 0.05, IslandGenerator.FLOWER_YELLOW: 0.05,
	IslandGenerator.PEBBLES: 0.05, IslandGenerator.GROUND_STICKS: 0.05, IslandGenerator.SHELL: 0.05,
	IslandGenerator.ORE: 7.0,
	IslandGenerator.MOSSY_STONE: 2.6, IslandGenerator.STONE: 3.0,
}


static func hardness(id: int) -> float:
	if PrefabLibrary.is_prefab(id):
		return {"wood": 2.0, "root": 1.6, "rock": 2.6, "leaves": 0.25, "mushroom": 0.05, "crop": 0.05}.get(PrefabLibrary.kind(id), 0.5)
	return HARDNESS.get(id, 0.0)


static func color_of(id: int) -> Color:
	if PrefabLibrary.is_prefab(id):
		return PrefabLibrary.color(id)
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
