extends RefCounted
class_name GearDB
## Catálogo de equipo: armaduras, accesorios y armas. Pensado para cientos de piezas (fabricables,
## de facción, de misión, de mazmorra, de enemigos...): cada una es una ficha y el resto del juego
## solo lee fichas. Valores provisionales; ver docs/EQUIPO.md.
##
## Ficha de armadura o accesorio:
##   name, slot (hueco), rarity (rareza), origin (de dónde sale), level (nivel del objeto: aún sin
##   uso, para un futuro sistema de niveles), armor (protección), weight (kg), durability (golpes
##   que aguanta; 0 = no se rompe nunca), set (conjunto), effects (efectos), desc (descripción).
## Efectos posibles: "stamina_regen" (+% de recuperación de resistencia), "melee" (+% de daño
## cuerpo a cuerpo), "sneak" (-% de distancia a la que te ven agachado), "corruption_resist"
## (resistencia a la corrupción de la torre: se usará cuando la corrupción haga daño).

## Huecos de armadura y accesorios (además de la ropa, la mochila y el escudo).
const SLOTS := ["head", "chest", "legs", "feet", "hands", "cloak", "ring", "necklace", "amulet"]
const SLOT_NAMES := {"head": "Cabeza", "chest": "Torso", "legs": "Piernas", "feet": "Pies", "hands": "Manos",
	"cloak": "Capa", "ring": "Anillo", "necklace": "Colgante", "amulet": "Amuleto"}
const RARITIES := {
	"common": {"name": "Común", "color": Color(0.85, 0.85, 0.82)},
	"good": {"name": "Buena", "color": Color(0.45, 0.85, 0.4)},
	"rare": {"name": "Rara", "color": Color(0.35, 0.6, 1.0)},
	"epic": {"name": "Épica", "color": Color(0.75, 0.4, 0.95)},
	"legendary": {"name": "Legendaria", "color": Color(1.0, 0.65, 0.2)},
}
## Valor en monedas según la rareza (provisional, hasta decidir el comercio).
const RARITY_VALUE := {"common": 4.0, "good": 10.0, "rare": 25.0, "epic": 60.0, "legendary": 200.0}
const ORIGINS := {"craft": "Fabricable", "faction": "De facción", "quest": "De misión", "dungeon": "De mazmorra",
	"enemy": "De enemigos", "ancient": "Hallazgo de los antiguos"}

## Protección: el daño se multiplica por ARMOR_SCALE / (ARMOR_SCALE + protección): cada punto
## protege algo menos que el anterior (51 de protección = la mitad de daño).
const ARMOR_SCALE := 50.0
## Peso: hasta FREE_WEIGHT kg no se nota; a partir de ahí, más lento y más cansado (hasta un tope).
const FREE_WEIGHT := 8.0
const HEAVY_WEIGHT := 40.0

const GEAR := {
	# --- Conjunto de piel (fabricable con piel de animales y cuerda) ---
	"hide_cap": {"name": "Gorro de piel", "slot": "head", "armor": 3.0, "weight": 0.8, "durability": 60, "rarity": "common", "origin": "craft", "level": 1, "set": "hide",
		"desc": "Piel curtida a mano y cosida con cuerda. Abriga más de lo que protege."},
	"hide_vest": {"name": "Chaleco de piel", "slot": "chest", "armor": 8.0, "weight": 3.0, "durability": 80, "rarity": "common", "origin": "craft", "level": 1, "set": "hide",
		"desc": "Dos capas de piel gruesa sobre el pecho. Para un náufrago, casi una coraza."},
	"hide_trousers": {"name": "Perneras de piel", "slot": "legs", "armor": 5.0, "weight": 2.0, "durability": 70, "rarity": "common", "origin": "craft", "level": 1, "set": "hide",
		"desc": "Perneras atadas sobre el pantalón. Las zarzas ya no son un problema."},
	"hide_boots": {"name": "Botas de piel", "slot": "feet", "armor": 3.0, "weight": 1.2, "durability": 60, "rarity": "common", "origin": "craft", "level": 1, "set": "hide",
		"desc": "Botas blandas con suela doble."},
	"hide_gloves": {"name": "Guantes de piel", "slot": "hands", "armor": 2.0, "weight": 0.5, "durability": 50, "rarity": "common", "origin": "craft", "level": 1, "set": "hide",
		"desc": "Para agarrar sin despellejarse las manos."},
	# --- Accesorios sencillos ---
	"sail_cloak": {"name": "Capa de vela", "slot": "cloak", "armor": 1.0, "weight": 1.0, "durability": 40, "rarity": "common", "origin": "craft", "level": 1,
		"effects": {"sneak": 0.05}, "desc": "Un trozo de vela del barco a modo de capa. Te ayuda a pasar desapercibido."},
	"bone_necklace": {"name": "Colgante de hueso", "slot": "necklace", "armor": 0.0, "weight": 0.1, "durability": 0, "rarity": "common", "origin": "craft", "level": 1,
		"effects": {"stamina_regen": 0.05}, "desc": "Un hueso tallado con un cordel. Dicen que da aliento."},
	"tusk_ring": {"name": "Anillo de colmillo", "slot": "ring", "armor": 0.0, "weight": 0.05, "durability": 0, "rarity": "good", "origin": "craft", "level": 2,
		"effects": {"melee": 0.04}, "desc": "Un aro tallado en colmillo de jabalí. Golpeas con más rabia."},
	"shell_amulet": {"name": "Amuleto de concha", "slot": "amulet", "armor": 0.0, "weight": 0.1, "durability": 0, "rarity": "common", "origin": "craft", "level": 1,
		"effects": {"stamina_regen": 0.05}, "desc": "Una concha de la playa del naufragio. Recuerdo de que sigues vivo."},
	# --- Armadura de los antiguos (legendaria, en las ruinas) ---
	"ancient_helm": {"name": "Yelmo de los antiguos", "slot": "head", "armor": 9.0, "weight": 2.0, "durability": 0, "rarity": "legendary", "origin": "ancient", "level": 10, "set": "ancient",
		"desc": "Un metal claro que no conoce el óxido. Tiene grabadas las mismas marcas que las piedras del pueblo."},
	"ancient_cuirass": {"name": "Coraza de los antiguos", "slot": "chest", "armor": 18.0, "weight": 5.0, "durability": 0, "rarity": "legendary", "origin": "ancient", "level": 10, "set": "ancient",
		"desc": "Pesa la mitad de lo que debería. En el pecho, un hueco vacío del tamaño de una joya."},
	"ancient_greaves": {"name": "Grebas de los antiguos", "slot": "legs", "armor": 12.0, "weight": 3.0, "durability": 0, "rarity": "legendary", "origin": "ancient", "level": 10, "set": "ancient",
		"desc": "Las placas encajan solas al moverte, como si supieran cómo andas."},
	"ancient_boots": {"name": "Botas de los antiguos", "slot": "feet", "armor": 6.0, "weight": 2.0, "durability": 0, "rarity": "legendary", "origin": "ancient", "level": 10, "set": "ancient",
		"desc": "No hacen ruido sobre la piedra."},
	"ancient_gauntlets": {"name": "Guanteletes de los antiguos", "slot": "hands", "armor": 6.0, "weight": 1.5, "durability": 0, "rarity": "legendary", "origin": "ancient", "level": 10, "set": "ancient",
		"desc": "Fríos al tacto, aunque los dejes al sol."},
}

## Conjuntos: extra al llevar varias piezas del mismo (por número de piezas).
const SETS := {
	"hide": {"name": "Conjunto de piel", "bonus": {3: {"armor": 4.0}}},
	"ancient": {"name": "Armadura de los antiguos", "bonus": {3: {"corruption_resist": 0.5}, 5: {"corruption_resist": 1.0, "stamina_regen": 0.25}}},
}

## Armas: lo que hasta ahora estaba en el combate, ya como fichas (las futuras irán aquí).
## style: rápida, equilibrada, pesada o de alcance (para animaciones y combos futuros).
const WEAPONS := {
	"": {"name": "Puños", "damage": 5.0, "reach": 1.8, "cooldown": 0.55, "cost": 7.0, "style": "rápida"},
	"stone_knife": {"name": "Cuchillo de piedra", "damage": 12.0, "reach": 2.0, "cooldown": 0.45, "cost": 10.0, "style": "rápida", "rarity": "common", "origin": "craft", "level": 1},
	"stone_axe": {"name": "Hacha de piedra", "damage": 22.0, "reach": 2.3, "cooldown": 0.85, "cost": 18.0, "style": "pesada", "rarity": "common", "origin": "craft", "level": 1},
	"stone_pick": {"name": "Pico de piedra", "damage": 16.0, "reach": 2.3, "cooldown": 0.8, "cost": 16.0, "style": "pesada", "rarity": "common", "origin": "craft", "level": 1},
	"spear": {"name": "Lanza", "damage": 18.0, "reach": 3.1, "cooldown": 0.7, "cost": 13.0, "style": "de alcance", "rarity": "common", "origin": "craft", "level": 1},
}


static func is_gear(id: String) -> bool:
	return GEAR.has(id)


static func get_info(id: String) -> Dictionary:
	return GEAR.get(id, {})


static func value(id: String) -> float:
	var info: Dictionary = GEAR.get(id, WEAPONS.get(id, {}))
	return float(RARITY_VALUE.get(info.get("rarity", "common"), 4.0))


static func durability(id: String) -> int:
	return int(GEAR.get(id, {}).get("durability", 0))


static func rarity_color(id: String) -> Color:
	var rarity: String = GEAR.get(id, WEAPONS.get(id, {})).get("rarity", "common")
	return RARITIES[rarity]["color"]


## Lo que suma todo lo puesto: protección, peso y efectos (con los extras de conjunto). 'wear' es
## lo que le queda a cada pieza; una pieza rota (0) no protege.
static func totals(equipment: Dictionary, wear: Dictionary) -> Dictionary:
	var result := {"armor": 0.0, "weight": 0.0, "effects": {}, "sets": {}}
	var pieces := {}
	for slot in SLOTS:
		var id := str(equipment.get(slot, ""))
		if not GEAR.has(id):
			continue
		var info: Dictionary = GEAR[id]
		var broken := int(info.get("durability", 0)) > 0 and int(wear.get(slot, 1)) <= 0
		result["weight"] += float(info.get("weight", 0.0))
		if broken:
			continue
		result["armor"] += float(info.get("armor", 0.0))
		_add_effects(result["effects"], info.get("effects", {}))
		if info.has("set"):
			pieces[info["set"]] = int(pieces.get(info["set"], 0)) + 1
	for set_id in pieces:
		var count: int = pieces[set_id]
		result["sets"][set_id] = count
		var bonuses: Dictionary = SETS.get(set_id, {}).get("bonus", {})
		for needed in bonuses:
			if count >= int(needed):
				var bonus: Dictionary = bonuses[needed]
				result["armor"] += float(bonus.get("armor", 0.0))
				_add_effects(result["effects"], bonus)
	return result


static func _add_effects(into: Dictionary, effects: Dictionary) -> void:
	for key in effects:
		if key != "armor":
			into[key] = float(into.get(key, 0.0)) + float(effects[key])


## Cuánto daño pasa con esta protección (multiplicador 0..1).
static func damage_factor(armor: float) -> float:
	return ARMOR_SCALE / (ARMOR_SCALE + maxf(0.0, armor))


## Lo que estorba el peso (0 = nada, 0.5 = el tope): más lento y más cansado.
static func burden(weight: float) -> float:
	return clampf((weight - FREE_WEIGHT) / (HEAVY_WEIGHT - FREE_WEIGHT), 0.0, 0.5)
