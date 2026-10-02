extends SceneTree
## Prueba de fabricar en el suelo, sin ventana: formas detectadas aunque los objetos estén
## sueltos dentro de su celda, giradas o reflejadas; solo recetas conocidas; dos objetos en la
## misma celda estropean la forma; fabricar quita los materiales y suelta el resultado.
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
	for item in _g.get_children():
		if item is PlacedItem:
			_g.remove(item)


func _recipes() -> Array:
	_g._find_matches()
	var out := []
	for m in _g._matches:
		out.append(m["recipe"])
	return out


func _run() -> void:
	# Cuerda: 3 hojas en línea (vertical), conocida desde el principio.
	for i in 3:
		_put("leaves", 4, 10 + i)
	_check("3 hojas en línea (sueltas en su celda) = cuerda", _recipes() == ["rope"])
	_p.global_position = Vector3(1.2, 0, 2.8)
	_check("Cerca de la forma aparece el aviso: '%s'" % _g.prompt(), _g.prompt().contains("Retorcer"))
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
	#   original:  C . C      girada:  T T C
	#              T T T               T T .
	#              T T T               T T C
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)]:
		_put("cloth", 20 + cell.x, 5 + cell.y)
	_put("rope", 22, 5)
	_put("rope", 22, 7)
	_check("Mochila girada = mochila improvisada", _recipes() == ["rough_backpack"])
	var extra := _put("cloth", 23, 6)
	_check("Con un objeto de más pegado = nada", _recipes().is_empty())
	_g.remove(extra)
	var twin := _put("cloth", 20, 5)
	_check("Dos objetos en la misma celda = nada", _recipes().is_empty())
	_g.remove(twin)
	_check("Quitándolo vuelve a valer", _recipes() == ["rough_backpack"])

	# Guardar y cargar.
	var data := _g.to_data()
	_g.from_data(data)
	_check("Guardar y cargar conserva los 8 objetos y la forma", _g.to_data().size() == 8 and _recipes() == ["rough_backpack"])

	# Fabricar.
	_g.craft(_g._matches[0])
	var drops := get_nodes_in_group("item_drops")
	_check("Fabricar quita los materiales y suelta la mochila", _g.to_data().is_empty()
		and drops.size() == 1 and (drops[0] as ItemDrop).item_id == "rough_backpack")
	_check("La mochila improvisada da 9 huecos", ItemDB.storage("rough_backpack") == 9 and ItemDB.wear_slot("rough_backpack") == "backpack")
	print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
	quit()


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1
