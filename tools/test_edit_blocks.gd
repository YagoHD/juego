extends SceneTree
## Prueba de romper/colocar e inventario sobre la isla real, sin ventana.
## Uso: godot --headless --path . --script res://tools/test_edit_blocks.gd
## Con 3 de piedra en la barra y mirando al suelo justo bajo los pies:
##   1. colocar NO debe funcionar (el hueco lo ocupa el propio jugador);
##   2. romper debe quitar el bloque, soltar partículas y un objeto que el jugador recoge solo;
## y mirando al frente a un bloque cercano:
##   3. colocar SÍ debe funcionar y gastar una piedra.

var _main: Node
var _step := 0
var _wait := 0
var _ground_id := 0
var _hold_target := {}
var _hold_block := 0
var _hold_start := 0


func _init() -> void:
	Main.test_mode = true  # mundo de pruebas aparte: nunca toca el mundo guardado del jugador
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	_wait += 1
	if _wait < 30:
		return false  # deja que se asienten la física y la cámara
	var terrain: VoxelTerrain = _main.get("_terrain")
	var tool := WorldVoxels.tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE

	match _step:
		0:
			var ground_items: GroundCrafting = _main.get("_ground")
			print("El diario del capitán está en el suelo al empezar: %s" % ("OK" if ground_items.has_item("captain_journal") and not player.has_journal else "FALLO"))
			player.pick_up("captain_journal", 1)
			print("Recogerlo enseña lo básico (cuerda, piedra afilada, hoguera): %s" % ("OK" if player.has_journal and player.known_recipes.has("rope") and player.known_recipes.has("sharp_rock") and player.known_recipes.has("campfire") else "FALLO"))
			player.set_creative(false)
			player.inventory.clear()
			player.inventory.add("stone", 3)
			player._select_slot(0)
			player.debug_pose(false, -1.55, 0.0, 0.0)  # mirar al suelo
			_step = 1
		1:
			var target: Dictionary = player.aim.target()
			if target.is_empty():
				print("FALLO: no apunta a ningún bloque mirando al suelo")
				return true
			var ground: Vector3i = target["voxel"]
			var above: Vector3i = target["place"]
			_ground_id = tool.get_voxel(ground)
			var overlaps: bool = player._overlaps_body(above)
			player._edit_block(true)
			var placed := tool.get_voxel(above) != IslandGenerator.AIR
			# La regla: solo se coloca si el bloque no se solapa con el cuerpo del jugador.
			print("No colocar dentro de uno mismo (se solapa=%s, colocado=%s): %s" % [
				overlaps, placed, "OK" if placed != overlaps else "FALLO"])
			if placed:
				tool.set_voxel(above, IslandGenerator.AIR)  # deshacer, para seguir la prueba igual
			player._edit_block(false)
			var removed := tool.get_voxel(ground) == IslandGenerator.AIR
			print("Romper el suelo (bloque %d): %s" % [_ground_id, "OK, quitado" if removed else "FALLO, sigue ahí"])
			print("Objeto soltado al romper: %s" % ("OK" if _count_drops() > 0 else "FALLO, no hay"))
			_step = 2
			_wait = 0
		2:
			if _wait < 90:  # 1,5 s: el objeto salta, cae y el jugador lo recoge
				return false
			var drop := ItemDB.drop_of(_ground_id)
			var got := player.inventory.count_of(drop)
			print("Recogida automática (%s): %s" % [drop, "OK, %d en el inventario" % got if got >= 1 else "FALLO"])
			player.debug_pose(false, -0.8, 0.0, 0.0)  # mirar al frente y abajo, a un bloque cercano
			_step = 3
			_wait = 0
		3:
			if _wait < 5:
				return false
			var target: Dictionary = player.aim.target()
			if target.is_empty():
				print("AVISO: al frente no hay bloque al alcance (prueba de colocar omitida)")
				return true
			player._select_slot(0)
			var cell: Vector3i = target["place"]
			var before := player.inventory.count_of("stone")
			player._edit_block(true)
			var placed := tool.get_voxel(cell) == IslandGenerator.STONE
			var spent := player.inventory.count_of("stone") == before - 1
			print("Colocar al frente gasta una piedra: %s" % ("OK" if placed and spent else "FALLO (colocado=%s, gastado=%s)" % [placed, spent]))
			# G: dejar una cuerda en el suelo donde se apunta.
			player.inventory.clear()
			player.inventory.add("rope", 3)
			player._select_slot(0)
			player.debug_pose(false, -1.0, 180.0, 0.0)  # hacia atrás: suelo libre
			_step = 4
			_wait = 0
		4:
			if _wait < 5:
				return false
			var ok := player.builder.place_on_ground(player.aim.target())
			print("G deja una cuerda en el suelo: %s" % ("OK" if ok and player.inventory.count_of("rope") == 2 else "FALLO"))
			_step = 5
			_wait = 0
		5:
			if _wait < 5:
				return false  # unos fotogramas apuntando al objeto (el recuadro lo rodea)
			var target: Dictionary = player.aim.target()
			var highlight: MeshInstance3D = player.aim.highlight
			print("Apuntar a la cuerda del suelo la recuadra: %s" % ("OK" if target.has("item") and highlight.visible else "FALLO"))
			player._edit_block(false)
			print("Clic izquierdo la recoge: %s" % ("OK" if player.inventory.count_of("rope") == 3 else "FALLO"))
			player.inventory.clear()
			_step = 6
			_wait = 0
		6:
			# Romper manteniendo el clic: el bloque aguanta un rato y muestra grietas.
			if _wait < 33:
				return false  # que desaparezca del todo la cuerda recogida
			if _wait == 33:
				_hold_target = player.aim.target()
				_hold_block = tool.get_voxel(_hold_target["voxel"])
				var press := InputEventMouseButton.new()
				press.button_index = MOUSE_BUTTON_LEFT
				press.pressed = true
				_hold_start = Time.get_ticks_msec()
				Input.parse_input_event(press)
				return false
			if _wait == 40:
				var cracks: BlockCracks = player.breaker.cracks
				var still := tool.get_voxel(_hold_target["voxel"]) == _hold_block
				print("Al poco de mantener el clic, el bloque sigue y tiene grietas: %s" % ("OK" if still and cracks.visible else "FALLO (sigue=%s, grietas=%s)" % [still, cracks.visible]))
			if Time.get_ticks_msec() - _hold_start < int((Blocks.hardness(_hold_block) + 0.5) * 1000.0):
				return false
			var gone := tool.get_voxel(_hold_target["voxel"]) != _hold_block
			print("Manteniendo %.1f s se rompe: %s" % [Blocks.hardness(_hold_block), "OK" if gone else "FALLO"])
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.pressed = false
			Input.parse_input_event(release)
			return true
	return false


func _count_drops() -> int:
	return root.get_tree().get_nodes_in_group("item_drops").size()
