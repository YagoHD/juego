extends Node
class_name Discoveries
## Lo que el jugador sabe de la historia en esta partida (LoreDB): se guarda con la partida y no se
## olvida. Al aprender algo se comprueban las deducciones: si ya tiene las pistas de alguna, el
## personaje "ata cabos" y la apunta también (y eso puede abrir otras). Los diálogos pueden exigir
## un descubrimiento para mostrar una respuesta, y los vecinos comentan según lo que sabes.
##
## Uso: get_tree().call_group("discoveries", "learn", "joyero_vacio", "pista")

signal learned(id: String, text: String)        # un descubrimiento nuevo
signal deduced(id: String, text: String)        # una deducción nueva (el personaje ata cabos)

## id -> {"source": de dónde salió, "day": día de la partida}. Es también lo que mira el diálogo
## ("requires"), así que se comparte con DialoguePanel.knowledge.
var known := {}
var day := 1   # lo pone main.gd para apuntar cuándo se supo


func _ready() -> void:
	add_to_group("discoveries")


func knows(id: String) -> bool:
	return known.has(id)


## Aprende 'id'. Devuelve true si era nuevo. Ids que no están en LoreDB también se guardan (marcas
## de otros sistemas), pero no salen en el cuaderno.
func learn(id: String, source := "") -> bool:
	if id == "" or known.has(id):
		return false
	known[id] = {"source": source, "day": day}
	if LoreDB.FACTS.has(id):
		learned.emit(id, str(LoreDB.FACTS[id]["text"]))
	_check_deductions()
	return true


func _check_deductions() -> void:
	var changed := true
	while changed:  # una deducción puede abrir otra
		changed = false
		for id: String in LoreDB.DEDUCTIONS:
			if known.has(id):
				continue
			for group: Array in LoreDB.DEDUCTIONS[id]["any"]:
				if group.all(func(need: String) -> bool: return known.has(need)):
					known[id] = {"source": "deducción", "day": day}
					deduced.emit(id, str(LoreDB.DEDUCTIONS[id]["text"]))
					changed = true
					break


## Entradas del cuaderno de un tema (o de todos con topic = ""), en el orden en que se supieron.
func entries(topic := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in known:
		var info := LoreDB.entry(id)
		if info.is_empty() or (topic != "" and info["topic"] != topic):
			continue
		out.append({"id": id, "text": info["text"], "topic": info["topic"],
			"deduction": LoreDB.DEDUCTIONS.has(id), "day": known[id]["day"]})
	return out


func to_data() -> Dictionary:
	return {"known": known.duplicate(true)}


func from_data(data: Dictionary) -> void:
	known.clear()  # el diálogo comparte este diccionario: se vacía, no se sustituye
	var saved: Variant = data.get("known", {})
	if saved is Dictionary:
		for id: String in saved:
			known[id] = saved[id] if saved[id] is Dictionary else {"source": "", "day": 1}
	_check_deductions()
