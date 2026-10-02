extends RefCounted
class_name Inventory
## Inventario: una lista de huecos; cada hueco está vacío ({}) o tiene un montón
## {"id": String, "count": int}. Lo usan el jugador (36 huecos: 0-8 la barra) y los cofres.

signal changed

var _slots: Array[Dictionary] = []


func _init(size: int) -> void:
	_slots.resize(size)
	for i in size:
		_slots[i] = {}


func size() -> int:
	return _slots.size()


func get_slot(index: int) -> Dictionary:
	return _slots[index]


func set_slot(index: int, stack: Dictionary) -> void:
	_slots[index] = stack.duplicate() if not stack.is_empty() and int(stack["count"]) > 0 else {}
	changed.emit()


func is_empty_slot(index: int) -> bool:
	return _slots[index].is_empty()


## Añade objetos: primero completa montones del mismo tipo y luego usa huecos vacíos (en orden,
## así la barra se llena primero). Solo usa los huecos de "allowed" (vacío = todos).
## Devuelve cuántos NO cupieron.
func add(id: String, count: int, allowed: Array = []) -> int:
	var slots: Array = allowed if not allowed.is_empty() else range(_slots.size())
	var left := count
	var limit := ItemDB.max_stack(id)
	for i in slots:
		if left == 0:
			break
		var s := _slots[i]
		if not s.is_empty() and s["id"] == id and int(s["count"]) < limit:
			var put := mini(left, limit - int(s["count"]))
			s["count"] = int(s["count"]) + put
			left -= put
	for i in slots:
		if left == 0:
			break
		if _slots[i].is_empty():
			var put := mini(left, limit)
			_slots[i] = {"id": id, "count": put}
			left -= put
	if left != count:
		changed.emit()
	return left


## Quita hasta 'count' objetos del hueco. Devuelve cuántos se quitaron.
func take(index: int, count: int) -> int:
	var s := _slots[index]
	if s.is_empty():
		return 0
	var taken := mini(count, int(s["count"]))
	s["count"] = int(s["count"]) - taken
	if int(s["count"]) <= 0:
		_slots[index] = {}
	changed.emit()
	return taken


func count_of(id: String) -> int:
	var total := 0
	for s in _slots:
		if not s.is_empty() and s["id"] == id:
			total += int(s["count"])
	return total


func clear() -> void:
	for i in _slots.size():
		_slots[i] = {}
	changed.emit()


## Para guardar: lista de huecos ({} o {"id", "count"}).
func to_data() -> Array:
	var out := []
	for s in _slots:
		out.append(s.duplicate())
	return out


func from_data(data: Array) -> void:
	for i in mini(data.size(), _slots.size()):
		var s: Dictionary = data[i] if data[i] is Dictionary else {}
		if not s.is_empty() and ItemDB.exists(str(s.get("id", ""))) and int(s.get("count", 0)) > 0:
			_slots[i] = {"id": str(s["id"]), "count": int(s["count"])}
		else:
			_slots[i] = {}
	changed.emit()
