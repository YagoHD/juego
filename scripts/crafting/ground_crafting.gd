extends Node3D
class_name GroundCrafting
## Fabricar en el suelo: guarda los objetos dejados a mano (PlacedItem), mira qué formas hacen
## entre ellos y, si una es una receta que el personaje conoce, la hace brillar. Manteniendo R
## cerca de ella, el personaje se agacha a trabajar y los objetos se convierten en el resultado.
##
## Los objetos se dejan donde sea, sin anclarse; solo para leer la forma se mira en qué celda
## invisible (GroundRecipes.CELL) cae cada uno. Dos objetos en la misma celda estropean la forma.

const WORK_DISTANCE := 2.2  # metros: hasta dónde se puede trabajar una forma

var player: Player
var _items: Array[PlacedItem] = []
var _matches: Array[Dictionary] = []   # {"recipe": String, "items": Array[PlacedItem], "center": Vector3}
var _dirty := true
var _progress := 0.0
var _working_on: Dictionary = {}
var debug_hold := false  # solo capturas: como si se mantuviera R
var _active := false  # el personaje está trabajando por orden nuestra


## Deja un objeto en el suelo, en el punto 'pos' (encima del bloque 'support').
func place(pos: Vector3, id: String, yaw: float, support: Vector3i) -> PlacedItem:
	var item := PlacedItem.new()
	item.item_id = id
	item.support = support
	add_child(item)
	item.global_position = pos
	item.rotation.y = yaw
	_items.append(item)
	_dirty = true
	return item


## Quita un objeto del suelo y devuelve su id.
func remove(item: PlacedItem) -> String:
	_items.erase(item)
	item.queue_free()
	_dirty = true
	return item.item_id


## Se ha roto un bloque: lo que estaba encima cae como objeto suelto.
func on_block_removed(cell: Vector3i) -> void:
	for item in _items.duplicate():
		if item.support == cell:
			ItemDrop.spawn(get_parent(), item.global_position + Vector3.UP * 0.2, item.item_id, 1)
			remove(item)


## Texto de ayuda para la pantalla ("" si no hay nada que hacer cerca).
func prompt() -> String:
	var m := _nearest_match()
	if m.is_empty():
		return ""
	var recipe: Dictionary = GroundRecipes.RECIPES[m["recipe"]]
	var text := "Mantén R: %s · %s" % [recipe["action"], ItemDB.display_name(recipe["result"])]
	if _progress > 0.0:
		text += "  %d%%" % int(_progress / float(recipe["time"]) * 100.0)
	return text


func _process(delta: float) -> void:
	if _dirty:
		_dirty = false
		_find_matches()
	if player == null:
		return
	var m := _nearest_match()
	var holding := debug_hold or (not player.ui_open and Input.is_key_pressed(KEY_R))
	if m.is_empty() or not holding or (not _working_on.is_empty() and _working_on["center"] != m["center"]):
		_progress = 0.0
		_working_on = {}
		if _active:
			_active = false
			player.set_working(false)
		return
	_working_on = m
	_active = true
	player.set_working(true)
	_progress += delta
	if _progress >= float(GroundRecipes.RECIPES[m["recipe"]]["time"]):
		craft(m)


## Termina una receta: quita los materiales y deja el resultado (salta hacia el jugador).
func craft(m: Dictionary) -> void:
	var recipe: Dictionary = GroundRecipes.RECIPES[m["recipe"]]
	for item: PlacedItem in m["items"]:
		remove(item)
	ItemDrop.spawn(get_parent(), m["center"] + Vector3.UP * 0.3, recipe["result"], int(recipe["count"]))
	_progress = 0.0
	_working_on = {}
	if player != null and _active:
		_active = false
		player.set_working(false)
	_find_matches()


func _nearest_match() -> Dictionary:
	if player == null:
		return {}
	var best := {}
	var best_d := WORK_DISTANCE
	for m in _matches:
		var d := (m["center"] as Vector3).distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = m
	return best


## Agrupa los objetos que se tocan (celdas vecinas, también en diagonal, a la misma altura) y
## mira si cada grupo es una receta conocida.
func _find_matches() -> void:
	_matches.clear()
	var known: Array = player.known_recipes if player != null else GroundRecipes.KNOWN_AT_START
	var by_cell := {}  # Vector3i(celda x, altura, celda z) -> Array[PlacedItem]
	for item in _items:
		var key := _cell_of(item)
		if not by_cell.has(key):
			by_cell[key] = []
		by_cell[key].append(item)
	var seen := {}
	for start in by_cell:
		if seen.has(start):
			continue
		var group := {}       # Vector2i -> id ("" si hay dos objetos en la celda)
		var members: Array[PlacedItem] = []
		var stack: Array = [start]
		seen[start] = true
		while not stack.is_empty():
			var cell: Vector3i = stack.pop_back()
			var here: Array = by_cell[cell]
			group[Vector2i(cell.x, cell.z)] = (here[0] as PlacedItem).item_id if here.size() == 1 else ""
			for it in here:
				members.append(it)
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var n := cell + Vector3i(dx, 0, dz)
					if by_cell.has(n) and not seen.has(n):
						seen[n] = true
						stack.append(n)
		var recipe := GroundRecipes.find(group, known)
		var center := Vector3.ZERO
		for it in members:
			center += it.global_position
		center /= members.size()
		for it in members:
			it.set_glow(recipe != "")
		if recipe != "":
			_matches.append({"recipe": recipe, "items": members, "center": center})


func _cell_of(item: PlacedItem) -> Vector3i:
	var p := item.global_position
	return Vector3i(floori(p.x / GroundRecipes.CELL), roundi(p.y * 8.0), floori(p.z / GroundRecipes.CELL))


## Hay que volver a mirar las formas (p. ej. el personaje ha aprendido una receta).
func refresh() -> void:
	_dirty = true


# ------------------------------------------------------------------ guardar

func to_data() -> Array:
	var out := []
	for item in _items:
		out.append(item.to_data())
	return out


func from_data(data: Array) -> void:
	for item in _items.duplicate():
		remove(item)
	for entry in data:
		if not entry is Dictionary:
			continue
		var d: Dictionary = entry
		var id := str(d.get("id", ""))
		var pos: Array = d.get("pos", [])
		var sup: Array = d.get("support", [])
		if not ItemDB.exists(id) or pos.size() != 3 or sup.size() != 3:
			continue
		place(Vector3(pos[0], pos[1], pos[2]), id, float(d.get("yaw", 0.0)),
			Vector3i(int(sup[0]), int(sup[1]), int(sup[2])))


func save_to(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(to_data()))


func load_from(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Array:
		from_data(data)
