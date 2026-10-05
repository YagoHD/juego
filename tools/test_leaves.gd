extends SceneTree
## Prueba de cruzar hojas, sin ventana.
## Uso: godot --headless --path . --script res://tools/test_leaves.gd
## Pone un trozo de hojas de árbol a la altura del pecho del jugador y comprueba que lo detecta
## (va más lento, manos delante de la cara), que no choca (se atraviesa) y que al quitarlo vuelve
## a la normalidad.

var _main: Node
var _step := 0
var _frames := 0
var _cell := Vector3i.ZERO
var _fails := 0


func _init() -> void:
	Main.test_mode = true  # mundo de pruebas aparte: nunca toca el mundo guardado del jugador
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	var tool := WorldVoxels.tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	_frames += 1
	match _step:
		0:
			var leaf := -1
			for piece in PrefabLibrary.pieces(PrefabLibrary.index_of("t_oak_1")):
				if PrefabLibrary.kind(piece[1]) == "leaves":
					leaf = piece[1]
					break
			_cell = player.aim.world_to_voxel(player.global_position + Vector3.UP * Player.BODY_HEIGHT * 0.6)
			tool.set_voxel(_cell, leaf)
			_step = 1
			_frames = 0
		1:
			if _frames < 30:
				return false
			_check("Detecta que está entre hojas", player.get("_in_leaves"))
			_check("Va más lento entre hojas", Player.LEAVES_SPEED < 1.0)
			var from: Vector3 = (Vector3(_cell) + Vector3(0.5, 3.0, 0.5)) * Main.VOXEL_SIZE
			var hit := player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.6 * Main.VOXEL_SIZE, 0xFFFFFFFF, [player.get_rid()]))
			_check("Las hojas no chocan (se atraviesan)", hit.is_empty())
			tool.set_voxel(_cell, IslandGenerator.AIR)
			_step = 2
			_frames = 0
		2:
			if _frames < 30:
				return false
			_check("Fuera de las hojas, vuelve a la normalidad", not player.get("_in_leaves"))
			print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
			return true
	return false


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1
