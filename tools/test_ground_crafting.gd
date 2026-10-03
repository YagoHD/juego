extends SceneTree
## Prueba de fabricar en el suelo, sin ventana: formas detectadas aunque los objetos estén
## sueltos dentro de su celda, giradas o reflejadas, también apiladas en vertical; solo recetas
## conocidas; dos objetos en la misma celda estropean la forma; trozos de recetas dicen qué
## falta; fabricar quita los materiales (no las herramientas) y suelta el resultado; desmontar
## devuelve materiales y enseña la receta; apilar y recoger el montón entero.
## Uso: godot --headless --path . --script res://tools/test_ground_crafting.gd

const C := GroundRecipes.CELL
var _fails := 0
var _p: Player
var _g: GroundCrafting
var _world: Node3D


func _init() -> void:
	_world = Node3D.new()
	root.add_child.call_deferred(_world)


func _process(_delta: float) -> bool:
	if not _world.is_inside_tree():
		return false
	if _p == null:
		_p = Player.new()
		_world.add_child(_p)
		_p.set_physics_process(false)
		_p.set_process_input(false)
		_g = GroundCrafting.new()
		_world.add_child(_g)
		_g.player = _p
		_p.ground = _g
		_run()
		return true
	return false


## Deja un objeto en la celda (cx, cz), en un punto al azar dentro de ella.
func _put(id: String, cx: int, cz: int) -> PlacedItem:
	var pos := Vector3((cx + randf_range(0.1, 0.9)) * C, 0.0, (cz + randf_range(0.1, 0.9)) * C)
	return _g.place(pos, id, randf() * TAU, Vector3i(0, -1, 0))


func _clear() -> void:
	for item in _g._items.duplicate():
		_g.remove(item)
	for d in get_nodes_in_group("item_drops"):
		d.free()


func _recipes() -> Array:
	_g._find_matches()
	var out := []
	for m in _g._matches:
		out.append(m["recipe"])
	return out


func _drops() -> Dictionary:
	var out := {}
	for d: ItemDrop in get_nodes_in_group("item_drops"):
		out[d.item_id] = int(out.get(d.item_id, 0)) + d.count
	return out


func _run() -> void:
	_p.known_recipes.clear()
	for i in 3:
		_put("leaves", 4, 10 + i)
	_check("Sin saber nada, 3 hojas en línea = nada", _recipes().is_empty())
	_p.learn("rope")
	_check("Sabiendo la cuerda: 3 hojas en línea (sueltas en su celda) = cuerda", _recipes() == ["rope"])
	_p.global_position = Vector3(1.2, 0, 2.8)
	_check("Cerca de la forma aparece el aviso: '%s'" % _g.prompt(), _g.prompt().contains("Retorcer · Cuerda"))
	_clear()

	# Cinturón: no se conoce hasta leer la nota.
	for i in 3:
		_put("rope", i, 0)
	_check("3 cuerdas sin saber la receta = nada", _recipes().is_empty())
	_p.inventory.set_slot(0, {"id": "note_belt", "count": 1})
	_p._hotbar_index = 0
	_check("Leer la nota enseña el cinturón y la gasta", _p._read_note() and _p.known_recipes.has("belt") and _p.inventory.is_empty_slot(0))
	_check("Ahora las 3 cuerdas = cinturón", _recipes() == ["belt"])
	_clear()

	# Mochila: forma de 3x3 girada 90 grados y reflejada.
	_p.learn("rough_backpack")
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)]:
		_put("cloth", 20 + cell.x, 5 + cell.y)
	_put("rope", 22, 5)
	var last_rope := _put("rope", 22, 7)
	_check("Mochila girada = mochila improvisada", _recipes() == ["rough_backpack"])
	var extra := _put("cloth", 23, 6)
	_check("Con un objeto de más pegado = nada", _recipes().is_empty())
	_g.remove(extra)
	var twin := _put("cloth", 20, 5)
	_check("Dos objetos en la misma celda = nada", _recipes().is_empty())
	_g.remove(twin)
	_g.remove(last_rope)
	_g._find_matches()
	var hint := _g.prompt()
	_p.global_position = Vector3(5.3, 0, 1.5)
	hint = _g.prompt()
	_check("Si falta una pieza, dice cuál ('%s') y la muestra en transparente" % hint,
		hint.contains("falta 1 Cuerda") and _g._ghosts.get_child_count() == 1)
	_put("rope", 22, 7)
	_check("Al ponerla, vale", _recipes() == ["rough_backpack"])

	var data := _g.to_data()
	_g.from_data(data)
	_check("Guardar y cargar conserva los 8 objetos y la forma", _g.to_data().size() == 8 and _recipes() == ["rough_backpack"])
	_p.inventory.clear()
	_g.craft(_g._matches[0])
	_check("Fabricar quita los materiales y la mochila va al inventario", _g.to_data().is_empty() and _p.inventory.count_of("rough_backpack") == 1)
	_clear()

	# Herramientas: tallar tablones con el cuchillo; el cuchillo no se gasta.
	_p.learn("planks")
	_put("wood", 0, 0)
	_put("stone_knife", 1, 0)
	_check("Tronco + cuchillo = tablones", _recipes() == ["planks"])
	_p.inventory.clear()
	_g.craft(_g._matches[0])
	var left: Array = _g.to_data()
	_check("El cuchillo se queda en el suelo y salen 4 tablones", left.size() == 1 and left[0]["id"] == "stone_knife" and _p.inventory.count_of("planks") == 4)
	_clear()

	# Vertical: cofre = cubo de 2x2x2 tablones (apilados).
	_check("Al principio no se sabe hacer el cofre", not _p.known_recipes.has("chest"))
	var chest := _put("chest", 30, 30)
	_check("Un cofre solo en el suelo se puede desmontar", _recipes() == ["chest"] and _g.prompt() == "" or _g._matches[0]["dismantle"])
	_p.inventory.clear()
	_g.craft(_g._matches[0])
	_check("Desmontarlo da 8 tablones y enseña el cofre", _p.inventory.count_of("planks") == 8 and _p.known_recipes.has("chest"))
	_clear()
	var bottom: Array[PlacedItem] = []
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		bottom.append(_put("planks", 40 + cell.x, 40 + cell.y))
	_check("Solo la capa de abajo = falta la de arriba", _recipes().is_empty() and _g._partials.size() == 1)
	for b in bottom:
		_g.stack_on(b, "planks", 0.0)
	_check("Apilando la capa de arriba = cofre", _recipes() == ["chest"])
	var top: PlacedItem = _g._top_of(bottom[0])
	_check("El de arriba está más alto que el de abajo", top.level == 1 and top.global_position.y > bottom[0].global_position.y)
	_g.remove(bottom[0])
	_check("Si se quita uno de abajo, el de encima baja", top.level == 0 and is_equal_approx(top.global_position.y, bottom[1].global_position.y))
	var group := _g.group_of(bottom[1])
	_check("El montón entero son los 7 que quedan", group.size() == 7)
	_p.inventory.clear()
	_p._pick_up_placed(bottom[1], true)
	_check("Mayús + clic recoge el montón entero", _g._items.is_empty() and _p.inventory.count_of("planks") == 7)
	_clear()

	# Cuchillo en vertical: piedra encima del palito, cuerda al lado.
	_p.learn("stone_knife")
	var stick := _put("sticks", 50, 50)
	_put("rope", 51, 50)
	_g.stack_on(stick, "stone", 0.0)
	_check("Palito + piedra encima + cuerda al lado = cuchillo", _recipes() == ["stone_knife"])
	_clear()
	# Mesa de trabajo: 2 troncos y 2 tablones encima.
	_p.learn("workbench")
	var w1 := _put("wood", 60, 60)
	var w2 := _put("wood", 61, 60)
	_g.stack_on(w1, "planks", 0.0)
	_g.stack_on(w2, "planks", 0.0)
	_check("2 troncos con 2 tablones encima = mesa de trabajo", _recipes() == ["workbench"])
	_clear()
	# Pico: solo encima de la mesa.
	_p.learn("stone_pick")
	var s1 := _put("sticks", 70, 70)
	var s2 := _put("sticks", 70, 71)
	var r1 := _put("rope", 71, 70)
	_g.stack_on(s1, "stone", 0.0)
	_g.stack_on(r1, "stone", 0.0)
	_check("La forma del pico en el suelo = nada", _recipes().is_empty())
	_g.block_at = func(_c: Vector3i) -> int: return IslandGenerator.WORKBENCH
	_check("La misma forma encima de la mesa = pico", _recipes() == ["stone_pick"])
	_g.block_at = Callable()
	_clear()
	_check("Con el pico, la piedra se rompe 3 veces más rápido", ItemDB.tool_speed("stone_pick", IslandGenerator.STONE) == 3.0)
	_check("Cosas que se pueden coser o fabricar tienen dibujo", ItemDB.icon("stone_axe") != null)
	_clear()
	# Plantilla: la receta elegida en el recetario se dibuja en transparente; al ponerla, se va.
	_g.set_template("rope", Vector3(20.0 * C, 0.0, 20.0 * C))
	_g._find_matches()
	_check("La plantilla de la cuerda dibuja 3 hojas en transparente", _g._ghosts.get_child_count() == 3)
	_put("leaves", 20, 20)
	_g._find_matches()
	_check("Al poner una hoja en su sitio quedan 2", _g._ghosts.get_child_count() == 2)
	print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
	quit()


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1
