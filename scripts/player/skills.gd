extends RefCounted
class_name Skills
## Progresión por uso (sin repartir puntos): cada habilidad sube al hacer lo suyo. Pelear sube el
## cuerpo a cuerpo, minar la minería, pescar la pesca... Cada nivel mejora un poco eso mismo.
## Valores provisionales, pensados para la Beta (nivel máximo 10); se ajustan aquí.

signal leveled_up(skill: String, level: int)

const MAX_LEVEL := 10
## Nombre, y qué mejora cada nivel (para enseñarlo en el inventario).
const INFO := {
	"melee": {"name": "Cuerpo a cuerpo", "perk": "+4% de daño y -2% de esfuerzo por nivel"},
	"archery": {"name": "Tiro con arco", "perk": "+4% de daño y -5% de temblor al apuntar por nivel"},
	"mining": {"name": "Minería", "perk": "+6% de rapidez picando piedra y mineral por nivel"},
	"woodcutting": {"name": "Tala", "perk": "+6% de rapidez cortando madera por nivel"},
	"fishing": {"name": "Pesca", "perk": "+6% de probabilidad de sacar dos peces por nivel"},
	"crafting": {"name": "Artesanía", "perk": "-4% de tiempo fabricando por nivel"},
	"stealth": {"name": "Sigilo", "perk": "-4% de distancia a la que te ven agachado por nivel"},
	"reading": {"name": "Lectura", "perk": "entender mejor los textos (más adelante, el idioma)"},
}

var xp := {}      # habilidad -> experiencia acumulada


## Experiencia total para llegar a un nivel: 15, 60, 135... 1500 (cada uno cuesta más).
static func xp_for(level: int) -> float:
	return 15.0 * level * level


func level(skill: String) -> int:
	var points := float(xp.get(skill, 0.0))
	var result := 0
	while result < MAX_LEVEL and points >= xp_for(result + 1):
		result += 1
	return result


## Cuánto falta para el siguiente nivel (0..1), para la barrita.
func progress(skill: String) -> float:
	var current := level(skill)
	if current >= MAX_LEVEL:
		return 1.0
	var low := xp_for(current)
	return clampf((float(xp.get(skill, 0.0)) - low) / (xp_for(current + 1) - low), 0.0, 1.0)


func gain(skill: String, amount: float) -> void:
	if not INFO.has(skill) or amount <= 0.0:
		return
	var before := level(skill)
	xp[skill] = float(xp.get(skill, 0.0)) + amount
	var after := level(skill)
	if after > before:
		leveled_up.emit(skill, after)


## Multiplicador de una mejora: 1 + por_nivel × nivel (por_nivel negativo para reducir).
func bonus(skill: String, per_level: float) -> float:
	return 1.0 + per_level * level(skill)


## Qué habilidad practica romper este bloque: minería (lo que pica el pico), tala (lo que corta
## el hacha) o ninguna.
static func block_skill(block_id: int) -> String:
	if ItemDB.tool_speed("stone_pick", block_id) > 1.0:
		return "mining"
	if ItemDB.tool_speed("stone_axe", block_id) > 1.0:
		return "woodcutting"
	return ""


func to_data() -> Dictionary:
	return xp.duplicate()


func from_data(data: Dictionary) -> void:
	xp = {}
	for skill in data:
		if INFO.has(skill):
			xp[skill] = maxf(0.0, float(data[skill]))
