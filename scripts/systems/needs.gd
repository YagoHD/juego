extends Node
class_name Needs
## Hambre y sed (suaves, isla del tutorial): bajan despacio con el tiempo; comer (clic derecho
## con comida) y beber (clic derecho con la mano vacía mirando agua dulce) las suben. Con
## hambre o sed no se puede correr; del todo vacías, se anda más despacio. No se muere.
## Cansancio: sube despierto y baja al dormir (más o menos según dónde, ver SleepSpot). Cansado no
## se corre, agotado se anda más lento y al llegar al tope el personaje se desmaya donde esté.
## El grano de alba (cafeína, escaso) lo quita. Al despertar mal: mareo un rato.

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
const FATIGUE_MINUTES := 30.0  # de descansado a agotado despierto, en minutos reales (~1,25 días)
const TIRED := 70.0            # cansado: no se corre
const EXHAUSTED := 90.0        # agotado: más lento
## Lo que despeja cada estimulante (puntos de cansancio que quita).
const CAFFEINE := {"dawn_bean": 45.0}

var player: Player
var hunger := 100.0   # 100 = lleno
var thirst := 100.0
var fatigue := 0.0    # 0 = descansado, 100 = se desmaya
var dizzy := 0.0      # segundos de mareo que quedan (al despertar mal)
var groggy := 0.0     # segundos de modorra que quedan (al despertar sin cama): no se corre
var _warned_hunger := false
var _warned_thirst := false
var _warned_fatigue := 0  # 0 nada, 1 avisado de cansado, 2 avisado de agotado

signal collapsed  # cansancio al tope: el personaje cae dormido donde está


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
	dizzy = maxf(dizzy - delta, 0.0)
	groggy = maxf(groggy - delta, 0.0)
	fatigue = minf(fatigue + delta * 100.0 / (FATIGUE_MINUTES * 60.0), 100.0)
	if fatigue >= 100.0:
		collapsed.emit()
	elif fatigue >= EXHAUSTED and _warned_fatigue < 2:
		_warned_fatigue = 2
		warned.emit("Te caes de sueño: duerme ya o te desmayarás donde estés.")
	elif fatigue >= TIRED and _warned_fatigue < 1:
		_warned_fatigue = 1
		warned.emit("Estás cansado: busca un sitio para dormir (mejor bajo techo).")
	elif fatigue < TIRED - 10.0:
		_warned_fatigue = 0
	if thirst < 20.0 and not _warned_thirst:
		_warned_thirst = true
		warned.emit("Tienes sed: bebe agua dulce de un río o un lago (clic derecho, mano vacía).")
	elif thirst > 30.0:
		_warned_thirst = false


static func is_food(id: String) -> bool:
	return FOOD.has(id) or CAFFEINE.has(id)


## Come uno de 'id'. Devuelve false si no es comida o ya está lleno.
func eat(id: String) -> bool:
	if CAFFEINE.has(id):
		if fatigue < 5.0:
			warned.emit("No estás cansado.")
			return false
		fatigue = maxf(fatigue - float(CAFFEINE[id]), 0.0)
		warned.emit("El grano de alba te despeja.")
		return true
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
	return hunger > 15.0 and thirst > 15.0 and fatigue < TIRED and groggy <= 0.0


func speed_factor() -> float:
	var factor := 0.7 if hunger <= 0.0 or thirst <= 0.0 else 1.0
	if fatigue >= EXHAUSTED or dizzy > 0.0:
		factor *= 0.85
	return factor


## Cuánto se balancea la vista (0..1): mareo al despertar y, un poco, el agotamiento.
func sway() -> float:
	return maxf(clampf(dizzy / 10.0, 0.0, 1.0), clampf((fatigue - EXHAUSTED) / 10.0, 0.0, 1.0) * 0.5)


## Despertar: lo que queda de cansancio y lo que dura el mareo según cómo se ha dormido.
func wake(rest: Dictionary) -> void:
	fatigue = minf(fatigue, float(rest["fatigue"]))
	dizzy = float(rest["dizzy"])
	groggy = float(rest["groggy"])
	_warned_fatigue = 0


func to_data() -> Dictionary:
	return {"hunger": hunger, "thirst": thirst, "fatigue": fatigue, "dizzy": dizzy, "groggy": groggy}


func from_data(data: Dictionary) -> void:
	hunger = clampf(float(data.get("hunger", 100.0)), 0.0, 100.0)
	thirst = clampf(float(data.get("thirst", 100.0)), 0.0, 100.0)
	fatigue = clampf(float(data.get("fatigue", 0.0)), 0.0, 99.0)
	dizzy = clampf(float(data.get("dizzy", 0.0)), 0.0, 60.0)
	groggy = clampf(float(data.get("groggy", 0.0)), 0.0, 120.0)
