extends Node
class_name TreeRegrowth
## Los árboles talados vuelven a crecer: al talar uno por la base queda un tocón (STUMP). Si el
## jugador no lo quita, pasado un rato el árbol rebrota en el mismo sitio y con la misma forma
## (el generador lo vuelve a plantar). Si se rompe el tocón, ahí ya no crece nada. Se guarda.

const GROW_SECONDS := 600.0   # diez minutos de juego
const CLEAR := 3.0            # metros: no rebrota con el jugador encima (lo encerraría)

var terrain: VoxelTerrain
var generator: IslandGenerator
var player: Node3D
var _stumps := {}             # "x,y,z" -> segundos que le quedan
var _check := 0.0


func _ready() -> void:
	add_to_group("tree_regrowth")


## Queda un tocón en 'cell': empieza a contar.
func plant(cell: Vector3i) -> void:
	_stumps["%d,%d,%d" % [cell.x, cell.y, cell.z]] = GROW_SECONDS


func pending() -> int:
	return _stumps.size()


func _process(delta: float) -> void:
	if terrain == null or _stumps.is_empty() or get_tree().paused:
		return
	_check += delta
	if _check < 2.0:
		return
	step(_check)
	_check = 0.0


## Avanza el tiempo 'seconds' (público para las pruebas).
func step(seconds: float) -> void:
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	for key in _stumps.keys():
		var p: PackedStringArray = String(key).split(",")
		var cell := Vector3i(int(p[0]), int(p[1]), int(p[2]))
		if not tool.is_area_editable(AABB(Vector3(cell), Vector3.ONE)):
			continue  # lejos, sin cargar: espera
		if tool.get_voxel(cell) != IslandGenerator.STUMP:
			_stumps.erase(key)  # el jugador quitó el tocón
			continue
		_stumps[key] = float(_stumps[key]) - seconds
		if float(_stumps[key]) > 0.0:
			continue
		if player != null and player.global_position.distance_to(terrain.to_global(Vector3(cell))) < CLEAR:
			continue  # espera a que se aparte
		generator.regrow(tool, cell)
		_stumps.erase(key)


func to_data() -> Dictionary:
	return _stumps.duplicate()


func from_data(data: Dictionary) -> void:
	_stumps.clear()
	for key in data:
		_stumps[str(key)] = float(data[key])
