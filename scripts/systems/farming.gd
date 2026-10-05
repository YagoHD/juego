extends Node
class_name Farming
## Agricultura: con semillas en la mano, clic derecho sobre hierba o tierra planta trigo
## (Kenney Nature Kit, en cubitos). Pasado un rato madura; maduro da trigo y semillas. El trigo,
## asado en la hoguera, es una torta de pan. Lo plantado se guarda.

const GROW_SECONDS := 240.0   # de brote a maduro (tiempo real jugando)

var terrain: VoxelTerrain
var _growing := {}            # "x,y,z" -> segundos que le quedan
var _check := 0.0


## ¿Se puede plantar encima de este bloque?
static func can_plant_on(block_id: int) -> bool:
	return block_id in [IslandGenerator.GRASS, IslandGenerator.GRASS_FLOWERS, IslandGenerator.DIRT]


## Planta en 'cell' (el hueco encima del suelo). Devuelve false si no se puede.
func plant(cell: Vector3i) -> bool:
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	if tool.get_voxel(cell) != IslandGenerator.AIR or not can_plant_on(tool.get_voxel(cell - Vector3i.UP)):
		return false
	tool.set_voxel(cell, PrefabLibrary.first_id("wheat_a"))
	_growing["%d,%d,%d" % [cell.x, cell.y, cell.z]] = GROW_SECONDS
	return true


func _process(delta: float) -> void:
	if terrain == null or _growing.is_empty() or get_tree().paused:
		return
	_check += delta
	if _check < 2.0:
		return
	var step := _check
	_check = 0.0
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	var young := PrefabLibrary.first_id("wheat_a")
	for key in _growing.keys():
		_growing[key] = float(_growing[key]) - step
		if float(_growing[key]) > 0.0:
			continue
		var p: PackedStringArray = String(key).split(",")
		var cell := Vector3i(int(p[0]), int(p[1]), int(p[2]))
		if tool.get_voxel(cell) == young:
			tool.set_voxel(cell, PrefabLibrary.first_id("wheat_b"))
		_growing.erase(key)


func to_data() -> Dictionary:
	return _growing.duplicate()


func from_data(data: Dictionary) -> void:
	_growing.clear()
	for key in data:
		_growing[str(key)] = float(data[key])
