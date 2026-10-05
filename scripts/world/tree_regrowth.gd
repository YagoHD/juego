extends Node
class_name TreeRegrowth
## Los árboles talados vuelven a crecer: al talar uno por la base queda un tocón (STUMP). Si el
## jugador no lo quita, a los GROW_DAYS días de juego el árbol rebrota en el mismo sitio y con la misma forma
## (el generador lo vuelve a plantar). Si se rompe el tocón, ahí ya no crece nada. Se guarda.

const GROW_DAYS := 2.0
const GROW_SECONDS := GROW_DAYS * DayNight.CYCLE_MINUTES * 60.0  # segundos de juego (2 días)
const CLEAR := 3.0            # metros: no rebrota con el jugador encima (lo encerraría)

var terrain: VoxelTerrain
var generator: IslandGenerator   # el que planta los árboles (TreeGenerator si van aparte)
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
	_check += delta * (DayNight.FAST_FORWARD if Input.is_key_pressed(KEY_T) else 1.0)  # T adelanta el reloj
	if _check < 2.0:
		return
	step(_check)
	_check = 0.0


## Avanza el tiempo 'seconds' (público para las pruebas).
func step(seconds: float) -> void:
	var tool := WorldVoxels.tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	for key in _stumps.keys():
		var p: PackedStringArray = String(key).split(",")
		var cell := Vector3i(int(p[0]), int(p[1]), int(p[2]))
		_stumps[key] = float(_stumps[key]) - seconds  # el tiempo pasa aunque estés lejos
		if not tool.is_area_editable(AABB(Vector3(cell), Vector3.ONE)):
			continue  # lejos, sin cargar: crece cuando vuelvas
		if tool.get_voxel(cell) != IslandGenerator.STUMP:
			_stumps.erase(key)  # el jugador quitó el tocón
			continue
		if float(_stumps[key]) > 0.0:
			continue
		if player != null and player.global_position.distance_to(terrain.to_global(Vector3(cell))) < CLEAR:
			continue  # espera a que se aparte
		tool.set_voxel(cell, IslandGenerator.AIR)  # el tocón (en el suelo) deja sitio al tronco
		generator.regrow(tool.trees_tool(), cell)  # el árbol, en el terreno de los árboles
		_stumps.erase(key)


func to_data() -> Dictionary:
	return _stumps.duplicate()


func from_data(data: Dictionary) -> void:
	_stumps.clear()
	for key in data:
		_stumps[str(key)] = float(data[key])
