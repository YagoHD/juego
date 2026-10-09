extends RefCounted
class_name VillageLayout
## Plano del pueblo principal: quién vive en él, sus lugares (plaza, fragua, capilla...), las casas
## y la ronda de los guardias, en metros respecto al centro del pueblo. Lo usan la aldea de pruebas
## (scripts/village/village_test.gd, con casetas provisionales) y la isla (Structures levanta los
## edificios de bloques en el llano de B4; IslandVillage pone a los vecinos).

## Centro del pueblo en la isla (metros): el llano del valle en B4 (docs/mapa_isla/MIGRACION_BETA.md).
const ISLAND_CENTER := Vector2(-127.0, -16.0)
const RADIUS := 46.0

## Los vecinos: nombre y oficio. Los guardias viven en el cuartel; los refugiados, en su campamento.
const POPULATION := [
	["Aldo", "farmer"], ["Berta", "farmer"], ["Ciro", "farmer"], ["Dalia", "farmer"], ["Elio", "farmer"],
	["Fela", "fisher"], ["Gil", "fisher"], ["Hilda", "fisher"],
	["Iván", "merchant"], ["Juana", "merchant"],
	["Lope", "blacksmith"], ["Marta", "baker"], ["Nuño", "innkeeper"], ["Olga", "banker"],
	["Pelayo", "woodcutter"], ["Quiteria", "woodcutter"], ["Ramiro", "hunter"], ["Sancha", "herbalist"],
	["Fray Tello", "priest"], ["Abuela Urraca", "elder"], ["Viejo Bermudo", "old_miner"], ["Vela", "carpenter"],
	["Ximena", "refugee"], ["Yáñez", "refugee"], ["Zoila", "refugee"],
	["Rodrigo", "guard_day"], ["Gonzalo", "guard_day"], ["Munio", "guard_day"],
	["Fruela", "guard_night"], ["Ordoño", "guard_night"], ["Sisebuto", "guard_night"],
]

const PLACE_NAMES := {"plaza": "Plaza", "field": "Campo", "dock": "Muelle", "market": "Mercado", "barracks": "Cuartel",
	"forge": "Fragua", "bakery": "Horno", "tavern": "Taberna", "bank": "Banco", "woods": "Bosque", "forest_edge": "Linde del bosque",
	"herb_garden": "Huerto de hierbas", "chapel": "Capilla", "workshop": "Carpintería", "refugee_camp": "Campamento de refugiados"}

## Lugar -> [punto (x, z) en metros respecto al centro, radio por el que pasean].
const PLACES := {"plaza": [Vector2(0, 0), 5.0], "field": [Vector2(-24, -16), 7.0],
	"dock": [Vector2(26, -18), 4.0], "market": [Vector2(12, 12), 4.0], "barracks": [Vector2(-14, 20), 3.0],
	"forge": [Vector2(8, -8), 2.0], "bakery": [Vector2(-8, -8), 2.0], "tavern": [Vector2(-10, 6), 3.5],
	"bank": [Vector2(6, 22), 2.0], "woods": [Vector2(-44, 10), 6.0], "forest_edge": [Vector2(-40, 34), 6.0],
	"herb_garden": [Vector2(20, 30), 3.0], "chapel": [Vector2(0, -24), 3.0], "workshop": [Vector2(18, 0), 2.5],
	"refugee_camp": [Vector2(36, 12), 5.0]}

## Edificios con tejado (además de las casas): lugar -> tamaño (ancho, fondo) en metros.
const BUILDINGS := {"forge": Vector2(5, 5), "bakery": Vector2(5, 5), "tavern": Vector2(6, 6), "bank": Vector2(5, 5),
	"workshop": Vector2(5, 5), "barracks": Vector2(6, 6), "chapel": Vector2(6, 8)}

const HOUSES := 13
const HOUSE_RING := 30.0
const HOUSE_SIZE := Vector2(4, 4)


## Las casas, en corro alrededor de la plaza (dos vecinos en cada una), en metros.
static func homes() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in HOUSES:
		var angle := 0.2 + i * TAU / float(HOUSES)
		out.append(Vector2(cos(angle), sin(angle)) * HOUSE_RING)
	return out


## La ronda de los guardias (metros).
static func patrol() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in 6:
		var angle := i * TAU / 6.0
		out.append(Vector2(cos(angle), sin(angle)) * 22.0)
	return out


## Dónde vive cada vecino (índice de POPULATION), en metros respecto al centro.
static func home_of(index: int) -> Vector2:
	var job: String = POPULATION[index][1]
	if job.begins_with("guard"):
		return PLACES["barracks"][0]
	if job == "refugee":
		return PLACES["refugee_camp"][0]
	var civil := 0
	for i in index:
		var other: String = POPULATION[i][1]
		if not other.begins_with("guard") and other != "refugee":
			civil += 1
	var list := homes()
	return list[(civil / 2) % list.size()]
