extends RefCounted
class_name VillageLaw
## Memoria de delitos de un pueblo (ver docs/VECINOS_Y_GUARDIAS.md). Solo cuenta lo que ve algún
## vecino o guardia. Romper o colocar bloques: cinco avisos y al quinto, delito leve (multa).
## Golpear: delito medio (multa; si no se paga, los guardias atacan). Golpear a un guardia:
## resistencia (multa mayor y ataque). Matar: delito máximo, sin perdón pagando.

signal changed(text: String)   # para avisar al jugador

const WARNINGS := 5
const FINE_PETTY := 3.0        # valor de la multa por delito leve
const FINE_ASSAULT := 10.0     # por golpear a un vecino
const FINE_RESIST := 15.0      # por golpear a un guardia
## Valor provisional de los objetos para pagar multas (y, más adelante, el comercio).
const VALUES := {
	"stone_knife": 6.0, "stone_axe": 8.0, "stone_pick": 8.0, "spear": 6.0, "bow": 8.0,
	"wooden_shield": 7.0, "iron_scrap": 4.0, "anchor_shard": 0.0, "enemy_orders": 0.0,
	"cooked_meat": 2.0, "cooked_fish": 2.0, "cooked_poultry": 2.0, "flatbread": 2.0,
	"hide": 2.0, "rope": 1.5, "cloth": 1.5, "planks": 1.0, "board": 1.0, "arrow": 0.5,
	"captain_journal": 0.0,
	"gold_coin": 1.0, "gold_nugget": 1.5,  # el banco paga la pepita a 1,5; fundida da 2 monedas
}

var warnings := 0       # avisos por tocar bloques (0..5)
var fine := 0.0         # lo que se debe
var hostile := false    # los guardias atacan (resistencia o multa sin pagar)
var murderer := false   # mató a alguien a la vista: no se perdona


static func value_of(id: String) -> float:
	return float(VALUES.get(id, 1.0))


## Los guardias deben atacar al jugador.
func guards_attack() -> bool:
	return murderer or hostile


## Un guardia debe acercarse a cobrar.
func wants_payment() -> bool:
	return fine > 0.0 and not guards_attack()


func block_edit() -> void:
	warnings += 1
	if warnings < WARNINGS:
		changed.emit("Un vecino te ha visto tocar las casas del pueblo (aviso %d de %d)." % [warnings, WARNINGS])
		return
	warnings = 0
	fine += FINE_PETTY
	changed.emit("Delito leve: dañar el pueblo. Un guardia viene a cobrarte la multa.")


func assault(victim_is_guard: bool) -> void:
	if victim_is_guard:
		fine += FINE_RESIST
		hostile = true
		changed.emit("¡Has atacado a un guardia! Los guardias van a por ti.")
	elif fine > 0.0 and not hostile:
		hostile = true  # volver a pegar con una multa pendiente
		fine += FINE_ASSAULT
		changed.emit("Has vuelto a atacar a un vecino: los guardias van a por ti.")
	else:
		fine += FINE_ASSAULT
		changed.emit("Delito: has golpeado a un vecino. Un guardia viene a cobrarte la multa.")


func murder() -> void:
	if not murderer:
		murderer = true
		changed.emit("Has matado a alguien a la vista de todos: los guardias te matarán si te ven en el pueblo.")


## Irse sin pagar cuando un guardia está cobrando.
func refuse() -> void:
	if wants_payment():
		hostile = true
		changed.emit("Te has ido sin pagar la multa: los guardias van a por ti.")


## Al morir el jugador perseguido por una multa: dejan de atacar (la multa sigue).
func player_died() -> void:
	hostile = false


## Paga la multa con lo ofrecido en la pantalla de pago (su valor en monedas). Devuelve el cambio,
## o -1 si no llega. Un asesinato no se perdona pagando.
func pay_offer(value: float) -> float:
	if fine <= 0.0 or murderer:
		return -1.0
	if value < fine:
		changed.emit("No llega para pagar la multa (vale %d; ofreces %.1f)." % [ceili(fine), value])
		return -1.0
	var change := value - fine
	fine = 0.0
	hostile = false
	changed.emit("Has pagado la multa. Los guardias te dejan en paz.")
	return change


func to_data() -> Dictionary:
	return {"warnings": warnings, "fine": fine, "hostile": hostile, "murderer": murderer}


func from_data(data: Dictionary) -> void:
	warnings = clampi(int(data.get("warnings", 0)), 0, WARNINGS - 1)
	fine = maxf(0.0, float(data.get("fine", 0.0)))
	hostile = bool(data.get("hostile", false))
	murderer = bool(data.get("murderer", false))
