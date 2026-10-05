extends Node
class_name WaterFlow
## Agua que corre, como en Minecraft. El agua de ríos y lagos (WATER) es "fuente": no se acaba.
## Al abrirle hueco (romper un bloque al lado, quitar el fondo...) se derrama:
##   - si debajo hay hueco, cae (WATER_FALL, columna entera);
##   - si no, se extiende a los lados perdiendo un nivel por bloque (7, 6... 1) y prefiere ir
##     hacia el hueco más cercano por donde caer (hasta 4 bloques);
##   - el agua que corre sin fuente que la alimente se retira poco a poco;
##   - dos fuentes juntas sobre suelo firme crean una fuente nueva entre ellas.
## Solo se mueve lo que se ha tocado (touch): el agua generada, quieta, no cuesta nada.

const TICK := 0.25            # el agua avanza un paso cada cuarto de segundo (como en Minecraft)
const MAX_PER_TICK := 600     # tope de celdas por paso (si hay más, siguen en el siguiente)
const SEEK := 4               # distancia a la que busca un hueco por donde caer
const HORIZONTAL: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

var terrain: VoxelTerrain
var _tool: WorldVoxels
var _due := {}                # celdas que revisar en el siguiente paso
var _time := 0.0


func _ready() -> void:
	add_to_group("water_flow")


## Algo ha cambiado en 'cell': revisar el agua de ahí y de alrededor.
func touch(cell: Vector3i) -> void:
	_due[cell] = true
	_due[cell + Vector3i.UP] = true
	_due[cell + Vector3i.DOWN] = true
	for d in HORIZONTAL:
		_due[cell + d] = true


func pending() -> int:
	return _due.size()


func _process(delta: float) -> void:
	if terrain == null or _due.is_empty() or get_tree().paused:
		return
	_time += delta
	if _time < TICK:
		return
	_time = 0.0
	step()


## Un paso de la simulación (público para las pruebas).
func step() -> void:
	if _tool == null:
		_tool = WorldVoxels.tool()
		_tool.channel = VoxelBuffer.CHANNEL_TYPE
	var cells: Array = _due.keys()
	_due.clear()
	var done := 0
	for c: Vector3i in cells:
		if done >= MAX_PER_TICK:
			_due[c] = true  # para el siguiente paso
			continue
		done += 1
		_update(c)


# ------------------------------------------------------------------ reglas

static func level_of(id: int) -> int:
	if id == IslandGenerator.WATER or id == IslandGenerator.WATER_FALL:
		return 8
	if id >= IslandGenerator.WATER_FLOW_1 and id < IslandGenerator.WATER_FLOW_1 + 7:
		return id - IslandGenerator.WATER_FLOW_1 + 1
	return 0


static func flow_id(level: int) -> int:
	return IslandGenerator.WATER_FLOW_1 + level - 1


## Huecos que el agua puede ocupar: aire y la hierba, flores, piedrecitas... (se las lleva).
func _open(id: int) -> bool:
	return id == IslandGenerator.AIR or Blocks.DECOR.has(id)


func _vox(c: Vector3i) -> int:
	return _tool.get_voxel(c)


func _put(c: Vector3i, id: int) -> bool:
	if not _tool.is_area_editable(AABB(Vector3(c), Vector3.ONE)):
		return false  # sin cargar: ahí no se toca
	_tool.set_voxel(c, id)
	touch(c)
	return true


func _update(c: Vector3i) -> void:
	var id := _vox(c)
	if not Blocks.is_water(id):
		return
	if id != IslandGenerator.WATER:
		# Agua que corre: ¿qué le toca ser según lo que la alimenta?
		var want := _wanted(c)
		if want != id:
			_put(c, want)
			id = want
			if id == IslandGenerator.AIR:
				return
	_spread(c, id)


## Lo que debería haber en una celda de agua que corre.
func _wanted(c: Vector3i) -> int:
	if Blocks.is_water(_vox(c + Vector3i.UP)):
		return IslandGenerator.WATER_FALL  # le cae agua de arriba
	var best := 0
	var sources := 0
	for d in HORIZONTAL:
		var n := _vox(c + d)
		if n == IslandGenerator.WATER:
			sources += 1
		var lv := level_of(n)
		if n == IslandGenerator.WATER_FALL and _open(_vox(c + d + Vector3i.DOWN)):
			lv = 0  # una cascada en el aire no alimenta de lado
		best = maxi(best, lv - 1)
	var below := _vox(c + Vector3i.DOWN)
	if sources >= 2 and (below == IslandGenerator.WATER or not (_open(below) or Blocks.is_water(below))):
		return IslandGenerator.WATER  # dos fuentes juntas: nueva fuente
	return flow_id(best) if best >= 1 else IslandGenerator.AIR


func _spread(c: Vector3i, id: int) -> void:
	var below := c + Vector3i.DOWN
	var below_id := _vox(below)
	if _open(below_id):
		_put(below, IslandGenerator.WATER_FALL)
		if id != IslandGenerator.WATER:
			return  # el agua que corre, si puede caer, cae y no se extiende
	elif Blocks.is_water(below_id) and below_id != IslandGenerator.WATER and id != IslandGenerator.WATER:
		return  # cae sobre agua que corre: la alimenta por arriba
	var out := level_of(id) - 1
	if out < 1:
		return
	for d in _directions(c):
		var n := c + d
		var nid := _vox(n)
		if _open(nid) or (level_of(nid) < out and nid != IslandGenerator.WATER and nid != IslandGenerator.WATER_FALL):
			_put(n, flow_id(out))


## Hacia dónde se extiende: hacia el hueco más cercano por donde caer; si no hay, a todos lados.
func _directions(c: Vector3i) -> Array[Vector3i]:
	var best := SEEK + 1
	var dirs: Array[Vector3i] = []
	for d in HORIZONTAL:
		for k in range(1, SEEK + 1):
			var p := c + d * k
			var pid := _vox(p)
			if not (_open(pid) or (Blocks.is_water(pid) and pid != IslandGenerator.WATER)):
				break  # pared
			if _open(_vox(p + Vector3i.DOWN)):
				if k < best:
					best = k
					dirs.clear()
				if k == best:
					dirs.append(d)
				break
	return dirs if not dirs.is_empty() else HORIZONTAL
