extends RefCounted
class_name LoreDB
## Lo que el jugador puede descubrir de la historia (ver docs/HISTORIA_NOMBRES.md): cada
## descubrimiento es una entrada del futuro cuaderno, y unas cuantas juntas dan una DEDUCCIÓN (el
## personaje ata cabos). Las fuentes son los diálogos ("set" en DialogueDB), las pistas del mundo
## (Clue) y lo que se lee (diario, notas). Nombres e historia, provisionales.
##
## Cada descubrimiento: {"topic": tema del cuaderno, "text": cómo queda apuntado}.

const TOPICS := {
	"naufragio": "El naufragio", "ataque": "El pueblo pesquero", "mina": "La mina de la montaña",
	"ruinas": "Las ruinas", "torre": "La torre", "invasores": "Los invasores",
}

const FACTS := {
	# Diálogos (DialogueDB): lo que cuentan los vecinos.
	"mina_brillo_morado": {"topic": "mina", "text": "Bermudo dice que al fondo de la mina la roca brillaba morada y zumbaba."},
	"mina_suenos_torre": {"topic": "mina", "text": "Los mineros que picaban junto al brillo soñaban con una torre."},
	"mina_derrumbe": {"topic": "mina", "text": "La mina se cerró tras un derrumbe en la galería del brillo."},
	"mina_galeria": {"topic": "mina", "text": "Aún se podría entrar a la galería por un pozo viejo."},
	"mina_soldados_suben": {"topic": "invasores", "text": "El cazador ha visto huellas de botas de soldado subiendo a la mina."},
	"nombre_umbrita": {"topic": "mina", "text": "Los viejos mineros llamaban 'umbrita' a esa piedra morada."},
	"ruinas_antiguos": {"topic": "ruinas", "text": "Las ruinas eran de 'los antiguos', que vigilaban algo."},
	"ruinas_lago_corazon": {"topic": "ruinas", "text": "Según la abuela Urraca, los antiguos vigilaban el lago: 'el corazón de la isla'."},
	"ruinas_armas": {"topic": "ruinas", "text": "En las ruinas quedarían armas y armaduras de los antiguos."},
	"ataque_mascaras": {"topic": "ataque", "text": "Los que atacaron el pueblo pesquero llevaban máscaras lisas."},
	"ataque_joyas": {"topic": "ataque", "text": "Buscaban las joyas de la familia de la casa grande."},
	"ataque_familia_muerta": {"topic": "ataque", "text": "La familia de la casa grande murió en el ataque."},
	"ataque_brillo_morado": {"topic": "ataque", "text": "Ximena vio cómo se llevaban un cofre que brillaba morado."},
	"ataque_barco_extranjero": {"topic": "ataque", "text": "Días antes, un barco extranjero preguntó por 'las piedras' de la familia."},
	"naufragio_mar_morado": {"topic": "naufragio", "text": "La noche de la tormenta, el mar brilló morado."},
	"rumor_torre": {"topic": "torre", "text": "En el pueblo se habla de una roca que crece en el norte."},
	# Pistas del mundo (Clue).
	"quilla_violeta": {"topic": "naufragio", "text": "La quilla del barco tiene una grieta que brilla violeta."},
	"diario_brujulas": {"topic": "naufragio", "text": "El capitán escribió que las brújulas giraban hacia un punto fijo."},
	"emblema_ojo_pesquero": {"topic": "ataque", "text": "En una puerta quemada del pueblo pesquero hay un ojo cerrado pintado."},
	"joyero_vacio": {"topic": "ataque", "text": "En la casa grande, un joyero vacío con polvo morado en el fondo."},
	"escudo_valdes": {"topic": "ataque", "text": "La casa grande era de los Valdés, armadores."},
	"emblema_ojo_campamento": {"topic": "invasores", "text": "Las tiendas del campamento enemigo llevan un ojo cerrado."},
	"mascara_lisa": {"topic": "invasores", "text": "Bajo la máscara de un enemigo había una cara normal."},
	"torre_brillo": {"topic": "torre", "text": "La base de la torre brilla con el mismo morado."},
	"runas_brillan": {"topic": "ruinas", "text": "Las runas de la armadura antigua brillan cerca de la piedra morada."},
}

## Deducciones: el personaje las saca solo al juntar pistas. "any": vale cualquiera de las listas
## (cada una, todas sus pistas). Pueden usar otras deducciones.
const DEDUCTIONS := {
	"ded_invasores_pesquero": {"topic": "invasores", "any": [
			["emblema_ojo_pesquero", "emblema_ojo_campamento"], ["ataque_mascaras", "mascara_lisa"]],
		"text": "Los del campamento son los mismos que arrasaron el pueblo pesquero."},
	"ded_joyas_umbrita": {"topic": "ataque", "any": [
			["ataque_brillo_morado", "mina_brillo_morado"], ["joyero_vacio", "mina_brillo_morado"]],
		"text": "Las joyas de la familia eran de la misma piedra morada que brillaba en la mina."},
	"ded_valdes_mina": {"topic": "ataque", "any": [["escudo_valdes", "ded_joyas_umbrita"]],
		"text": "Si los Valdés tenían esa piedra, alguien de la familia tuvo que sacarla de la mina."},
	"ded_torre_umbrita": {"topic": "torre", "any": [
			["ded_joyas_umbrita", "torre_brillo"], ["mina_suenos_torre", "mina_soldados_suben"]],
		"text": "La torre necesita esa piedra morada: por eso mataron por las joyas y ahora suben a la mina."},
	"ded_naufragio": {"topic": "naufragio", "any": [
			["naufragio_mar_morado", "quilla_violeta"], ["naufragio_mar_morado", "diario_brujulas"]],
		"text": "Mi naufragio no fue casualidad: el mar brilló morado la noche en que despertaron la torre."},
	"ded_antiguos_guardianes": {"topic": "ruinas", "any": [
			["ruinas_lago_corazon", "ruinas_armas"], ["ruinas_antiguos", "runas_brillan"]],
		"text": "Los antiguos protegían el lago de algo así. Su equipo podría servir contra la torre."},
}


static func has(id: String) -> bool:
	return FACTS.has(id) or DEDUCTIONS.has(id)


static func entry(id: String) -> Dictionary:
	return FACTS.get(id, DEDUCTIONS.get(id, {}))
