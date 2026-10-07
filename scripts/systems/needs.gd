extends Node
class_name Needs
## Hambre y sed (suaves, isla del tutorial): bajan despacio con el tiempo; comer (clic derecho
## con comida) y beber (clic derecho con la mano vacía mirando agua dulce) las suben. Con
## hambre o sed no se puede correr; del todo vacías, se anda más despacio. No se muere.

signal warned(text: String)

const HUNGER_MINUTES := 40.0   # de lleno a vacío, en minutos reales
const THIRST_MINUTES := 25.0
## Lo que alimenta cada comida (sobre 100). Lo asado, más.
const FOOD := {
	"raw_meat": 7.0, "cooked_meat": 34.0, "raw_poultry": 6.0, "cooked_poultry": 28.0,
	"berries": 10.0, "roasted_berries": 20.0, "insect": 5.0, "roasted_insect": 16.0,
	"mushroom": 7.0, "roasted_mushroom": 18.0, "seeds": 2.0, "roasted_seeds": 8.0,
	"wheat": 3.0, "raw_fish": 6.0, "cooked_fish": 32.0, "flatbread": 24.0, "raw_crab": 4.0, "cooked_crab": 22.0,
}
const DRINK := 30.0

var player: Player
var hunger := 100.0   # 100 = lleno
var thirst := 100.0
var _warned_hunger := false
var _warned_thirst := false


func _process(delta: float) -> void:
	if player == null or player.creative or get_tree().paused:
		return
	hunger = maxf(hunger - delta * 100.0 / (HUNGER_MINUTES * 60.0), 0.0)
	thirst = maxf(thirst - delta * 100.0 / (THIRST_MINUTES * 60.0), 0.0)
	if hunger < 20.0 and not _warned_hunger:
		_warned_hunger = true
		warned.emit("Tienes hambre: come algo (bayas, setas, insectos... mejor asados).")
	elif hunger > 30.0:
		_warned_hunger = false
	if thirst < 20.0 and not _warned_thirst:
		_warned_thirst = true
		warned.emit("Tienes sed: bebe agua dulce de un río o un lago (clic derecho, mano vacía).")
	elif thirst > 30.0:
		_warned_thirst = false


static func is_food(id: String) -> bool:
	return FOOD.has(id)


## Come uno de 'id'. Devuelve false si no es comida o ya está lleno.
func eat(id: String) -> bool:
	if not FOOD.has(id):
		return false
	if hunger >= 99.0:
		warned.emit("No tienes hambre.")
		return false
	hunger = minf(hunger + float(FOOD[id]), 100.0)
	return true


func drink() -> bool:
	if thirst >= 99.0:
		warned.emit("No tienes sed.")
		return false
	thirst = minf(thirst + DRINK, 100.0)
	return true


## Cuánto se puede correr y andar: sin correr con hambre o sed; más lento del todo vacías.
func can_sprint() -> bool:
	return hunger > 15.0 and thirst > 15.0


func speed_factor() -> float:
	return 0.7 if hunger <= 0.0 or thirst <= 0.0 else 1.0


func to_data() -> Dictionary:
	return {"hunger": hunger, "thirst": thirst}


func from_data(data: Dictionary) -> void:
	hunger = clampf(float(data.get("hunger", 100.0)), 0.0, 100.0)
	thirst = clampf(float(data.get("thirst", 100.0)), 0.0, 100.0)
