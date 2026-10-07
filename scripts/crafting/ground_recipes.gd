class_name GroundRecipes
## Recetas que se fabrican colocando objetos en el suelo, también apilados hacia arriba.
## Cada receta es una FORMA en capas (de abajo arriba). Cada capa son filas de letras: cada letra
## es un objeto y "." un hueco que debe quedar vacío. Por debajo hay una cuadrícula invisible de
## celdas de CELL metros: un objeto cuenta en la celda donde cae, esté en el punto que esté de
## ella. La forma vale girada o reflejada (no tumbada: lo de arriba va arriba).
##   "tools": letras que son herramientas (no se gastan al fabricar).
##   "surface": "workbench": solo sale encima de mesas de trabajo.
##   "dismantle": el objeto, dejado solo en el suelo, se puede desmontar; devuelve sus
##                materiales y el personaje aprende a hacerlo.
## Las recetas no se ven en ninguna lista: el personaje las aprende (notas, desmontar...) y
## quedan dibujadas en el diario del capitán.

const CELL := 0.25      # metros (medio bloque)
const MAX_LEVELS := 4   # objetos apilados como mucho en una columna

const RECIPES := {
	"bow": {
		"result": "bow", "count": 1, "action": "Atar", "time": 3.0,
		"layers": [["SR", "S.", "SR"]], "key": {"S": "sticks", "R": "rope"}, "dismantle": true,
	},
	"arrow": {
		"result": "arrow", "count": 4, "action": "Atar", "time": 1.5,
		"layers": [["PF", "SS"]], "key": {"P": "sharp_rock", "F": "feather", "S": "sticks"},
	},
	"wooden_shield": {
		"result": "wooden_shield", "count": 1, "action": "Montar", "time": 3.0,
		"layers": [["PPP", "PRP"]], "key": {"P": "planks", "R": "rope"}, "dismantle": true,
	},
	"rope": {
		"result": "rope", "count": 1, "action": "Retorcer", "time": 1.5,
		"layers": [["FFF"]], "key": {"F": "fiber"},
	},
	"sharp_rock": {
		"result": "sharp_rock", "count": 1, "action": "Golpear", "time": 1.5,
		"layers": [["R"], ["R"]], "key": {"R": "rock"},
	},
	"planks": {
		"result": "planks", "count": 4, "action": "Tallar", "time": 2.0,
		"layers": [["WK"]], "key": {"W": "wood", "K": "stone_knife"}, "tools": ["K"],
	},
	"sticks": {
		"result": "sticks", "count": 4, "action": "Tallar", "time": 1.5,
		"layers": [["PK"]], "key": {"P": "planks", "K": "stone_knife"}, "tools": ["K"],
	},
	"belt": {
		"result": "belt", "count": 1, "action": "Atar", "time": 2.0,
		"layers": [["CCC"]], "key": {"C": "rope"},
	},
	"rough_backpack": {
		"result": "rough_backpack", "count": 1, "action": "Coser", "time": 3.0,
		"layers": [["C.C", "TTT", "TTT"]], "key": {"C": "rope", "T": "cloth"},
	},
	"chest": {
		"result": "chest", "count": 1, "action": "Montar", "time": 3.0,
		"layers": [["PP", "PP"], ["PP", "PP"]], "key": {"P": "planks"}, "dismantle": true,
	},
	"stone_knife": {
		"result": "stone_knife", "count": 1, "action": "Atar", "time": 2.0,
		"layers": [["SR"], ["P."]], "key": {"S": "sticks", "R": "rope", "P": "sharp_rock"}, "dismantle": true,
	},
	"stone_axe": {
		"result": "stone_axe", "count": 1, "action": "Atar", "time": 2.5,
		"layers": [["SSR"], ["..P"]], "key": {"S": "sticks", "R": "rope", "P": "sharp_rock"}, "dismantle": true,
	},
	"workbench": {
		"result": "workbench", "count": 1, "action": "Montar", "time": 3.0,
		"layers": [["WW"], ["BB"]], "key": {"W": "wood", "B": "board"},
	},
	# Sobre la mesa de trabajo ("surface"): formas que en el suelo no salen.
	"sailor_backpack": {
		"result": "backpack", "count": 1, "action": "Coser", "time": 4.0, "surface": "workbench",
		"layers": [["BT", "TT"], ["RR", ".."]], "key": {"B": "rough_backpack", "T": "cloth", "R": "rope"},
		"dismantle": true,
	},
	"stone_pick": {
		"result": "stone_pick", "count": 1, "action": "Atar", "time": 3.0, "surface": "workbench",
		"layers": [["SR", "S."], ["PP", ".."]], "key": {"S": "sticks", "R": "rope", "P": "rock"},
	},
	"torch": {
		"result": "torch", "count": 2, "action": "Untar", "time": 1.5,
		"layers": [["S"], ["Z"]], "key": {"S": "sticks", "Z": "resin"},
	},
	"board": {
		"result": "board", "count": 2, "action": "Cortar", "time": 3.0,
		"layers": [["WA"]], "key": {"W": "wood", "A": "stone_axe"}, "tools": ["A"],
	},
	"plank_slab": {
		"result": "plank_slab", "count": 2, "action": "Cortar", "time": 2.5,
		"layers": [["PA"]], "key": {"P": "planks", "A": "stone_axe"}, "tools": ["A"],
	},
	"campfire": {
		"result": "campfire", "count": 1, "action": "Montar", "time": 2.5,
		"layers": [["RRR", "RSR", "RRR"], ["...", ".F.", "..."]], "key": {"R": "rock", "S": "sticks", "F": "fiber"},
	},
	"bedroll": {
		"result": "bedroll", "count": 1, "action": "Coser", "time": 3.0,
		"layers": [["TTT", "CTC"]], "key": {"T": "cloth", "C": "rope"},
	},
	"spear": {
		"result": "spear", "count": 1, "action": "Atar", "time": 2.5,
		"layers": [["BRP"]], "key": {"B": "board", "R": "rope", "P": "sharp_rock"}, "dismantle": true,
	},
	"raft": {
		"result": "raft", "count": 1, "action": "Atar", "time": 4.0,
		"layers": [["BB", "BB"], ["CC", ".."]], "key": {"B": "board", "C": "rope"},
	},
}

## Lo que el personaje sabe hacer desde el principio (nada: lo básico viene en el diario).
const KNOWN_AT_START := []
## Lo que se puede leer en el diario del capitán (está empapado: solo se salva lo básico).
const JOURNAL_RECIPES := ["rope", "sharp_rock", "stone_knife", "stone_axe", "board", "workbench", "torch", "campfire", "bedroll", "spear", "raft", "plank_slab", "chest", "bow", "arrow", "wooden_shield"]


## Celdas de la forma: {Vector3i(columna, capa, fila): id del objeto}.
static func cells_of(recipe_id: String) -> Dictionary:
	var recipe: Dictionary = RECIPES[recipe_id]
	var cells := {}
	var layers: Array = recipe["layers"]
	for level in layers.size():
		var rows: Array = layers[level]
		for row in rows.size():
			var line: String = rows[row]
			for col in line.length():
				var letter := line[col]
				if letter != ".":
					cells[Vector3i(col, level, row)] = recipe["key"][letter]
	return cells


## Ids de los objetos que son herramientas (no se gastan).
static func tools_of(recipe_id: String) -> Array:
	var recipe: Dictionary = RECIPES[recipe_id]
	var out := []
	for letter in recipe.get("tools", []):
		out.append(recipe["key"][letter])
	return out


## Materiales que se gastan: {id: cantidad}.
static func materials_of(recipe_id: String) -> Dictionary:
	var tools := tools_of(recipe_id)
	var out := {}
	for id in cells_of(recipe_id).values():
		if not tools.has(id):
			out[id] = int(out.get(id, 0)) + 1
	return out


## ¿Este grupo de celdas ({Vector3i: id}, capa 0 = en el suelo) tiene exactamente la forma de
## la receta, en alguna de sus 8 orientaciones (4 giros, con y sin reflejo)?
static func matches(group: Dictionary, recipe_id: String) -> bool:
	var target := _normalize(group)
	for variant in _variants(cells_of(recipe_id)):
		if _same(variant, target):
			return true
	return false


## La receta que forma este grupo, entre las conocidas ("" si ninguna).
## Las de mesa de trabajo solo valen si el grupo está encima de mesas (on_workbench).
static func find(group: Dictionary, known: Array, on_workbench := false) -> String:
	for recipe_id in known:
		if RECIPES.has(recipe_id) and allowed_on(recipe_id, on_workbench) and matches(group, recipe_id):
			return recipe_id
	return ""


static func allowed_on(recipe_id: String, on_workbench: bool) -> bool:
	return on_workbench or RECIPES[recipe_id].get("surface", "") != "workbench"


## Si el grupo es un trozo de la receta (todo lo puesto encaja), las celdas que faltan
## ({Vector3i: id}, en las coordenadas del grupo); si no encaja, {}.
static func missing(group: Dictionary, recipe_id: String) -> Dictionary:
	var best := {}
	var anchor: Vector3i = group.keys()[0]
	for variant in _variants(cells_of(recipe_id)):
		if variant.size() <= group.size():
			continue
		for v: Vector3i in variant:
			if variant[v] != group[anchor]:
				continue
			var offset := anchor - v
			if offset.y != 0:
				continue  # la capa de abajo de la receta va en el suelo
			var fits := true
			for g: Vector3i in group:
				if variant.get(g - offset, "") != group[g]:
					fits = false
					break
			if not fits:
				continue
			var lack := {}
			for v2: Vector3i in variant:
				if not group.has(v2 + offset):
					lack[v2 + offset] = variant[v2]
			if best.is_empty() or lack.size() < best.size():
				best = lack
	return best


## Las 8 orientaciones (4 giros y sus reflejos alrededor del eje vertical), normalizadas.
static func _variants(cells: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mirror in [false, true]:
		for turns in 4:
			var variant := {}
			for c: Vector3i in cells:
				var p := Vector2i(-c.x, c.z) if mirror else Vector2i(c.x, c.z)
				for t in turns:
					p = Vector2i(-p.y, p.x)
				variant[Vector3i(p.x, c.y, p.y)] = cells[c]
			out.append(_normalize(variant))
	return out


static func _normalize(cells: Dictionary) -> Dictionary:
	var low := Vector3i(1 << 30, 1 << 30, 1 << 30)
	for c: Vector3i in cells:
		low = Vector3i(mini(low.x, c.x), mini(low.y, c.y), mini(low.z, c.z))
	var out := {}
	for c: Vector3i in cells:
		out[c - low] = cells[c]
	return out


static func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k) or b[k] != a[k]:
			return false
	return true
