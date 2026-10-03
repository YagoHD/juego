extends Node3D
class_name FishSchool
## Peces (modelos del Survival Kit de Kenney, en cubitos) nadando en el agua poco profunda del
## mar cerca del jugador. Van de un sitio a otro sin prisa y huyen si se les acerca alguien. Con
## la lanza en la mano, clic izquierdo apuntando a uno cercano: se pesca (try_spear).

const MAX_FISH := 8
const NEAR := 30.0       # metros: aparecen y desaparecen a esta distancia del jugador
const SPEED := 0.6
const FLEE_SPEED := 2.6

var player: Player
var generator: IslandGenerator
var voxel_size := 0.5
var _fish: Array[Dictionary] = []   # {"node": Node3D, "target": Vector3, "wait": float}
var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _meshes: Array[Mesh] = []


func _ready() -> void:
	_rng.randomize()
	for n in ["fish", "fish_large"]:
		var path := "res://assets/models/voxel/%s.res" % n
		if ResourceLoader.exists(path):
			_meshes.append(load(path))


## Altura de la superficie del mar (metros).
func _sea_y() -> float:
	return IslandGenerator.SEA_LEVEL * voxel_size - 0.1


## ¿Hay aquí mar con algo de fondo (al menos 2 bloques de agua)?
func _is_sea(p: Vector3) -> bool:
	if generator == null:
		return false
	var ground := generator.get_ground_height(int(floorf(p.x / voxel_size)), int(floorf(p.z / voxel_size)))
	return ground <= IslandGenerator.SEA_LEVEL - 2


func _process(delta: float) -> void:
	if player == null or _meshes.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 1.5
		_spawn_some()
	var me := player.global_position
	for f in _fish.duplicate():
		var node: Node3D = f["node"]
		var pos := node.global_position
		if pos.distance_to(me) > NEAR + 8.0:
			node.queue_free()
			_fish.erase(f)
			continue
		var to_player := pos - me
		to_player.y = 0.0
		var speed := SPEED
		var target: Vector3 = f["target"]
		if to_player.length() < 2.8:  # alguien cerca: huye
			target = pos + to_player.normalized() * 4.0
			target.y = pos.y
			speed = FLEE_SPEED
			if not _is_sea(target):
				target = f["target"]
		f["wait"] = float(f["wait"]) - delta
		if pos.distance_to(target) < 0.2 or float(f["wait"]) <= 0.0:
			f["target"] = _random_spot(pos, 4.0)
			f["wait"] = _rng.randf_range(3.0, 7.0)
			continue
		var dir := (target - pos).normalized()
		node.global_position = pos + dir * minf(speed * delta, pos.distance_to(target))
		# Mira hacia donde nada (el modelo apunta a -Z) y se menea un poco.
		var flat := Vector3(dir.x, 0, dir.z)
		if flat.length() > 0.01:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-5.0 * delta))
		node.rotation.z = sin(Time.get_ticks_msec() * 0.012 + node.get_instance_id()) * 0.12


func _spawn_some() -> void:
	if _fish.size() >= MAX_FISH:
		return
	for attempt in 6:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(6.0, NEAR)
		var p := player.global_position + Vector3(cos(a) * r, 0, sin(a) * r)
		if not _is_sea(p):
			continue
		p.y = _sea_y() - _rng.randf_range(0.1, 0.3)  # cerca de la superficie: se ven desde la orilla
		var node := MeshInstance3D.new()
		node.mesh = _meshes[_rng.randi() % _meshes.size()]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		node.global_position = p
		_fish.append({"node": node, "target": _random_spot(p, 4.0), "wait": 5.0})
		return


func _random_spot(around: Vector3, radius: float) -> Vector3:
	for attempt in 5:
		var a := _rng.randf() * TAU
		var p := around + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.0, radius)
		p.y = clampf(around.y + _rng.randf_range(-0.1, 0.1), _sea_y() - 0.35, _sea_y() - 0.08)
		if _is_sea(p):
			return p
	return around


## Lanzazo desde 'from' hacia 'dir': si hay un pez cerca y delante, se pesca. Devuelve true.
func try_spear(from: Vector3, dir: Vector3) -> bool:
	var best: Dictionary = {}
	var best_d := 4.0
	for f in _fish:
		var node: Node3D = f["node"]
		var to := node.global_position - from
		var d := to.length()
		if d < best_d and to.normalized().dot(dir) > 0.86:
			best_d = d
			best = f
	if best.is_empty():
		return false
	(best["node"] as Node3D).queue_free()
	_fish.erase(best)
	return true
