extends SceneTree
## Prueba de las formas de los bloques, sin ventana.
## Uso: godot --headless --path . --script res://tools/test_shapes.gd
## El recuadro de selección sigue la forma de las piezas (no un cubo) y las plantas solo se
## apuntan si el rayo pasa por la planta, no por el hueco de su cubo.

var _main: Node
var _fails := 0


func _init() -> void:
	Main.test_mode = true
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1


func _lines(m: Mesh) -> int:
	return (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 2


func _physics_process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	var cube := _lines(player.get("_cube_outline"))
	var palm := PrefabLibrary.first_id("palm_tall")
	var trunk_lines := _lines(player.call("_shape_outline", palm))
	var bench_lines := _lines(player.call("_shape_outline", IslandGenerator.WORKBENCH))
	print("aristas: cubo %d, trozo de palmera %d, mesa %d" % [cube, trunk_lines, bench_lines])
	_check("El cubo tiene 12 aristas", cube == 12)
	_check("La palmera tiene su propio contorno", trunk_lines > 0 and player.call("_shape_outline", palm) != player.get("_cube_outline"))
	_check("La mesa tiene su propio contorno (muchas aristas)", bench_lines > 30)
	_check("La alfombra es fina", is_equal_approx(Player.shape_box(IslandGenerator.CLOTH).size.y, 1.0 / 16.0))
	_check("Las piedrecitas son bajitas", Player.shape_box(IslandGenerator.PEBBLES).size.y < 0.4)
	# Hierba alta delante: el rayo que pasa por la esquina de su cubo no la coge; el del centro sí.
	var terrain: VoxelTerrain = _main.get("_terrain")
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	var cell := Vector3i((player.global_position / 0.5).floor()) + Vector3i(2, 1, 0)
	for x in range(-1, 4):
		for y in range(0, 3):
			tool.set_voxel(cell + Vector3i(x - 2, y - 1, 0), IslandGenerator.AIR)
	tool.set_voxel(cell, IslandGenerator.TALL_GRASS)
	var center := terrain.to_global(Vector3(cell) + Vector3(0.5, 0.4, 0.5))
	var from := center + Vector3(-1.0, 0.0, 0.0)
	var hit: Dictionary = player.call("_decor_hit", from, (center - from).normalized(), 3.0)
	_check("Apuntando a la hierba se coge", not hit.is_empty())
	var corner := terrain.to_global(Vector3(cell) + Vector3(0.5, 0.97, 0.02))
	var miss: Dictionary = player.call("_decor_hit", corner + Vector3(-1.0, 0, 0), Vector3.RIGHT, 3.0)
	_check("Apuntando al hueco de su cubo, no", miss.is_empty())
	print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
	return true
