extends SceneTree
## Prueba de talar un árbol en la isla real (sin ventana): se busca un roble o un pino cerca, se
## corta todo el ancho de su tronco por la base y se comprueba que cae, que al golpear el suelo
## revienta en madera para recoger, que las hojas dejan objetos, que queda un tocón y que, pasado
## el tiempo, el árbol vuelve a crecer.
## Uso: godot --headless --path . --script res://tools/test_tree_fall.gd

var _main: Node
var _step := 0
var _t0 := 0
var _fails := 0
var _base := Vector3i.ZERO      # pie del árbol (centro del tronco, a ras de suelo)
var _prefab := -1
var _trunk_above := 0           # trozos de tronco por encima del corte


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
			if not _find_tree(tool, Vector3i((player.global_position / 0.5).floor())):
				print("AVISO: no hay árboles cerca (prueba omitida)")
				return true
			print("Árbol %s en %s, %d trozos de tronco por encima del corte" % [PrefabLibrary.NAMES[_prefab], _base, _trunk_above])
			# Cortar todo el ancho del tronco a ras de suelo; el último corte lo derriba.
			var cuts: Array[Vector3i] = []
			for piece in PrefabLibrary.pieces(_prefab):
				var c: Vector3i = piece[0]
				if c.y == 0 and PrefabLibrary.kind(piece[1]) == "wood":
					cuts.append(_base + c)
			var fell := false
			for i in cuts.size():
				tool.set_voxel(cuts[i], IslandGenerator.AIR)
				var from := (Vector3(cuts[i]) + Vector3(-3, 0, 0)) * 0.5
				var now := TreeFelling.try_fell(_main, terrain, cuts[i], PrefabLibrary.first_id(PrefabLibrary.NAMES[_prefab]), from)
				if now and i < cuts.size() - 1:
					_check("No cae hasta cortar todo el ancho del tronco", false)
				fell = fell or now
			_check("Cortado todo el ancho, el árbol cae (%d cortes)" % cuts.size(), fell)
			_t0 = Time.get_ticks_msec()
			_step = 1
		1:
			if Time.get_ticks_msec() - _t0 < 9000:
				return false
			var wood := 0
			var leaves := 0
			for d: ItemDrop in get_nodes_in_group("item_drops"):
				if d.item_id == "wood" or d.item_id == "dead_wood":
					wood += d.count
				if d.item_id == "leaves" or d.item_id == "pine_leaves":
					leaves += d.count
			_check("El tronco revienta en madera para recoger (%d, tronco de %d)" % [wood, _trunk_above], wood >= _trunk_above)
			_check("Las hojas dejan objetos por el suelo (%d)" % leaves, leaves > 0)
			_check("Queda un tocón en el pie", tool.get_voxel(_base) == IslandGenerator.STUMP)
			var regrowth: TreeRegrowth = _main.get_node("TreeRegrowth")
			regrowth.player = null
			regrowth.step(TreeRegrowth.GROW_SECONDS + 1.0)
			var again := tool.get_voxel(_base + Vector3i.UP)
			_check("Pasado el tiempo, el árbol vuelve a crecer", PrefabLibrary.prefab_of(again) == PrefabLibrary.NAMES[_prefab])
			print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
			return true
	return false


## Busca cerca un roble o un pino ya cargado, con hueco a su alrededor para caer.
func _find_tree(tool: VoxelTool, me: Vector3i) -> bool:
	var gen: IslandGenerator = _main.get("_generator")
	for r in range(6, 90):
		for dx in range(-r, r + 1):
			for dz: int in [-r, r]:
				var x := me.x + dx
				var z := me.z + dz
				var kind := gen._tree_kind(x, z)
				if kind == 0 or kind == 3:
					continue
				var prefab := gen._tree_prefab(x, z, kind)
				var name: String = PrefabLibrary.NAMES[prefab]
				if not (name.begins_with("t_oak") or name.begins_with("t_pine")):
					continue
				var base := Vector3i(x, gen._height_at(x, z), z)
				if PrefabLibrary.prefab_of(tool.get_voxel(base + Vector3i.UP)) != name:
					continue  # sin cargar, o lo tapa otro árbol
				_base = base
				_prefab = prefab
				_trunk_above = 0
				for piece in PrefabLibrary.pieces(prefab):
					if (piece[0] as Vector3i).y > 0 and PrefabLibrary.kind(piece[1]) == "wood":
						_trunk_above += 1
				return true
	return false


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1
