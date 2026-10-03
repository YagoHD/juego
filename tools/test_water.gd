extends SceneTree
## Prueba del agua que corre, sin ventana.
## Uso: godot --headless --path . --script res://tools/test_water.gd
## En el aire, sobre una losa de piedra de 15x15: una fuente en el centro se extiende perdiendo
## nivel, cae por los bordes; al quitar la fuente, el agua se retira. Y la corriente de los ríos.

var _main: Node
var _fails := 0
var _phase := 0


func _init() -> void:
	Main.test_mode = true
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1


func _physics_process(_delta: float) -> bool:
	var player: Player = _main.get("_player")
	if player == null or _main.get("_loading") or not player.is_on_ground_ready():
		return false
	var terrain: VoxelTerrain = _main.get("_terrain")
	var flow: WaterFlow = _main.get_node("WaterFlow")
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	var base := Vector3i((player.global_position / 0.5).floor()) + Vector3i(0, 14, 0)
	# Losa de piedra de 15x15 y aire encima.
	for x in range(-7, 8):
		for z in range(-7, 8):
			tool.set_voxel(base + Vector3i(x, 0, z), IslandGenerator.STONE)
			for y in range(1, 4):
				tool.set_voxel(base + Vector3i(x, y, z), IslandGenerator.AIR)
	var src := base + Vector3i.UP
	tool.set_voxel(src, IslandGenerator.WATER)
	flow.touch(src)
	for i in 30:
		flow.step()
	var l1 := WaterFlow.level_of(tool.get_voxel(src + Vector3i(1, 0, 0)))
	var l3 := WaterFlow.level_of(tool.get_voxel(src + Vector3i(0, 0, -3)))
	var l7 := WaterFlow.level_of(tool.get_voxel(src + Vector3i(7, 0, 0)))
	var beyond := tool.get_voxel(src + Vector3i(7, 0, 7))
	print("niveles: al lado %d, a 3 %d, a 7 %d" % [l1, l3, l7])
	_check("Se extiende perdiendo nivel (7 al lado, 5 a tres bloques)", l1 == 7 and l3 == 5)
	_check("A siete bloques de la fuente ya no llega", l7 == 1 or l7 == 0)
	_check("La esquina lejana sigue seca", beyond == IslandGenerator.AIR)
	# Quitar la fuente: el agua se retira.
	tool.set_voxel(src, IslandGenerator.AIR)
	flow.touch(src)
	for i in 40:
		flow.step()
	var left := 0
	for x in range(-7, 8):
		for z in range(-7, 8):
			if Blocks.is_water(tool.get_voxel(base + Vector3i(x, 1, z))):
				left += 1
	_check("Sin fuente, el agua se retira (quedan %d)" % left, left == 0)
	# Cascada: fuente al borde de la losa, cae hacia abajo.
	var edge := base + Vector3i(7, 1, 0)
	tool.set_voxel(edge, IslandGenerator.WATER)
	flow.touch(edge)
	for i in 10:
		flow.step()
	_check("Al borde, el agua cae por fuera", tool.get_voxel(edge + Vector3i(1, -1, 0)) == IslandGenerator.WATER_FALL)
	# Dos fuentes con un hueco entre ellas: se crea otra.
	var a := base + Vector3i(-1, 1, -1)
	tool.set_voxel(a, IslandGenerator.WATER)
	tool.set_voxel(a + Vector3i(2, 0, 0), IslandGenerator.WATER)
	flow.touch(a)
	flow.touch(a + Vector3i(2, 0, 0))
	for i in 6:
		flow.step()
	_check("Dos fuentes juntas crean otra entre ellas", tool.get_voxel(a + Vector3i(1, 0, 0)) == IslandGenerator.WATER)
	# Corriente de los ríos.
	var gen: IslandGenerator = _main.get("_generator")
	var moving := 0
	var n := gen.map_pixels()
	for k in 4000:
		var wx := int(randf_range(-IslandGenerator.MAP_HALF, IslandGenerator.MAP_HALF))
		var wz := int(randf_range(-IslandGenerator.MAP_HALF, IslandGenerator.MAP_HALF))
		if gen.water_current(wx, wz).length() > 0.2:
			moving += 1
	print("mapa %d px; columnas con corriente: %d de 4000" % [n, moving])
	_check("Los ríos tienen corriente", moving > 0)
	print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
	return true
