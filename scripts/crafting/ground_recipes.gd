class_name GroundRecipes
## Recetas que se fabrican colocando objetos en el suelo. Cada receta es una FORMA: filas de
## letras, donde cada letra es un objeto y "." un hueco que debe quedar vacío. Por debajo hay
## una cuadrícula invisible de celdas de CELL metros: un objeto cuenta en la celda donde cae,
## esté en el punto que esté de ella. La forma vale girada o reflejada.
## Las recetas no se ven en ninguna lista: el personaje las aprende (notas, ...) y quedan
## dibujadas en su cuaderno.

const CELL := 0.25  # metros (medio bloque)

const RECIPES := {
	"rope": {
		"result": "rope", "count": 1, "action": "Retorcer", "time": 1.5,
		"shape": ["HHH"], "key": {"H": "leaves"},
	},
	"belt": {
		"result": "belt", "count": 1, "action": "Atar", "time": 2.0,
		"shape": ["CCC"], "key": {"C": "rope"},
	},
	"rough_backpack": {
		"result": "rough_backpack", "count": 1, "action": "Coser", "time": 3.0,
		"shape": ["C.C", "TTT", "TTT"], "key": {"C": "rope", "T": "cloth"},
	},
}

## Lo que el personaje sabe hacer desde el principio.
const KNOWN_AT_START := ["rope"]


## Celdas de la forma: {Vector2i(columna, fila): id del objeto}.
static func cells_of(recipe_id: String) -> Dictionary:
	var recipe: Dictionary = RECIPES[recipe_id]
	var cells := {}
	var rows: Array = recipe["shape"]
	for row in rows.size():
		var line: String = rows[row]
		for col in line.length():
			var letter := line[col]
			if letter != ".":
				cells[Vector2i(col, row)] = recipe["key"][letter]
	return cells


## ¿Este grupo de celdas ({Vector2i: id}) tiene exactamente la forma de la receta, en alguna
## de sus 8 orientaciones (4 giros, con y sin reflejo)?
static func matches(group: Dictionary, recipe_id: String) -> bool:
	var target := _normalize(group)
	var cells := cells_of(recipe_id)
	if cells.size() != target.size():
		return false
	for mirror in [false, true]:
		for turns in 4:
			var variant := {}
			for c: Vector2i in cells:
				var p := Vector2i(-c.x, c.y) if mirror else c
				for t in turns:
					p = Vector2i(-p.y, p.x)
				variant[p] = cells[c]
			if _same(_normalize(variant), target):
				return true
	return false


## La receta que forma este grupo, entre las conocidas ("" si ninguna).
static func find(group: Dictionary, known: Array) -> String:
	for recipe_id in known:
		if RECIPES.has(recipe_id) and matches(group, recipe_id):
			return recipe_id
	return ""


static func _normalize(cells: Dictionary) -> Dictionary:
	var low := Vector2i(1 << 30, 1 << 30)
	for c: Vector2i in cells:
		low = Vector2i(mini(low.x, c.x), mini(low.y, c.y))
	var out := {}
	for c: Vector2i in cells:
		out[c - low] = cells[c]
	return out


static func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k) or b[k] != a[k]:
			return false
	return true
