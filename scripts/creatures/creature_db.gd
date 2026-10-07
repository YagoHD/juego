extends RefCounted
class_name CreatureDB
## Valores provisionales y botín separados de IA y gráficos. Distancias en metros, tiempos
## en segundos. Los perfiles devueltos son copias: cambiar uno no modifica el catálogo.

const ENEMIES := ["tracker", "soldier", "captain", "mage", "tower_guardian", "archer"]
const ANIMALS := ["pig", "cow", "boar", "snake", "wolf", "cat", "deer", "rabbit", "hen", "gull", "crow", "eagle"]
const DATA := {
	"archer": {"name": "Arquero", "hp": 50.0, "speed": 2.0, "damage": 11.0, "windup": 1.0, "cooldown": 2.1, "range": 16.0, "sense": 17.0, "attack": "arrow", "color": Color(0.25, 0.6, 0.4), "loot": [["cloth", 1, 2, 1.0], ["rope", 1, 2, 0.8]]},
	"tracker": {"name": "Rastreador", "hp": 45.0, "speed": 2.2, "damage": 9.0, "windup": 0.55, "cooldown": 1.4, "sense": 10.0, "color": Color(0.65, 0.44, 0.25), "loot": [["cloth", 1, 2, 1.0], ["rope", 1, 1, 0.6]]},
	"soldier": {"name": "Soldado", "hp": 85.0, "speed": 1.8, "damage": 15.0, "armor": 0.2, "windup": 0.8, "cooldown": 1.7, "sense": 11.0, "color": Color(0.38, 0.48, 0.6), "loot": [["iron_scrap", 1, 3, 1.0], ["cloth", 1, 2, 0.7]]},
	"captain": {"name": "Capitán", "hp": 140.0, "speed": 2.1, "damage": 18.0, "armor": 0.15, "windup": 0.65, "cooldown": 2.2, "combo": 2, "sense": 12.0, "color": Color(0.65, 0.18, 0.19), "loot": [["iron_scrap", 2, 4, 1.0], ["enemy_orders", 1, 1, 1.0]]},
	"mage": {"name": "Mago", "hp": 60.0, "speed": 1.7, "damage": 14.0, "windup": 1.15, "cooldown": 2.5, "range": 13.0, "sense": 15.0, "attack": "bolt", "color": Color(0.53, 0.24, 0.75), "loot": [["arcane_dust", 1, 3, 1.0], ["cloth", 1, 2, 0.8]]},
	"tower_guardian": {"name": "Guardián de la torre", "hp": 400.0, "speed": 1.1, "damage": 28.0, "armor": 0.3, "height": 2.8, "radius": 0.75, "windup": 1.4, "cooldown": 2.8, "range": 4.5, "sense": 13.0, "leash": 18.0, "attack": "slam", "color": Color(0.32, 0.2, 0.42), "loot": [["anchor_shard", 1, 1, 1.0], ["stone", 4, 8, 1.0]]},
	"pig": {"name": "Cerdo", "hp": 35.0, "speed": 1.0, "temper": "timid", "color": Color(0.9, 0.57, 0.59), "loot": [["raw_meat", 2, 3, 1.0], ["hide", 1, 1, 0.7]]},
	"cow": {"name": "Vaca", "hp": 70.0, "speed": 0.8, "temper": "defensive", "damage": 10.0, "height": 1.3, "radius": 0.55, "color": Color(0.8, 0.76, 0.67), "loot": [["raw_meat", 3, 5, 1.0], ["hide", 2, 3, 1.0], ["bone", 1, 2, 0.8]]},
	"boar": {"name": "Jabalí", "hp": 65.0, "speed": 1.3, "temper": "territorial", "damage": 14.0, "range": 1.5, "attack": "charge", "sense": 5.0, "color": Color(0.38, 0.26, 0.17), "loot": [["raw_meat", 2, 4, 1.0], ["hide", 1, 2, 1.0], ["tusk", 1, 2, 0.7]]},
	"snake": {"name": "Serpiente", "hp": 15.0, "speed": 0.65, "height": 0.25, "radius": 0.12, "temper": "territorial", "damage": 4.0, "poison": 6.0, "sense": 2.5, "range": 0.9, "color": Color(0.3, 0.48, 0.22), "loot": [["venom_gland", 1, 1, 0.8], ["raw_meat", 1, 1, 0.5]]},
	"wolf": {"name": "Lobo", "hp": 55.0, "speed": 2.0, "temper": "predator", "damage": 12.0, "sense": 10.0, "nocturnal": true, "color": Color(0.48, 0.5, 0.54), "loot": [["raw_meat", 1, 3, 1.0], ["hide", 1, 2, 1.0], ["bone", 1, 2, 0.7]]},
	"cat": {"name": "Gato", "hp": 20.0, "speed": 1.2, "temper": "shy", "height": 0.45, "radius": 0.18, "nocturnal": true, "color": Color(0.84, 0.54, 0.27), "loot": [["hide", 1, 1, 0.5], ["bone", 1, 1, 0.5]]},
	"deer": {"name": "Ciervo", "hp": 45.0, "speed": 2.0, "temper": "timid", "height": 1.4, "color": Color(0.62, 0.4, 0.22), "loot": [["raw_meat", 2, 4, 1.0], ["hide", 1, 2, 1.0], ["bone", 1, 2, 0.8]]},
	"rabbit": {"name": "Conejo", "hp": 12.0, "speed": 1.6, "temper": "timid", "height": 0.35, "radius": 0.15, "color": Color(0.71, 0.65, 0.57), "loot": [["raw_meat", 1, 1, 1.0], ["hide", 1, 1, 0.5]]},
	"hen": {"name": "Gallina", "hp": 16.0, "speed": 0.85, "temper": "timid", "height": 0.45, "radius": 0.18, "color": Color(0.85, 0.73, 0.51), "loot": [["raw_poultry", 1, 2, 1.0], ["feather", 1, 3, 1.0]]},
	"gull": {"name": "Gaviota", "hp": 12.0, "speed": 2.2, "temper": "timid", "flying": true, "height": 0.35, "radius": 0.16, "color": Color(0.9, 0.92, 0.93), "loot": [["raw_poultry", 1, 1, 1.0], ["feather", 1, 3, 1.0]]},
	"crow": {"name": "Cuervo", "hp": 15.0, "speed": 2.0, "temper": "shy", "flying": true, "height": 0.4, "radius": 0.17, "color": Color(0.13, 0.15, 0.2), "loot": [["raw_poultry", 1, 1, 1.0], ["feather", 1, 3, 1.0]]},
	# Gente del pueblo (no son enemigos ni animales: los maneja scripts/village/villager.gd).
	"villager": {"name": "Vecino", "hp": 40.0, "speed": 1.15, "temper": "timid", "height": 1.5, "sense": 14.0, "color": Color(0.78, 0.66, 0.5), "loot": []},
	"guard": {"name": "Guardia", "hp": 90.0, "speed": 2.0, "damage": 12.0, "armor": 0.15, "temper": "defensive", "height": 1.55, "sense": 16.0, "windup": 0.7, "cooldown": 1.5, "leash": 80.0, "color": Color(0.35, 0.42, 0.62), "loot": [["cloth", 1, 1, 0.5]]},
	"eagle": {"name": "Águila", "hp": 30.0, "speed": 2.8, "temper": "hunter", "flying": true, "height": 0.6, "radius": 0.23, "damage": 8.0, "color": Color(0.42, 0.31, 0.2), "loot": [["raw_poultry", 1, 2, 1.0], ["feather", 2, 4, 1.0]]},
}

static func profile(id: String) -> Dictionary:
	if not DATA.has(id):
		return {}
	var result := {"hp": 30.0, "speed": 1.2, "damage": 6.0, "height": 0.85, "radius": 0.3,
		"sense": 6.0, "range": 1.6, "windup": 0.6, "cooldown": 1.6, "leash": 22.0,
		"armor": 0.0, "attack": "melee", "temper": "timid", "flying": false,
		"nocturnal": false, "combo": 1, "poison": 0.0, "enemy": ENEMIES.has(id)}
	result.merge(DATA[id].duplicate(true), true)
	if result["enemy"] and not DATA[id].has("height"):
		result["height"] = 1.5
	return result

## Tirada independiente por entrada; solo se llama una vez al morir.
static func roll_loot(id: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	for entry in DATA.get(id, {}).get("loot", []):
		if rng.randf() < float(entry[3]):
			drops.append({"id": entry[0], "count": rng.randi_range(int(entry[1]), int(entry[2]))})
	return drops
