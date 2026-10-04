extends RigidBody3D
class_name TreeFelling
## Talar árboles con física de verdad. Al romper un bloque de tronco, si lo de encima ya no se
## sostiene:
##   1. Se buscan los troncos conectados por encima del corte (y sus ramas) y las hojas de su copa.
##      Si siguen unidos a algo por debajo del corte (otro trozo de un tronco de 2x2), no cae nada.
##   2. Se quitan del mundo y aparece un cuerpo rígido con la misma forma (una caja de choque por
##      bloque, las hojas más ligeras que la madera). Recibe un empujón alejándose de quien tala,
##      con algo de azar en la dirección, la fuerza y el giro: cada árbol cae a su manera, rebota,
##      rueda un poco o se queda apoyado en una cuesta.
##   3. Al primer golpe contra el suelo, las hojas se rompen: trocitos y algunas hojas como
##      objetos esparcidos.
##   4. Cuando el tronco, ya tumbado, golpea el suelo, revienta: saltan astillas y la madera queda
##      en el suelo como objetos para recoger. Donde estaba, queda un tocón que rebrota (TreeRegrowth).
## Para que un muro de troncos construido no "caiga como un árbol", el tronco normal necesita
## hojas en su copa (los árboles muertos no tienen).

const WOODS := [IslandGenerator.WOOD, IslandGenerator.DEAD_WOOD]
const LEAF_IDS := [IslandGenerator.LEAVES, IslandGenerator.PINE_LEAVES]
const MAX_BLOCKS := 700
const CROWN_REACH := 6           # hojas a más columnas del corte no son de este árbol
const LEAF_DROP_CHANCE := 0.35   # cuántas hojas quedan como objeto al romperse
const PHYSICS_LAYER := 1 << 3    # capa propia: choca con el terreno, no con el jugador
const MAX_TIME := 10.0           # pase lo que pase, a los 10 s revienta

var _terrain: VoxelTerrain
var _tool: VoxelTool
var _vs := 0.5                   # metros por bloque
var _woods := {}                 # Vector3i -> id
var _leaves := {}                # Vector3i -> id
var _cut := Vector3i.ZERO
var _origin := Vector3.ZERO      # en bloques: base del primer bloque de tronco (origen del cuerpo)
var _leaf_nodes: Array[Node] = []
var _leaves_broken := false
var _hit := false                # el cuerpo tocó algo (lo avisa la física)
var _touching := false           # está tocando algo ahora mismo
var _age := 0.0
var _still := 0.0
var _done := false
var _push := Vector3.ZERO       # empujón guardado hasta que se suelta
var _push_at := Vector3.ZERO
var _spin := 0.0
var _tip_speed := 0.8
var _tip_axis := Vector3.ZERO
const WAIT := 0.35               # s quieto al principio: el terreno tiene que quitar su choque viejo


## Tronco: el de los árboles normales, el seco y las piezas de tronco de las palmeras.
static func _is_wood(id: int) -> bool:
	return WOODS.has(id) or (PrefabLibrary.is_prefab(id) and PrefabLibrary.kind(id) == "wood")


static func _is_leaf(id: int) -> bool:
	return LEAF_IDS.has(id) or (PrefabLibrary.is_prefab(id) and PrefabLibrary.kind(id) == "leaves")


## Se llama al romper un bloque. Devuelve true si el árbol empieza a caer.
static func try_fell(parent: Node, terrain: VoxelTerrain, cut: Vector3i, cut_id: int, from: Vector3) -> bool:
	if not _is_wood(cut_id):
		return false
	var tool := terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	var tree := TreeFelling.new()
	tree._terrain = terrain
	tree._tool = tool
	tree._vs = terrain.scale.x
	tree._cut = cut
	if not tree._collect(cut):
		tree.free()
		return false
	tree._leave_stump(cut)
	parent.add_child(tree)
	tree._start(from)
	return true

## Talado por la base (debajo del corte ya no hay tronco): ahí queda un tocón, del que el árbol
## volverá a crecer si nadie lo quita (TreeRegrowth). Solo donde el generador planta un árbol.
func _leave_stump(cut: Vector3i) -> void:
	var gen := _terrain.generator as IslandGenerator
	if gen == null or _is_wood(_tool.get_voxel(cut + Vector3i.DOWN)):
		return  # cortado a media altura: el resto del tronco sigue en pie
	# El pie del árbol: el centro del tronco, que puede estar a un par de bloques del último corte
	# (los troncos gruesos ocupan 3x3 o 5x5 bloques y se talan cortando todo su ancho).
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var d := Vector3i(dx, 0, dz)
			var c: Vector3i = cut + d
			if gen.has_tree(c.x, c.z) and _tool.get_voxel(c) == IslandGenerator.AIR:
				_tool.set_voxel(c, IslandGenerator.STUMP)
				_terrain.get_tree().call_group("tree_regrowth", "plant", c)
				return


# ------------------------------------------------------------------ qué cae

func _collect(cut: Vector3i) -> bool:
	# Troncos: desde los que tocan el corte por encima (también en diagonal, para las ramas).
	var stack: Array[Vector3i] = []
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var c := cut + Vector3i(dx, 1, dz)
			if _is_wood(_tool.get_voxel(c)):
				stack.append(c)
	if stack.is_empty():
		return false
	var dead_only := true
	while not stack.is_empty():
		var c: Vector3i = stack.pop_back()
		if _woods.has(c):
			continue
		var id := _tool.get_voxel(c)
		if not _is_wood(id):
			continue
		if c.y <= cut.y:
			return false  # sigue unido a algo por debajo del corte: se sostiene
		_woods[c] = id
		if id != IslandGenerator.DEAD_WOOD and not PrefabLibrary.is_dead(id):
			dead_only = false
		if _woods.size() > MAX_BLOCKS:
			return false
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if dx != 0 or dy != 0 or dz != 0:
						stack.append(c + Vector3i(dx, dy, dz))
	# Hojas: las que tocan los troncos y las que se tocan entre sí (la copa).
	var dirs := [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]
	var lstack: Array[Vector3i] = []
	for c: Vector3i in _woods:
		for d: Vector3i in dirs:
			lstack.append(c + d)
	while not lstack.is_empty():
		var c: Vector3i = lstack.pop_back()
		if _leaves.has(c) or _woods.has(c):
			continue
		if c.y < cut.y or maxi(absi(c.x - cut.x), absi(c.z - cut.z)) > CROWN_REACH:
			continue
		var id := _tool.get_voxel(c)
		if not _is_leaf(id):
			continue
		_leaves[c] = id
		if _leaves.size() > MAX_BLOCKS:
			break
		for d: Vector3i in dirs:
			lstack.append(c + d)
	return dead_only or _leaves.size() >= 3


# ------------------------------------------------------------------ empezar a caer

func _start(from: Vector3) -> void:
	# El cuerpo nace justo encima del corte, con cada bloque como una caja de choque.
	_origin = Vector3(_cut.x + 0.5, _cut.y + 1, _cut.z + 0.5)
	global_position = _origin * _vs
	collision_layer = PHYSICS_LAYER
	collision_mask = 1  # el terreno
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = true
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var dead := _woods.values().all(func(w: int) -> bool: return w == IslandGenerator.DEAD_WOOD or PrefabLibrary.is_dead(w))
	# Peso: la madera pesa y las hojas poco; los muertos, secos, pesan menos.
	mass = _woods.size() * (12.0 if dead else 20.0) + _leaves.size() * 1.5
	var friction := PhysicsMaterial.new()
	friction.friction = 0.9
	friction.bounce = 0.08 + rng.randf() * 0.1
	physics_material_override = friction
	angular_damp = 0.6
	linear_damp = 0.1

	for c: Vector3i in _woods:
		_add_box(c, 1.0)
	for c: Vector3i in _leaves:
		_leaf_nodes.append(_add_box(c, 0.9))
	var wood_view := _build_blocks(_woods)
	add_child(wood_view)
	var leaf_view := _build_blocks(_leaves)
	add_child(leaf_view)
	_leaf_nodes.append(leaf_view)

	# Quitar del mundo lo que ahora es el cuerpo.
	for c: Vector3i in _woods:
		_tool.set_voxel(c, IslandGenerator.AIR)
	for c: Vector3i in _leaves:
		_tool.set_voxel(c, IslandGenerator.AIR)

	# Empujón: lejos de quien tala, con algo de azar; arriba más que abajo (así vuelca).
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.RIGHT
	away = away.normalized().rotated(Vector3.UP, rng.randf_range(-0.45, 0.45))
	var height := 1.0
	for c: Vector3i in _woods:
		height = maxf(height, c.y - _cut.y)
	var strength := rng.randf_range(0.6, 1.4) * mass
	_push = away * strength * 0.35
	_push_at = Vector3.UP * height * _vs * 0.8
	_spin = rng.randf_range(-0.6, 0.6)  # un poco de giro sobre sí mismo
	_tip_speed = rng.randf_range(0.5, 1.1)
	# Quieto un instante (el crujido): si se suelta ya, nace metido en el choque viejo del propio
	# árbol (el terreno tarda unos fotogramas en rehacerlo) y la física lo lanza por los aires.
	freeze = true
	Sfx.play("cofre", global_position, 3.0, 0.15)  # crujido del tronco


## Caja de choque de un bloque (scale < 1: algo más pequeña, para las hojas).
func _add_box(c: Vector3i, scale_k: float) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * _vs * scale_k
	shape.shape = box
	shape.position = _local(c) * _vs
	add_child(shape)
	return shape


## Centro de un bloque respecto al origen del cuerpo (en bloques).
func _local(c: Vector3i) -> Vector3:
	return Vector3(c) + Vector3.ONE * 0.5 - _origin


## Un MultiMesh por tipo de bloque, cada bloque en su sitio dentro del cuerpo.
func _build_blocks(cells: Dictionary) -> Node3D:
	var holder := Node3D.new()
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
		var shaped := PrefabLibrary.is_prefab(id)  # pieza de palmera: su propia forma
		mm.mesh = PrefabLibrary.centered_mesh(id, _vs) if shaped else BlockTextures.make_block_mesh(id, _vs)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, Transform3D(Basis(), _local(list[i]) * _vs))
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.material_override = PrefabLibrary.material() if shaped else BlockTextures.make_material()
		holder.add_child(inst)
	return holder


# ------------------------------------------------------------------ mientras cae

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_touching = state.get_contact_count() > 0
	if state.get_contact_count() > 0:
		_hit = true


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if freeze:
		if _age >= WAIT:
			freeze = false
			apply_impulse(_push, _push_at)
			# Vuelco: empieza a inclinarse hacia donde se le empuja; el peso de la copa hace el resto.
			var tip := Vector3.UP.cross(_push.normalized()).normalized()
			_tip_axis = tip
			angular_velocity = tip * _tip_speed + Vector3.UP * _spin
		return
	# Si se queda enganchado de pie (entre las copas vecinas), se sigue venciendo hacia su lado.
	if _age < WAIT + 4.0 and _tilt() < 0.35 and _tip_axis != Vector3.ZERO:
		apply_torque(_tip_axis * mass * 3.0)
		_still = 0.0
	# Golpe contra el suelo con la copa: las hojas se rompen.
	if not _leaves_broken and _hit and _age > 0.25 and (_tilt() > 0.6 or _age > 2.5):
		_break_leaves()
	# El tronco ya tumbado golpea el suelo: revienta en objetos.
	if _leaves_broken and _touching and _tilt() > 0.8 and _age > WAIT + 0.3:
		_shatter()
		return
	# Quieto un rato (enganchado en una cuesta, o demasiado tiempo cayendo): también revienta.
	var moving := linear_velocity.length() > 0.15 or angular_velocity.length() > 0.2
	_still = 0.0 if moving else _still + delta
	if (_still > 0.6 and _age > WAIT + 1.0 and (_tilt() >= 0.35 or _age > WAIT + 4.0)) or _age > MAX_TIME or global_position.y < -60.0:
		_shatter()


## Cuánto se ha inclinado (0 de pie, 1 tumbado).
func _tilt() -> float:
	return 1.0 - absf(global_basis.y.normalized().y)


func _break_leaves() -> void:
	_leaves_broken = true
	if _leaves.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var dropped := 0
	var center := Vector3.ZERO
	for c: Vector3i in _leaves:
		var p := global_transform * (_local(c) * _vs)
		center += p
		if rng.randf() < LEAF_DROP_CHANCE and dropped < 40:
			dropped += 1
			ItemDrop.spawn(get_parent(), p + Vector3.UP * 0.3, _leaf_item(_leaves[c]), 1)
	center /= _leaves.size()
	# Los pinos sueltan resina al caer.
	if _leaves.values().any(func(l: int) -> bool: return l == IslandGenerator.PINE_LEAVES or PrefabLibrary.is_pine(l)):
		for k in rng.randi_range(1, 3):
			ItemDrop.spawn(get_parent(), global_transform * (Vector3(0, 1.5, 0) * _vs) + Vector3.UP * 0.4, "resin", 1)
	for node in _leaf_nodes:
		node.queue_free()
	_leaf_nodes.clear()
	# Sin las hojas, el centro de masas es el del tronco.
	mass = maxf(_woods.size() * 15.0, 1.0)
	_burst_leaves(center)
	Sfx.play("romper_tela", center, 0.0, 0.15)  # susurro de las hojas


# ------------------------------------------------------------------ contra el suelo: revienta

const MAX_DROPS := 12            # objetos sueltos como mucho (los troncos se agrupan en montones)


## El tronco golpea el suelo y revienta: astillas, y la madera queda en el suelo como objetos
## para recoger (un tronco por bloque, en montones repartidos a lo largo de donde cayó).
func _shatter() -> void:
	_done = true
	freeze = true
	if not _leaves_broken:
		_break_leaves()
	var counts := {}   # objeto -> cuántos
	var spots: Array[Vector3] = []
	var center := Vector3.ZERO
	for c: Vector3i in _woods:
		var item := _leaf_item(_woods[c])
		counts[item] = int(counts.get(item, 0)) + 1
		var p := global_transform * (_local(c) * _vs)
		spots.append(p)
		center += p
	center /= maxf(_woods.size(), 1)
	# Montones repartidos por el tronco caído.
	var piles := mini(MAX_DROPS, _woods.size())
	var k := 0
	for item: String in counts:
		var left: int = counts[item]
		while left > 0:
			var amount := maxi(1, ceili(float(counts[item]) / piles))
			amount = mini(amount, left)
			var at: Vector3 = spots[(k * 7) % spots.size()]
			ItemDrop.spawn(get_parent(), _above_ground(at) + Vector3.UP * 0.4, item, amount)
			left -= amount
			k += 1
	_burst_chips(center, spots)
	Sfx.play("romper_arena", center, 2.0, 0.1)  # golpe sordo contra el suelo
	queue_free()


## Astillas de madera que saltan a lo largo del tronco.
func _burst_chips(center: Vector3, spots: Array[Vector3]) -> void:
	var length := 0.5
	for p in spots:
		length = maxf(length, p.distance_to(center))
	var particles := CPUParticles3D.new()
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * 0.07
	var material := StandardMaterial3D.new()
	var first: int = _woods.values()[0]
	material.albedo_color = Blocks.color_of(first)
	material.roughness = 1.0
	chunk.material = material
	particles.mesh = chunk
	particles.amount = mini(120, 20 + _woods.size() * 6)
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = length
	particles.direction = Vector3.UP
	particles.spread = 70.0
	particles.gravity = Vector3(0, -12.0, 0)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	particles.angular_velocity_min = -400.0
	particles.angular_velocity_max = 400.0
	get_parent().add_child(particles)
	particles.global_position = center
	particles.emitting = true
	get_tree().create_timer(1.6).timeout.connect(particles.queue_free)


func _burst_leaves(at: Vector3) -> void:
	var particles := CPUParticles3D.new()
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE * 0.08
	chunk.material = Blocks.make_material(IslandGenerator.LEAVES)
	particles.mesh = chunk
	particles.amount = mini(90, 12 + _leaves.size())
	particles.lifetime = 1.1
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(1.3, 0.5, 1.3)
	particles.direction = Vector3.UP
	particles.spread = 80.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 3.0
	get_parent().add_child(particles)
	particles.global_position = at
	particles.emitting = true
	get_tree().create_timer(1.8).timeout.connect(particles.queue_free)


static func _leaf_item(id: int) -> String:
	return PrefabLibrary.tree_item(id) if PrefabLibrary.is_prefab(id) else ItemDB.drop_of(id)



## El punto, subido hasta el primer hueco si ha quedado dentro del suelo (un tronco que cae medio
## enterrado en una cuesta): si no, el objeto nacería dentro del terreno y lo atravesaría.
func _above_ground(p: Vector3) -> Vector3:
	var cell := Vector3i((p / _vs).floor())
	for i in 8:
		var id := _tool.get_voxel(cell)
		if id == IslandGenerator.AIR or Blocks.is_decor(id) or Blocks.is_water(id):
			break
		cell.y += 1
	return Vector3(p.x, maxf(p.y, cell.y * _vs + 0.05), p.z)
