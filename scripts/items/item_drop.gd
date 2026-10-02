extends Node3D
class_name ItemDrop
## Objeto tirado en el suelo: un cubito con la textura del objeto que salta al aparecer, cae
## hasta apoyarse, gira y flota un poco. Al acercarse el jugador vuela hacia él y se mete en su
## inventario. Los montones iguales que caen juntos se fusionan. Desaparece a los LIFETIME s.

const SIZE := 0.22
const GRAVITY := 18.0
const PICKUP_DELAY := 0.5   # s antes de poder recogerlo (para que se vea saltar)
const PICKUP_RADIUS := 0.9  # m
const MAGNET_RADIUS := 2.5  # m: a esta distancia vuela hacia el jugador
const MERGE_RADIUS := 0.8   # m
const LIFETIME := 300.0

var item_id := ""
var count := 1

var _velocity := Vector3.ZERO
var _age := 0.0
var _resting := false
var _visual: MeshInstance3D


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
	var block := ItemDB.block_of(item_id)
	_visual.mesh = BlockTextures.make_block_mesh(block, SIZE)
	_visual.material_override = BlockTextures.make_material(block == IslandGenerator.WATER)
	_visual.position.y = SIZE * 0.5
	add_child(_visual)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return

	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and _age > PICKUP_DELAY:
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
	_visual.position.y = SIZE * 0.5 + 0.06 + sin(_age * 2.5) * 0.05


func _ray(from: Vector3, motion: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + motion)
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if player != null:
		query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _give_to(player: Player) -> void:
	var left := player.pick_up(item_id, count)
	if left <= 0:
		queue_free()
	else:
		count = left


func _merge_nearby() -> void:
	for other in get_tree().get_nodes_in_group("item_drops"):
		var drop := other as ItemDrop
		if drop == self or drop == null or drop.is_queued_for_deletion() or drop.item_id != item_id:
			continue
		if drop.global_position.distance_to(global_position) < MERGE_RADIUS \
				and count + drop.count <= ItemDB.max_stack(item_id):
			count += drop.count
			drop.queue_free()
