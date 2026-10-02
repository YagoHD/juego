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


func _init() -> void:
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
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE

	match _step:
		0:
			player.set_creative(false)
			player.inventory.clear()
			player.inventory.add("stone", 3)
			player._select_slot(0)
			player.debug_pose(false, -1.55, 0.0, 0.0)  # mirar al suelo
			_step = 1
		1:
			var target: Dictionary = player._target()
			if target.is_empty():
				print("FALLO: no apunta a ningún bloque mirando al suelo")
				return true
			var ground: Vector3i = target["voxel"]
			var above: Vector3i = target["place"]
			_ground_id = tool.get_voxel(ground)
			player._edit_block(true)
			var placed_inside := tool.get_voxel(above) != IslandGenerator.AIR
			print("Colocar dentro de uno mismo: %s" % ("FALLO, se colocó" if placed_inside else "OK, no se coloca"))
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
			player.debug_pose(false, -0.45, 0.0, 0.0)  # mirar al frente, a un bloque cercano
			_step = 3
			_wait = 0
		3:
			if _wait < 5:
				return false
			var target: Dictionary = player._target()
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
			return true
	return false


func _count_drops() -> int:
	return root.get_tree().get_nodes_in_group("item_drops").size()
