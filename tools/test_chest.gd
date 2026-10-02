extends SceneTree
## Prueba de los cofres del naufragio, sin ventana.
## Uso: godot --headless --path . --script res://tools/test_chest.gd
##   1. Los dos cofres del naufragio existen en el mundo.
##   2. Al abrir uno, aparece la pantalla con su botín.
##   3. Mayús+clic en un hueco del cofre pasa ese montón al jugador.
##   4. Al romper un cofre, su contenido cae al suelo como objetos.

var _main: Node
var _step := 0
var _wait := 0
var _cell := Vector3i.ZERO


func _init() -> void:
	Main.test_mode = true  # mundo de pruebas aparte: nunca toca el mundo guardado del jugador
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	_wait += 1
	if _wait < 60:
		return false
	var terrain: VoxelTerrain = _main.get("_terrain")
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	match _step:
		0:
			var cells: Array = Structures._chest_loot.keys()
			var found := 0
			for c in cells:
				if tool.get_voxel(c) == IslandGenerator.CHEST:
					found += 1
					_cell = c
			print("Cofres del naufragio en el mundo: %d de %d -> %s" % [found, cells.size(), "OK" if found == cells.size() else "FALLO"])
			player.inventory.clear()
			_main._on_block_used(_cell, IslandGenerator.CHEST)
			var screen: InventoryScreen = _main.get("_inventory_screen")
			var chest: Inventory = _main.get("_chests").get_or_create(_cell)
			var items := 0
			for i in chest.size():
				items += 0 if chest.is_empty_slot(i) else 1
			print("Abrir cofre: pantalla visible=%s, montones de botín=%d -> %s" % [screen.visible, items, "OK" if screen.visible and items > 0 else "FALLO"])
			# Mayús+clic en el primer hueco del cofre.
			var first: Dictionary = chest.get_slot(0)
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.shift_pressed = true
			screen._on_slot_input(click, 0, 0)
			var moved := player.inventory.count_of(first["id"]) == int(first["count"]) and chest.is_empty_slot(0)
			print("Mayús+clic pasa %d de %s al jugador -> %s" % [int(first["count"]), first["id"], "OK" if moved else "FALLO"])
			screen.close()
			_step = 1
			_wait = 30
		1:
			var before := root.get_tree().get_nodes_in_group("item_drops").size()
			tool.set_voxel(_cell, IslandGenerator.AIR)
			_main._on_block_broken(_cell, IslandGenerator.CHEST)
			var after := root.get_tree().get_nodes_in_group("item_drops").size()
			print("Romper cofre suelta su contenido: %d objetos -> %s" % [after - before, "OK" if after > before else "FALLO"])
			return true
	return false
