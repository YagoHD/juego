extends Node3D
class_name GroundCrafting
## Fabricar en el suelo: guarda los objetos dejados a mano (PlacedItem), mira qué formas hacen
## entre ellos (también apilados hacia arriba) y:
##   - si una es una receta que el personaje conoce, la hace brillar; desde la vista de fabricar
##     (CraftSession) aparece un botón y los objetos se convierten en el resultado (las
##     herramientas, como el cuchillo, no se gastan);
##   - si es un trozo de una receta conocida, muestra en transparente lo que falta;
##   - un objeto que se puede desmontar, dejado solo, se puede desmontar: devuelve sus
##     materiales y el personaje aprende a hacerlo;
##   - una "plantilla" (receta elegida en el recetario) se dibuja en transparente en su sitio.
##
## Los objetos se dejan donde sea, sin anclarse; solo para leer la forma se mira en qué celda
## invisible (GroundRecipes.CELL) cae cada uno. Dos objetos en la misma celda estropean la forma.

const WORK_DISTANCE := 2.2   # metros: hasta dónde se puede trabajar una forma
const HINT_DISTANCE := 6.0   # metros: hasta dónde se ven las piezas que faltan

signal crafted(recipe_id: String)

var player: Player
## Solo pruebas: qué bloque hay en una celda (si no, se mira el terreno del jugador).
var block_at := Callable()
var _items: Array[PlacedItem] = []
## {"recipe", "items", "center", "dismantle": bool} formas completas (o para desmontar).
var _matches: Array[Dictionary] = []
## {"recipe", "center", "missing": {id: cantidad}} trozos de recetas.
var _partials: Array[Dictionary] = []
var _ghosts: Node3D
var _dirty := true
## Plantilla: {"recipe", "origin": Vector3i(celda x, capa 0, celda z), "base_y", "support"} o {}.
var _template := {}


func _ready() -> void:
	_ghosts = Node3D.new()
	add_child(_ghosts)


## Deja un objeto en el suelo, en el punto 'pos' (encima del bloque 'support').
func place(pos: Vector3, id: String, yaw: float, support: Vector3i) -> PlacedItem:
	var item := _make(id, support, Vector2i(floori(pos.x / GroundRecipes.CELL), floori(pos.z / GroundRecipes.CELL)), 0, pos.y)
	item.global_position = pos
	item.rotation.y = yaw
	return item


## Apila un objeto encima de la columna de 'other'. Devuelve null si ya está muy alta.
func stack_on(other: PlacedItem, id: String, yaw: float) -> PlacedItem:
	var top := _top_of(other)
	if top.level + 1 >= GroundRecipes.MAX_LEVELS:
		return null
	var item := _make(id, top.support, top.column, top.level + 1, top.base_y)
	# Encima del de abajo, un pelín desplazado: apilado a mano, no perfecto.
	item.global_position = top.global_position + Vector3(randf_range(-0.03, 0.03), top.height(), randf_range(-0.03, 0.03))
	item.rotation.y = yaw
	return item


func _make(id: String, support: Vector3i, column: Vector2i, level: int, base_y: float) -> PlacedItem:
	var item := PlacedItem.new()
	item.item_id = id
	item.support = support
	item.column = column
	item.level = level
	item.base_y = base_y
	add_child(item)
	_items.append(item)
	_dirty = true
	return item


func _top_of(item: PlacedItem) -> PlacedItem:
	var top := item
	for other in _items:
		if other.column == item.column and other.support == item.support and other.level > top.level:
			top = other
	return top


## Quita un objeto del suelo y devuelve su id. Lo que estuviera apilado encima baja.
func remove(item: PlacedItem) -> String:
	_items.erase(item)
	for other in _items:
		if other.column == item.column and other.support == item.support and other.level > item.level:
			other.level -= 1
			other.global_position.y -= item.height()
	item.queue_free()
	_dirty = true
	return item.item_id


## Todos los objetos que se tocan con este (el montón entero).
func group_of(item: PlacedItem) -> Array[PlacedItem]:
	var by_cell := _by_cell()
	var start := _key(item)
	var out: Array[PlacedItem] = []
	var seen := {start: true}
	var stack: Array = [start]
	while not stack.is_empty():
		var cell: Vector3i = stack.pop_back()
		for it in by_cell[cell]:
			out.append(it)
		for n in _neighbours(cell):
			if by_cell.has(n) and not seen.has(n):
				seen[n] = true
				stack.append(n)
	return out


## Se ha roto un bloque: lo que estaba encima cae como objeto suelto.
func on_block_removed(cell: Vector3i) -> void:
	for item in _items.duplicate():
		if item.support == cell:
			ItemDrop.spawn(get_parent(), item.global_position + Vector3.UP * 0.2, item.item_id, 1)
			_items.erase(item)
			item.queue_free()
			_dirty = true


## Nombre de lo que se hace con una forma completa: "Coser · Mochila improvisada".
static func label_of(m: Dictionary) -> String:
	var recipe: Dictionary = GroundRecipes.RECIPES[m["recipe"]]
	var action: String = "Desmontar" if m["dismantle"] else recipe["action"]
	return "%s · %s" % [action, ItemDB.display_name(recipe["result"])]


## Qué le falta a un trozo de receta: "Mochila improvisada: falta 1 Cuerda".
static func missing_text(p: Dictionary) -> String:
	var parts: PackedStringArray = []
	var lack: Dictionary = p["missing"]
	for id in lack:
		parts.append("%d %s" % [lack[id], ItemDB.display_name(id)])
	var verb := "falta" if lack.size() == 1 and int(lack.values()[0]) == 1 else "faltan"
	return "%s: %s %s" % [ItemDB.display_name(GroundRecipes.RECIPES[p["recipe"]]["result"]), verb, ", ".join(parts)]


## Texto de lo más cercano al jugador ("" si no hay nada).
func prompt() -> String:
	var m := _nearest(_matches, WORK_DISTANCE)
	if not m.is_empty():
		return label_of(m)
	var p := _nearest(_partials, WORK_DISTANCE)
	return "" if p.is_empty() else missing_text(p)


## Formas completas (o para desmontar) cerca de un punto.
func matches_near(center: Vector3, radius: float) -> Array[Dictionary]:
	if _dirty:
		_dirty = false
		_find_matches()
	var out: Array[Dictionary] = []
	for m in _matches:
		if (m["center"] as Vector3).distance_to(center) < radius:
			out.append(m)
	return out


## Trozos de recetas cerca de un punto.
func partials_near(center: Vector3, radius: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in _partials:
		if (p["center"] as Vector3).distance_to(center) < radius:
			out.append(p)
	return out


## Dibuja en transparente la receta elegida en el recetario, empezando en el punto "at" (su
## celda) y apoyada en el bloque "support". recipe_id "" la quita.
func set_template(recipe_id: String, at: Vector3 = Vector3.ZERO, support := Vector3i.ZERO) -> void:
	if recipe_id == "":
		_template = {}
	else:
		_template = {"recipe": recipe_id, "base_y": at.y, "support": support,
			"origin": Vector3i(floori(at.x / GroundRecipes.CELL), 0, floori(at.z / GroundRecipes.CELL))}
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_find_matches()


## Termina una receta: quita los materiales y el resultado va a la mochila del jugador (lo que
## no quepa cae al suelo). Si es desmontar: quita el objeto, devuelve sus materiales y enseña
## la receta.
func craft(m: Dictionary) -> void:
	var recipe_id: String = m["recipe"]
	var recipe: Dictionary = GroundRecipes.RECIPES[recipe_id]
	var center: Vector3 = m["center"]
	if m["dismantle"]:
		for item: PlacedItem in m["items"]:
			remove(item)
		var mats := GroundRecipes.materials_of(recipe_id)
		for id in mats:
			_give(id, int(mats[id]), center)
		Sfx.play("aprender", center)
		if player != null and player.learn(recipe_id):
			player.notice.emit("Al desmontarlo has aprendido a hacer: %s. Está en el diario (J)." % ItemDB.display_name(recipe["result"]))
	else:
		var tools := GroundRecipes.tools_of(recipe_id)
		for item: PlacedItem in m["items"]:
			if not tools.has(item.item_id):
				remove(item)
		_give(recipe["result"], int(recipe["count"]), center)
		Sfx.play("fabricado", center)
		crafted.emit(recipe_id)
		if not _template.is_empty() and _template["recipe"] == recipe_id:
			_template = {}  # hecha: la plantilla ya no hace falta
	_spawn_dust(center)
	_find_matches()


## Da objetos al jugador (a sus huecos disponibles); lo que no cabe, al suelo.
func _give(id: String, count: int, at: Vector3) -> void:
	var left := count if player == null else player.pick_up(id, count)
	if left > 0:
		ItemDrop.spawn(get_parent(), at + Vector3.UP * 0.3, id, left)


func _nearest(list: Array[Dictionary], max_distance: float) -> Dictionary:
	if player == null:
		return {}
	var best := {}
	var best_d := max_distance
	for m in list:
		var d := (m["center"] as Vector3).distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = m
	return best


# ------------------------------------------------------------------ leer las formas

## Clave de la celda de un objeto: (columna x, altura del suelo y capa, columna z). Las capas de
## una misma columna quedan una encima de otra (y de 1 en 1), así que se tocan como vecinas.
func _key(item: PlacedItem) -> Vector3i:
	return Vector3i(item.column.x, item.support.y * 16 + item.level, item.column.y)


func _by_cell() -> Dictionary:
	var by_cell := {}
	for item in _items:
		var key := _key(item)
		if not by_cell.has(key):
			by_cell[key] = []
		by_cell[key].append(item)
	return by_cell


func _neighbours(cell: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx != 0 or dy != 0 or dz != 0:
					out.append(cell + Vector3i(dx, dy, dz))
	return out


## Agrupa los objetos que se tocan y mira si cada grupo es una receta conocida, un trozo de una,
## o algo que se puede desmontar.
func _find_matches() -> void:
	_matches.clear()
	_partials.clear()
	for ghost in _ghosts.get_children():
		_ghosts.remove_child(ghost)  # fuera ya (si no, cuentan hasta el siguiente fotograma)
		ghost.queue_free()
	var known: Array = player.known_recipes if player != null else GroundRecipes.KNOWN_AT_START
	var by_cell := _by_cell()
	var seen := {}
	for start in by_cell:
		if seen.has(start):
			continue
		var group := {}       # Vector3i(x, capa, z) -> id ("" si hay dos objetos en la celda)
		var members: Array[PlacedItem] = []
		var stack: Array = [start]
		seen[start] = true
		while not stack.is_empty():
			var cell: Vector3i = stack.pop_back()
			var here: Array = by_cell[cell]
			var first: PlacedItem = here[0]
			group[Vector3i(cell.x, first.level, cell.z)] = first.item_id if here.size() == 1 else ""
			for it in here:
				members.append(it)
			for n in _neighbours(cell):
				if by_cell.has(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
		var center := Vector3.ZERO
		for it in members:
			center += it.global_position
		center /= members.size()

		var bench := _on_workbench(members)
		var recipe := GroundRecipes.find(group, known, bench)
		var dismantle := false
		if recipe == "" and members.size() == 1:
			recipe = _dismantle_recipe(members[0].item_id)
			dismantle = recipe != ""
		for it in members:
			if it.item_id == "captain_journal":
				it.set_glow(true, 0.25)  # el diario llama un poco la atención
			else:
				it.set_glow(recipe != "")
		if recipe != "":
			_matches.append({"recipe": recipe, "items": members, "center": center, "dismantle": dismantle})
		elif members.size() >= 2 and not group.values().has(""):
			_add_partial(group, members, center, known, bench)
	_draw_template()


## ¿Está todo el grupo encima de mesas de trabajo?
func _on_workbench(members: Array[PlacedItem]) -> bool:
	for it in members:
		if _block_at(it.support) != IslandGenerator.WORKBENCH:
			return false
	return true


func _block_at(cell: Vector3i) -> int:
	if block_at.is_valid():
		return int(block_at.call(cell))
	if player == null or player._tool == null:
		return IslandGenerator.AIR
	return player._tool.get_voxel(cell)


## La plantilla del recetario: cada pieza que aún no está puesta, en transparente en su sitio.
func _draw_template() -> void:
	if _template.is_empty():
		return
	var origin: Vector3i = _template["origin"]
	var cells := GroundRecipes.cells_of(_template["recipe"])
	for c: Vector3i in cells:
		var col := Vector2i(origin.x + c.x, origin.z + c.z)
		var id: String = cells[c]
		var done := false
		var y: float = _template["base_y"] + c.y * 0.18
		for it in _items:
			if it.column == col and it.level == c.y and it.item_id == id:
				done = true
			if it.column == col and it.level == c.y - 1:
				y = it.global_position.y + it.height()
		if not done:
			var pos := Vector3((col.x + 0.5) * GroundRecipes.CELL, y, (col.y + 0.5) * GroundRecipes.CELL)
			_ghosts.add_child(_make_ghost(id, pos))


## Receta de desmontar este objeto ("" si no se puede).
func _dismantle_recipe(id: String) -> String:
	for recipe_id in GroundRecipes.RECIPES:
		var recipe: Dictionary = GroundRecipes.RECIPES[recipe_id]
		if recipe["result"] == id and recipe.get("dismantle", false):
			return recipe_id
	return ""


## Si el grupo es un trozo de una receta conocida: lo apunta y pone las piezas que faltan en
## transparente, en su sitio.
func _add_partial(group: Dictionary, members: Array[PlacedItem], center: Vector3, known: Array, bench: bool) -> void:
	var best_recipe := ""
	var best := {}
	for recipe_id in known:
		if not GroundRecipes.RECIPES.has(recipe_id) or not GroundRecipes.allowed_on(recipe_id, bench):
			continue
		var lack := GroundRecipes.missing(group, recipe_id)
		if not lack.is_empty() and (best.is_empty() or lack.size() < best.size()):
			best = lack
			best_recipe = recipe_id
	if best_recipe == "":
		return
	var count := {}
	for cell in best:
		count[best[cell]] = int(count.get(best[cell], 0)) + 1
	_partials.append({"recipe": best_recipe, "center": center, "missing": count})
	if player != null and center.distance_to(player.global_position) > HINT_DISTANCE:
		return
	var base: PlacedItem = members[0]
	for cell: Vector3i in best:
		var id: String = best[cell]
		var y := base.base_y + cell.y * 0.18
		for it in members:  # encima de un objeto puesto: justo sobre él (los planos son finos)
			if it.column == Vector2i(cell.x, cell.z) and it.level == cell.y - 1:
				y = it.global_position.y + it.height()
		var pos := Vector3((cell.x + 0.5) * GroundRecipes.CELL, y, (cell.z + 0.5) * GroundRecipes.CELL)
		_ghosts.add_child(_make_ghost(id, pos))


func _make_ghost(id: String, pos: Vector3) -> MeshInstance3D:
	var ghost := MeshInstance3D.new()
	var is_block := ItemDB.block_of(id) >= 0
	var size := 0.18 if is_block else 0.3
	ghost.mesh = ItemMesh.make(id, size)
	var material := ItemMesh.make_material(id)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 1, 1, 0.35)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override = material
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.position = pos + Vector3.UP * (size * 0.5 if is_block else 0.01)
	if not is_block:
		ghost.rotation.x = -PI / 2.0
	return ghost


## Polvillo al terminar de fabricar.
func _spawn_dust(center: Vector3) -> void:
	var particles := CPUParticles3D.new()
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * 0.04
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.78, 0.62)
	chunk.material = material
	particles.mesh = chunk
	particles.amount = 16
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 80.0
	particles.initial_velocity_min = 0.6
	particles.initial_velocity_max = 1.6
	particles.gravity = Vector3(0, -4.0, 0)
	add_child(particles)
	particles.global_position = center + Vector3.UP * 0.1
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)


## ¿Sigue este objeto en el suelo?
func has_placed(item: PlacedItem) -> bool:
	return _items.has(item)


## ¿Hay en el suelo algún objeto de este tipo?
func has_item(id: String) -> bool:
	for item in _items:
		if item.item_id == id:
			return true
	return false


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
		_items.erase(item)
		item.queue_free()
	for entry in data:
		if not entry is Dictionary:
			continue
		var d: Dictionary = entry
		var id := str(d.get("id", ""))
		var pos: Array = d.get("pos", [])
		var sup: Array = d.get("support", [])
		if not ItemDB.exists(id) or pos.size() != 3 or sup.size() != 3:
			continue
		var p := Vector3(pos[0], pos[1], pos[2])
		var col: Array = d.get("column", [floori(p.x / GroundRecipes.CELL), floori(p.z / GroundRecipes.CELL)])
		var item := _make(id, Vector3i(int(sup[0]), int(sup[1]), int(sup[2])), Vector2i(int(col[0]), int(col[1])),
			int(d.get("level", 0)), float(d.get("base_y", p.y)))
		item.global_position = p
		item.rotation.y = float(d.get("yaw", 0.0))
		if item.campfire != null and d.get("state") is Dictionary:
			item.campfire.set_state(d["state"])
	_dirty = true


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
