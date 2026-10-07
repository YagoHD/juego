extends SceneTree
## Eventos GUI reales: clic, arrastre, barra inferior y tirar fuera; conserva durabilidad.
var failures := 0
var arena: Node3D
var screen: InventoryScreen
var player: Player
var held := false

func _init() -> void:
	Engine.max_fps = 120
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	print(("OK: " if ok else "FALLO: ") + message)
	if not ok:
		failures += 1

func frames(count := 3) -> void:
	for i in count:
		await process_frame

func point(index: int) -> Vector2:
	for view in screen._slot_views:
		if int(view["index"]) == index:
			return (view["panel"] as Control).get_global_rect().get_center()
	return Vector2.ZERO

func move_mouse(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(motion)

func button(pos: Vector2, pressed: bool, kind := MOUSE_BUTTON_LEFT, shift := false) -> void:
	move_mouse(pos)
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = kind
	event.pressed = pressed
	event.shift_pressed = shift
	if kind == MOUSE_BUTTON_LEFT:
		held = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event)

func click(pos: Vector2, kind := MOUSE_BUTTON_LEFT, shift := false) -> void:
	button(pos, true, kind, shift)
	button(pos, false, kind, shift)
	await frames()

func drag(from: Vector2, to: Vector2) -> void:
	button(from, true)
	await frames()
	move_mouse(to)
	await frames()
	button(to, false)
	await frames()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	arena = load("res://scenes/combat_arena.tscn").instantiate()
	arena.set("save_path", "user://inventory_interactions_test.json")
	root.add_child(arena)
	player = arena.player
	screen = arena._inventory
	await frames(15)
	for node in get_nodes_in_group("creatures"):
		node.free()
	player.inventory.clear()
	player.set_equipment({"shirt": "shirt", "pants": "pants", "belt": "belt", "backpack": "backpack"})
	player.inventory.set_slot(9, {"id": "stone_axe", "count": 1, "dur": 13})
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	root.push_input(key)
	await frames(8)
	check(screen.visible and screen._sections.size() == 2, "arena muestra almacenamiento y barra separados")
	await click(point(9))
	check(screen.cursor_stack().get("id", "") == "stone_axe", "clic recoge montón")
	await click(point(0))
	check(player.inventory.get_slot(0).get("dur", 0) == 13 and screen.cursor_stack().is_empty(), "clic mueve herramienta a barra sin repararla")
	player.inventory.set_slot(10, {"id": "spear", "count": 1, "dur": 7})
	await drag(point(10), point(1))
	check(player.inventory.get_slot(1).get("dur", 0) == 7 and player.inventory.is_empty_slot(10), "arrastrar y soltar entre huecos funciona")
	player.inventory.set_slot(11, {"id": "stone_knife", "count": 1, "dur": 19})
	await drag(point(11), arena._hotbar._slots[2].get_global_rect().get_center())
	check(player.inventory.get_slot(2).get("dur", 0) == 19 and player.inventory.is_empty_slot(11), "arrastrar a barra inferior visible funciona")
	player.inventory.set_slot(12, {"id": "stone_pick", "count": 1, "dur": 27})
	await click(point(12), MOUSE_BUTTON_LEFT, true)
	check(player.inventory.get_slot(3).get("dur", 0) == 27 and player.inventory.is_empty_slot(12), "Mayús clic envía a barra y conserva desgaste")
	await click(point(0), MOUSE_BUTTON_RIGHT)
	await click(point(13), MOUSE_BUTTON_RIGHT)
	check(player.inventory.get_slot(13).get("dur", 0) == 13, "clic derecho conserva desgaste")
	await click(point(13))
	var before := get_nodes_in_group("item_drops").size()
	await click(Vector2(20, 320))
	var drops := get_nodes_in_group("item_drops")
	check(drops.size() == before + 1 and screen.cursor_stack().is_empty(), "clic fuera tira montón al mundo")
	if drops.is_empty():
		quit(1)
		return
	var dropped := drops.back() as ItemDrop
	check(int(dropped.metadata.get("dur", 0)) == 13, "objeto tirado mantiene desgaste")
	screen.close()
	dropped._give_to(player)
	check(player.inventory.get_slot(0).get("dur", 0) == 13, "recoger del suelo mantiene desgaste")
	# Abrir de nuevo y probar arrastre al mundo y tirar uno con clic derecho.
	root.push_input(key)
	await frames(8)
	player.inventory.set_slot(14, {"id": "hide", "count": 5})
	await drag(point(14), Vector2(20, 320))
	check(player.inventory.is_empty_slot(14) and screen.cursor_stack().is_empty(), "arrastre fuera tira montón completo")
	player.inventory.set_slot(15, {"id": "bone", "count": 4})
	await click(point(15))
	await click(Vector2(20, 320), MOUSE_BUTTON_RIGHT)
	check(int(screen.cursor_stack().get("count", 0)) == 3, "clic derecho fuera tira solo una unidad")
	screen.set_layout("craft")
	var signals := {"world": 0, "thrown": 0, "dragged": 0}
	screen.world_input.connect(func(_event: InputEvent) -> void: signals["world"] += 1)
	screen.stack_dropped.connect(func(_stack: Dictionary) -> void: signals["thrown"] += 1)
	screen.world_drop.connect(func() -> void: signals["dragged"] += 1)
	await click(Vector2(20, 320))
	check(signals["world"] > 0 and signals["thrown"] == 0 and signals["dragged"] == 0, "fabricación conserva interacción especial sin soltar dos veces")
	screen.close()
	arena.free()
	print("TOTAL: %d fallos" % failures)
	quit(1 if failures else 0)
