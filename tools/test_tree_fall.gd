extends SceneTree
## Prueba de talar un árbol en la isla real (sin ventana): se busca un árbol cerca, se rompe el
## primer bloque del tronco y se comprueba que el resto cae, que el tronco queda tumbado entero en
## el suelo y que las hojas dejan objetos esparcidos.
## Uso: godot --headless --path . --script res://tools/test_tree_fall.gd

var _main: Node
var _step := 0
var _t0 := 0
var _fails := 0
var _cut := Vector3i.ZERO
var _height := 0
var _wood_before := 0


func _init() -> void:
	Main.test_mode = true
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	var terrain: VoxelTerrain = _main.get("_terrain")
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	match _step:
		0:
			# Buscar un árbol de tronco normal (con hojas) cerca del jugador.
			var me := Vector3i((player.global_position / 0.5).floor())
			for r in range(4, 70):
				for dx in range(-r, r + 1):
					for dz in [-r, r]:
						if _try_tree(tool, me + Vector3i(dx, 0, dz)):
							break
					if _height > 0:
						break
				if _height > 0:
					break
			if _height == 0:
				print("AVISO: no hay árboles cerca (prueba omitida)")
				return true
			_wood_before = _count_wood(tool, _cut, 12)
			print("Árbol encontrado en ", _cut, " con tronco de ", _height)
			tool.set_voxel(_cut, IslandGenerator.AIR)
			var from := (Vector3(_cut) + Vector3(-3, 0, 0)) * 0.5
			_check("Romper el pie del tronco hace caer el árbol", TreeFelling.try_fell(_main, terrain, _cut, IslandGenerator.WOOD, from))
			_check("Lo de encima ya no está en pie", tool.get_voxel(_cut + Vector3i.UP) == IslandGenerator.AIR)
			_t0 = Time.get_ticks_msec()
			_step = 1
		1:
			if Time.get_ticks_msec() - _t0 < 9000:
				return false
			# Caído hacia +X (lejos de quien tala): tronco tumbado a lo largo de X, a ras de suelo.
			var lying := 0
			for dx in range(-14, 15):
				for dy in range(-6, 4):
					for dz in range(-14, 15):
						var id := tool.get_voxel(_cut + Vector3i(dx, dy, dz))
						if id == IslandGenerator.LOG_X or id == IslandGenerator.LOG_Z:
							lying += 1
			_check("El tronco queda tumbado entero (%d de %d bloques)" % [lying, _height - 1], lying >= _height - 1)
			var leaves := 0
			for d: ItemDrop in get_nodes_in_group("item_drops"):
				if d.item_id == "leaves" or d.item_id == "pine_leaves":
					leaves += d.count
			_check("Las hojas dejan objetos por el suelo (%d)" % leaves, leaves > 0)
			print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
			return true
	return false


## ¿Hay aquí el pie de un árbol? (tronco sobre tierra/hierba, con hojas arriba y espacio libre
## hacia +X para caer)
func _try_tree(tool: VoxelTool, column: Vector3i) -> bool:
	for y in range(column.y - 12, column.y + 12):
		var c := Vector3i(column.x, y, column.z)
		if tool.get_voxel(c) != IslandGenerator.WOOD or tool.get_voxel(c + Vector3i.UP) != IslandGenerator.WOOD:
			continue
		var below := tool.get_voxel(c + Vector3i.DOWN)
		if below == IslandGenerator.WOOD or below == IslandGenerator.AIR:
			continue
		var h := 0
		while tool.get_voxel(c + Vector3i(0, h, 0)) == IslandGenerator.WOOD:
			h += 1
		# Tronco de una columna (sin vecinos de 2x2) y con hueco a +X.
		if tool.get_voxel(c + Vector3i(1, 0, 0)) == IslandGenerator.WOOD or tool.get_voxel(c + Vector3i(0, 0, 1)) == IslandGenerator.WOOD \
				or tool.get_voxel(c + Vector3i(-1, 0, 0)) == IslandGenerator.WOOD or tool.get_voxel(c + Vector3i(0, 0, -1)) == IslandGenerator.WOOD:
			continue
		if h < 4:
			continue
		_cut = c
		_height = h
		return true
	return false


func _count_wood(tool: VoxelTool, at: Vector3i, r: int) -> int:
	var n := 0
	for dx in range(-r, r + 1):
		for dy in range(-2, r + 1):
			for dz in range(-r, r + 1):
				if tool.get_voxel(at + Vector3i(dx, dy, dz)) == IslandGenerator.WOOD:
					n += 1
	return n


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1
