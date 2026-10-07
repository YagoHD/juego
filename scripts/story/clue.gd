extends Node3D
class_name Clue
## Pista del mundo: algo que se puede examinar (clic derecho mirándolo de cerca) y que enseña un
## descubrimiento de LoreDB (un joyero vacío, un ojo pintado en una puerta, la grieta de la
## quilla...). Al examinarla, el personaje dice lo que ve y lo apunta (Discoveries). Lleva su
## propio dibujo como hijo (o ninguno, si la pista es parte del terreno).

const REACH := 3.0          # metros
const AIM_ANGLE := 22.0     # grados entre la mirada y la pista

@export var fact := ""      # id de LoreDB que enseña
@export var look_text := ""  # lo que dice el personaje al verla

signal examined(clue: Clue)


func _ready() -> void:
	add_to_group("clues")


## La pista que mira el jugador desde 'eye' hacia 'forward' (o null): la más centrada a su alcance.
static func looked_at(tree: SceneTree, eye: Vector3, forward: Vector3) -> Clue:
	var best: Clue = null
	var best_angle := deg_to_rad(AIM_ANGLE)
	for node in tree.get_nodes_in_group("clues"):
		var clue := node as Clue
		if clue == null or not clue.is_visible_in_tree():
			continue
		var to := clue.global_position - eye
		if to.length() > REACH:
			continue
		var angle := forward.angle_to(to)
		if angle < best_angle:
			best_angle = angle
			best = clue
	return best


## Examinarla: apunta el descubrimiento. Devuelve lo que dice el personaje.
func examine() -> String:
	examined.emit(self)
	var learned := false
	for d in get_tree().get_nodes_in_group("discoveries"):
		learned = (d as Discoveries).learn(fact, "pista") or learned
	if look_text != "":
		return look_text
	var info := LoreDB.entry(fact)
	return str(info.get("text", "Nada que no sepa ya.")) if learned else "Ya lo he visto."
