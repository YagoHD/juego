extends SceneTree

func _initialize() -> void:
	var storage := ChestStorage.new()
	ShowroomGenerator.stock_item_chests(storage)
	var found := {}
	var failed := false
	for chest in ShowroomGenerator.item_chests():
		var inventory := storage.get_or_create(chest["cell"])
		for i in inventory.size():
			var stack := inventory.get_slot(i)
			if stack.is_empty(): continue
			var id: String = stack["id"]
			if found.has(id) or stack["count"] != ItemDB.max_stack(id): failed = true
			if ItemDB.max_durability(id) > 0 and stack.get("dur", 0) != ItemDB.max_durability(id): failed = true
			found[id] = true
	for catalog: Dictionary in [ItemDB.BLOCK_ITEMS, ItemDB.OTHER_ITEMS]:
		for id in catalog:
			if not found.has(id): failed = true
	print("Cofres: %d; objetos distintos: %d; catálogo completo y herramientas nuevas: %s" % [ShowroomGenerator.item_chests().size(), found.size(), "FALLO" if failed else "OK"])
	quit(1 if failed else 0)
