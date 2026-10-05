extends RefCounted
class_name WorldVoxels
## Los bloques del mundo, vistos como uno solo aunque estén en dos terrenos:
##   - el del suelo (todo lo que no son árboles), con mucha distancia de detalle;
##   - el de los árboles detallados, con menos distancia (más allá se ven los árboles sencillos de
##     FarTrees): los árboles son casi todo lo que cuesta dibujar.
## Se usa como una VoxelTool (get_voxel, set_voxel, is_area_editable): leer un bloque mira primero
## el de los árboles; escribir pone las piezas de árbol en el suyo y lo demás en el del suelo
## (quitando lo que hubiera en el otro).

static var _instance: WorldVoxels

var channel := VoxelBuffer.CHANNEL_TYPE   # (como en VoxelTool; aquí siempre el de tipo)
var ground: VoxelTerrain
var trees: VoxelTerrain                   # null si no hay mundo de árboles (sala de muestras)
var _ground_tool: VoxelTool
var _trees_tool: VoxelTool


## Prepara el mundo doble. Lo llama main.gd al crear los terrenos.
static func setup(ground_terrain: VoxelTerrain, trees_terrain: VoxelTerrain) -> void:
	var w := WorldVoxels.new()
	w.ground = ground_terrain
	w.trees = trees_terrain
	w._ground_tool = ground_terrain.get_voxel_tool()
	w._ground_tool.channel = VoxelBuffer.CHANNEL_TYPE
	if trees_terrain != null:
		w._trees_tool = trees_terrain.get_voxel_tool()
		w._trees_tool.channel = VoxelBuffer.CHANNEL_TYPE
	_instance = w


## La herramienta para leer y escribir bloques (o null antes de crear el mundo).
static func tool() -> WorldVoxels:
	return _instance


## ¿Es una pieza de los árboles detallados (va en su propio terreno)?
static func is_tree_piece(id: int) -> bool:
	return PrefabLibrary.is_prefab(id) and PrefabLibrary.prefab_of(id).begins_with("t_")


func get_voxel(cell: Vector3i) -> int:
	if _trees_tool != null:
		var t := _trees_tool.get_voxel(cell)
		if t != IslandGenerator.AIR:
			return t
	return _ground_tool.get_voxel(cell)


func set_voxel(cell: Vector3i, id: int) -> void:
	if _trees_tool != null and is_tree_piece(id):
		_trees_tool.set_voxel(cell, id)
		if _ground_tool.get_voxel(cell) != IslandGenerator.AIR:
			_ground_tool.set_voxel(cell, IslandGenerator.AIR)
		return
	_ground_tool.set_voxel(cell, id)
	if _trees_tool != null and _trees_tool.get_voxel(cell) != IslandGenerator.AIR:
		_trees_tool.set_voxel(cell, IslandGenerator.AIR)


func is_area_editable(box: AABB) -> bool:
	return _ground_tool.is_area_editable(box)


## La herramienta del terreno de los árboles (para hacer rebrotar uno entero de golpe).
func trees_tool() -> VoxelTool:
	return _trees_tool if _trees_tool != null else _ground_tool
