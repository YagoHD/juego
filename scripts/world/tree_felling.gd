extends Node3D
class_name TreeFelling
## Talar árboles: al romper un bloque de tronco, si lo de encima ya no se sostiene, el árbol cae.
##   1. Se buscan los troncos conectados por encima del corte (y sus ramas) y las hojas de su copa.
##      Si esos troncos siguen unidos a algo por debajo del corte (otro trozo de un tronco de
##      2x2, por ejemplo), no cae nada.
##   2. Se quitan del mundo y se dibuja el árbol como una pieza que gira desde el corte hacia el
##      lado contrario al jugador, cada vez más rápido, hasta quedar tumbado.
##   3. Al chocar, las hojas se rompen: unas cuantas quedan como objetos esparcidos por el suelo.
##      El tronco cae hasta apoyarse y se queda entero, tumbado, como bloques que hay que romper.
## Para que un muro de troncos construido no "caiga como un árbol", el tronco normal necesita
## hojas en su copa (los árboles muertos no tienen).

const WOODS := [IslandGenerator.WOOD, IslandGenerator.DEAD_WOOD]
const LEAF_IDS := [IslandGenerator.LEAVES, IslandGenerator.PINE_LEAVES]
const MAX_BLOCKS := 700
const CROWN_REACH := 6           # hojas a más columnas del corte no son de este árbol
const FALL_TIME := 1.5           # segundos en caer (si es alto, algo más)
const LEAF_DROP_CHANCE := 0.35   # cuántas hojas quedan como objeto al romperse

var _terrain: VoxelTerrain
var _tool: VoxelTool
var _vs := 0.5                   # metros por bloque
var _woods := {}                 # Vector3i -> id
var _leaves := {}                # Vector3i -> id
var _pivot := Vector3.ZERO       # en bloques: arista sobre la que gira
var _axis := Vector3.RIGHT
var _dir := Vector3i(1, 0, 0)    # hacia dónde cae
var _t := 0.0
var _fall_time := FALL_TIME
var _phase := 0                  # 0 cayendo, 1 bajando hasta apoyarse, 2 terminado
var _drop := 0.0
var _drop_left := 0.0
var _visual: Node3D
var _leaf_visual: Node3D


## Se llama al romper un bloque. Devuelve true si el árbol empieza a caer.
static func try_fell(parent: Node, terrain: VoxelTerrain, cut: Vector3i, cut_id: int, from: Vector3) -> bool:
	if not WOODS.has(cut_id):
		return false
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	var tree := TreeFelling.new()
	tree._terrain = terrain
	tree._tool = tool
	tree._vs = terrain.scale.x
	if not tree._collect(cut):
		tree.free()
		return false
	parent.add_child(tree)
	tree._start(cut, from)
	return true


# ------------------------------------------------------------------ qué cae

func _collect(cut: Vector3i) -> bool:
	# Troncos: desde los que tocan el corte por encima (también en diagonal, para las ramas).
	var stack: Array[Vector3i] = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var c := cut + Vector3i(dx, 1, dz)
			if WOODS.has(_tool.get_voxel(c)):
				stack.append(c)
	if stack.is_empty():
		return false
	var dead_only := true
	while not stack.is_empty():
		var c: Vector3i = stack.pop_back()
		if _woods.has(c):
			continue
		var id := _tool.get_voxel(c)
		if not WOODS.has(id):
			continue
		if c.y <= cut.y:
			return false  # sigue unido a algo por debajo del corte: se sostiene
		_woods[c] = id
		if id == IslandGenerator.WOOD:
			dead_only = false
		if _woods.size() > MAX_BLOCKS:
			return false
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if dx != 0 or dy != 0 or dz != 0:
						stack.append(c + Vector3i(dx, dy, dz))
	# Hojas: las que tocan los troncos y las que se tocan entre sí (la copa).
	var lstack: Array[Vector3i] = []
	for c: Vector3i in _woods:
		for d in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			lstack.append(c + d)
	while not lstack.is_empty():
		var c: Vector3i = lstack.pop_back()
		if _leaves.has(c) or _woods.has(c):
			continue
		if c.y < cut.y or maxi(absi(c.x - cut.x), absi(c.z - cut.z)) > CROWN_REACH:
			continue
		var id := _tool.get_voxel(c)
		if not LEAF_IDS.has(id):
			continue
		_leaves[c] = id
		if _leaves.size() > MAX_BLOCKS:
			break
		for d in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			lstack.append(c + d)
	return dead_only or _leaves.size() >= 3


# ------------------------------------------------------------------ la caída

func _start(cut: Vector3i, from: Vector3) -> void:
	# Cae hacia el lado contrario a quien lo tala, en una de las 4 direcciones (así, tumbado,
	# encaja en la cuadrícula de bloques).
	var away := Vector3(cut) * _vs + Vector3.ONE * _vs * 0.5 - from
	away.y = 0.0
	if absf(away.x) > absf(away.z):
		_dir = Vector3i(int(signf(away.x)) if away.x != 0.0 else 1, 0, 0)
	else:
		_dir = Vector3i(0, 0, int(signf(away.z)) if away.z != 0.0 else 1)
	# Gira sobre la arista de abajo del corte, en el lado hacia el que cae.
	_pivot = Vector3(cut.x + 0.5 + _dir.x * 0.5, cut.y, cut.z + 0.5 + _dir.z * 0.5)
	_axis = Vector3.UP.cross(Vector3(_dir)).normalized()
	var height := 0
	for c: Vector3i in _woods:
		height = maxi(height, c.y - cut.y)
	_fall_time = FALL_TIME + height * 0.04

	# Fuera del mundo y, en su lugar, una copia que se mueve.
	for c: Vector3i in _woods:
		_tool.set_voxel(c, IslandGenerator.AIR)
	for c: Vector3i in _leaves:
		_tool.set_voxel(c, IslandGenerator.AIR)
	position = _pivot * _vs
	_visual = Node3D.new()
	add_child(_visual)
	_leaf_visual = Node3D.new()
	_visual.add_child(_leaf_visual)
	_build_blocks(_visual, _woods)
	_build_blocks(_leaf_visual, _leaves)
	Sfx.play("cofre", position, 2.0, 0.1)  # crujido


## Un MultiMesh por tipo de bloque, con cada bloque en su sitio respecto a la arista de giro.
func _build_blocks(holder: Node3D, cells: Dictionary) -> void:
	var by_id := {}
	for c: Vector3i in cells:
		var id: int = cells[c]
		if not by_id.has(id):
			by_id[id] = []
		by_id[id].append(c)
	for id: int in by_id:
		var list: Array = by_id[id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = BlockTextures.make_block_mesh(id, _vs)
		mm.instance_count = list.size()
		for i in list.size():
			var c: Vector3i = list[i]
			var center := (Vector3(c) + Vector3.ONE * 0.5 - _pivot) * _vs
			mm.set_instance_transform(i, Transform3D(Basis(), center))
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.material_override = BlockTextures.make_material()
		holder.add_child(inst)


func _process(delta: float) -> void:
	match _phase:
		0:
			_t += delta
			var k := clampf(_t / _fall_time, 0.0, 1.0)
			_visual.basis = Basis(_axis, PI * 0.5 * k * k)  # cada vez más rápido, como al caer
			if k >= 1.0:
				_land()
		1:
			var step := minf(_drop_left, delta * 6.0)
			_drop_left -= step
			_visual.position.y -= step * _vs
			if _drop_left <= 0.0:
				_settle()


## Toca el suelo: las hojas se rompen y el tronco baja hasta apoyarse.
func _land() -> void:
	_phase = 1
	var rot := Basis(_axis, PI * 0.5)
	# Hojas: trocitos y algunas como objeto, esparcidas donde cayeron.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var dropped := 0
	for c: Vector3i in _leaves:
		var p := _pivot + rot * (Vector3(c) + Vector3.ONE * 0.5 - _pivot)
		if rng.randf() < LEAF_DROP_CHANCE and dropped < 40:
			dropped += 1
			ItemDrop.spawn(get_parent(), p * _vs + Vector3.UP * 0.3, ItemDB.drop_of(_leaves[c]), 1)
	_leaf_visual.queue_free()
	_burst_leaves(rot)
	Sfx.play("romper_hierba", position, 4.0, 0.1)
	Sfx.play("romper_madera", position, 2.0, 0.05)
	# Tronco: cuántos bloques puede bajar hasta que alguno toque algo sólido.
	_drop = 99.0
	for c: Vector3i in _woods:
		var p := _landed_cell(c, rot)
		var free := 0
		while free < 12 and _tool.get_voxel(p - Vector3i(0, free + 1, 0)) == IslandGenerator.AIR:
			free += 1
		_drop = minf(_drop, free)
	if _drop >= 12.0:
		_drop = 0.0
	_drop_left = _drop


## Celda del mundo donde queda un bloque de tronco ya tumbado (antes de bajar).
func _landed_cell(c: Vector3i, rot: Basis) -> Vector3i:
	var p := _pivot + rot * (Vector3(c) + Vector3.ONE * 0.5 - _pivot)
	return Vector3i(p.floor())


## Ya apoyado: el tronco vuelve a ser bloques del mundo, tumbados y enteros.
func _settle() -> void:
	_phase = 2
	var rot := Basis(_axis, PI * 0.5)
	for c: Vector3i in _woods:
		var p := _landed_cell(c, rot) - Vector3i(0, int(_drop), 0)
		if _tool.get_voxel(p) == IslandGenerator.AIR:
			_tool.set_voxel(p, _woods[c])
		else:  # el sitio está ocupado: ese trozo cae como objeto
			ItemDrop.spawn(get_parent(), (Vector3(p) + Vector3.ONE * 0.5) * _vs + Vector3.UP * 0.4, ItemDB.drop_of(_woods[c]), 1)
	Sfx.play("colocar", position, 3.0, 0.05)
	queue_free()


func _burst_leaves(rot: Basis) -> void:
	var particles := CPUParticles3D.new()
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * 0.08
	chunk.material = Blocks.make_material(IslandGenerator.LEAVES)
	particles.mesh = chunk
	particles.amount = mini(80, 10 + _leaves.size())
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var length := 0.0
	for c: Vector3i in _leaves:
		length = maxf(length, (Vector3(c) - _pivot).length())
	particles.emission_box_extents = Vector3(1.2, 0.4, 1.2)
	particles.direction = Vector3.UP
	particles.spread = 80.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 3.0
	get_parent().add_child(particles)
	particles.global_position = (_pivot + rot * Vector3(0, length * 0.7, 0)) * _vs
	particles.emitting = true
	get_tree().create_timer(1.6).timeout.connect(particles.queue_free)
