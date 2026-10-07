extends Node3D
class_name ItemDrop
## Objeto tirado en el suelo: un cubito con la textura del objeto que salta al aparecer, cae
## hasta apoyarse, gira y flota un poco (en el agua, sube a la superficie y flota; en los ríos, la
## corriente lo arrastra). Al acercarse el jugador vuela hacia él y se mete en su
## inventario. Los montones iguales que caen juntos se fusionan. Desaparece a los LIFETIME s.

const SIZE := 0.22
const GRAVITY := 18.0
const PICKUP_DELAY := 0.5   # s antes de poder recogerlo (para que se vea saltar)
const PICKUP_RADIUS := 0.9  # m
const MAGNET_RADIUS := 2.5  # m: a esta distancia vuela hacia el jugador
const MERGE_RADIUS := 0.8   # m
const LIFETIME := 300.0
const FLOAT_RISE := 1.6     # m/s: sube a la superficie del agua
const DRIFT := 0.7          # m/s con la corriente más fuerte de un río


var item_id := ""
var count := 1
var metadata: Dictionary = {}  # desgaste/datos del montón tirado desde el inventario

var _velocity := Vector3.ZERO
var _age := 0.0
var pickup_delay := PICKUP_DELAY  # al tirarlo con Q es mayor, para que no vuelva enseguida
var _resting := false
var _visual: MeshInstance3D
var _base_y := 0.0
var _tool: WorldVoxels
var _terrain: VoxelTerrain


## Crea un objeto en el suelo en 'pos' con un pequeño salto en dirección aleatoria.
static func spawn(parent: Node, pos: Vector3, id: String, amount: int) -> ItemDrop:
	var drop := ItemDrop.new()
	drop.item_id = id
	drop.count = amount
	parent.add_child(drop)
	drop.global_position = pos
	var a := randf() * TAU
	drop._velocity = Vector3(cos(a) * 1.2, 3.5, sin(a) * 1.2)
	return drop


func _ready() -> void:
	add_to_group("item_drops")
	_visual = MeshInstance3D.new()
	_visual.mesh = ItemMesh.make(item_id, SIZE if ItemDB.block_of(item_id) >= 0 else SIZE * 1.6)
	_visual.material_override = ItemMesh.make_material(item_id)
	_base_y = -_visual.mesh.get_aabb().position.y  # apoyado en el suelo
	_visual.position.y = _base_y
	add_child(_visual)


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return  # ya se juntó con otro montón: no debe tragarse más (se perderían)
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return

	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not player.ui_open and _age > pickup_delay:
		var target := player.global_position + Vector3.UP * 0.6
		var to_player := target - global_position
		if to_player.length() < PICKUP_RADIUS:
			_give_to(player)
			return
		if to_player.length() < MAGNET_RADIUS and player.can_pick_up(item_id):
			# Vuela hacia el jugador, cada vez más deprisa.
			global_position += to_player.normalized() * minf(to_player.length(), (6.0 + 10.0 * _age) * delta)
			_resting = false
			_spin(delta)
			return

	_unbury()
	if _float(delta):
		_spin(delta)
		return
	if not _resting:
		_velocity.y -= GRAVITY * delta
		var motion := _velocity * delta
		var hit := _ray(global_position + Vector3.UP * 0.05, motion + Vector3.DOWN * 0.05)
		if not hit.is_empty() and _velocity.y <= 0.0:
			global_position = (hit["position"] as Vector3)
			_velocity = Vector3.ZERO
			_resting = true
			_merge_nearby()
		else:
			global_position += motion
		if global_position.y < -50.0:
			queue_free()
			return
	elif _ray(global_position + Vector3.UP * 0.05, Vector3.DOWN * 0.15).is_empty():
		_resting = false  # le han quitado el suelo de debajo: vuelve a caer
	_spin(delta)


func _spin(delta: float) -> void:
	_visual.rotation.y += delta * 1.6
	_visual.position.y = _base_y + 0.06 + sin(_age * 2.5) * 0.05


func _ray(from: Vector3, motion: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + motion)
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if player != null:
		query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _give_to(player: Player) -> void:
	var left: int
	if metadata.is_empty():
		left = player.pick_up(item_id, count)
	else:
		var stack := metadata.duplicate(true)
		stack["id"] = item_id
		stack["count"] = count
		left = player.inventory.add_stack(stack, player.unlocked_slots())
	if left < count:
		Sfx.play("recoger", null, -8.0, 0.15)
	if left <= 0:
		queue_free()
	else:
		count = left


func _merge_nearby() -> void:
	for other in get_tree().get_nodes_in_group("item_drops"):
		var drop := other as ItemDrop
		if drop == self or drop == null or drop.is_queued_for_deletion() or drop.item_id != item_id or drop.metadata != metadata:
			continue
		if drop.global_position.distance_to(global_position) < MERGE_RADIUS \
				and count + drop.count <= ItemDB.max_stack(item_id):
			count += drop.count
			drop.queue_free()


## Lanzar un objeto (tecla Q): sale disparado hacia donde se mira y tarda en poder recogerse.
static func throw(parent: Node, pos: Vector3, direction: Vector3, id: String, amount: int) -> ItemDrop:
	var drop := spawn(parent, pos, id, amount)
	drop._velocity = direction * 4.5 + Vector3.UP * 1.5
	drop.pickup_delay = 2.0
	return drop


static func throw_stack(parent: Node, pos: Vector3, direction: Vector3, stack: Dictionary) -> ItemDrop:
	var drop := throw(parent, pos, direction, str(stack["id"]), int(stack["count"]))
	drop.metadata = stack.duplicate(true)
	drop.metadata.erase("id")
	drop.metadata.erase("count")
	return drop


## Si ha quedado metido dentro de algo sólido (salió disparado contra una cuesta o un tronco), se
## sube al primer hueco de encima: desde dentro, el rayo no ve el suelo y lo atravesaría.
func _unbury() -> void:
	if not _setup_tool():
		return
	var cell := Vector3i(_terrain.to_local(global_position + Vector3.UP * 0.01).floor())
	if _free(_tool.get_voxel(cell)):
		return
	for i in 8:
		cell.y += 1
		if _free(_tool.get_voxel(cell)):
			global_position.y = _terrain.to_global(Vector3(cell)).y
			_velocity = Vector3.ZERO
			_resting = false
			return


## En el agua (ríos, lagos o el mar): sube hasta la superficie, se mece y la corriente lo arrastra.
## Devuelve true si está flotando.
func _float(delta: float) -> bool:
	if not _setup_tool():
		return false
	var surface := _water_surface()
	if surface == -INF or global_position.y > surface + 0.1:
		return false
	_resting = false
	_velocity.x = move_toward(_velocity.x, 0.0, delta * 3.0)
	_velocity.z = move_toward(_velocity.z, 0.0, delta * 3.0)
	_velocity.y = 0.0
	var gen := _terrain.generator as IslandGenerator
	if gen != null:
		var cell := Vector3i(_terrain.to_local(global_position).floor())
		var current := gen.water_current(cell.x, cell.z) * DRIFT
		_velocity.x += current.x * delta * 3.0
		_velocity.z += current.y * delta * 3.0
	global_position.x += _velocity.x * delta
	global_position.z += _velocity.z * delta
	var bob := sin(_age * 2.0) * 0.03
	global_position.y = move_toward(global_position.y, surface - 0.08 + bob, FLOAT_RISE * delta)
	return true


## Altura de la superficie del agua en la que está (o -INF si no está en el agua).
func _water_surface() -> float:
	var vs := _terrain.scale.x
	var cell := Vector3i(_terrain.to_local(global_position).floor())
	if Blocks.is_water(_tool.get_voxel(cell)):
		while Blocks.is_water(_tool.get_voxel(cell + Vector3i.UP)) and cell.y < 512:
			cell.y += 1
		var level := WaterFlow.level_of(_tool.get_voxel(cell))
		return (cell.y + (1.0 if level >= 8 else level / 8.0)) * vs
	# El mar es un plano: bajo él, donde el fondo está por debajo del nivel del mar.
	var sea := IslandGenerator.SEA_LEVEL * vs - 0.08
	var gen := _terrain.generator as IslandGenerator
	if global_position.y < sea + 0.05 and gen != null and gen.get_ground_height(cell.x, cell.z) < IslandGenerator.SEA_LEVEL:
		return sea
	return -INF


func _setup_tool() -> bool:
	if _tool != null:
		return true
	_terrain = get_tree().get_first_node_in_group("voxel_terrain") as VoxelTerrain
	if _terrain == null:
		return false
	_tool = WorldVoxels.tool()
	_tool.channel = VoxelBuffer.CHANNEL_TYPE
	return true


static func _free(id: int) -> bool:
	return id == IslandGenerator.AIR or Blocks.is_decor(id) or Blocks.is_water(id)
