extends Node3D
class_name Wildlife
## Vida de la isla: cangrejos que andan de lado por la arena (se cogen con la mano: clic
## izquierdo apuntando a uno cercano; huyen si te acercas corriendo) y gaviotas que vuelan en
## círculos sobre la costa. Aparecen cerca del jugador y desaparecen al alejarse.

const MAX_CRABS := 6
const MAX_GULLS := 4
const NEAR := 30.0

var player: Player
var generator: IslandGenerator
var voxel_size := 0.5
var _crabs: Array[Dictionary] = []   # {"node", "dir": Vector3, "turn": float}
var _gulls: Array[Dictionary] = []   # {"node", "center": Vector3, "radius", "angle", "speed"}
var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _cry_timer := 8.0


func _ready() -> void:
	_rng.randomize()


## ¿Es arena de playa (cerca del mar) este punto? Devuelve la altura del suelo (m) o -1.
func _sand_height(p: Vector3) -> float:
	if generator == null:
		return -1.0
	var vx := int(floorf(p.x / voxel_size))
	var vz := int(floorf(p.z / voxel_size))
	var h := generator.get_ground_height(vx, vz)
	if h <= IslandGenerator.SEA_LEVEL or h > IslandGenerator.SEA_LEVEL + 7:
		return -1.0
	return h * voxel_size


func _process(delta: float) -> void:
	if player == null:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 2.0
		_spawn_crab()
		_spawn_gull()
	_update_crabs(delta)
	_update_gulls(delta)


# ------------------------------------------------------------------ cangrejos

func _spawn_crab() -> void:
	if _crabs.size() >= MAX_CRABS:
		return
	for attempt in 6:
		var a := _rng.randf() * TAU
		var p := player.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(8.0, NEAR)
		var y := _sand_height(p)
		if y < 0.0:
			continue
		p.y = y
		var node := _crab_model()
		add_child(node)
		node.global_position = p
		_crabs.append({"node": node, "dir": Vector3(cos(a), 0, sin(a)), "turn": 2.0})
		return


func _crab_model() -> Node3D:
	var crab := Node3D.new()
	var shell := Color(0.85, 0.32, 0.18)
	_box(crab, Vector3(0, 0.05, 0), Vector3(0.16, 0.06, 0.12), shell)
	_box(crab, Vector3(0, 0.085, 0), Vector3(0.12, 0.03, 0.09), shell.lightened(0.1))
	for s in [-1.0, 1.0]:
		_box(crab, Vector3(0.11 * s, 0.06, -0.06), Vector3(0.05, 0.04, 0.04), shell.darkened(0.1))  # pinzas
		for k in 3:
			_box(crab, Vector3(0.1 * s, 0.025, -0.03 + k * 0.035), Vector3(0.06, 0.015, 0.012), shell.darkened(0.25))  # patas
	_box(crab, Vector3(-0.03, 0.11, -0.04), Vector3(0.015, 0.03, 0.015), Color(0.1, 0.1, 0.1))  # ojos
	_box(crab, Vector3(0.03, 0.11, -0.04), Vector3(0.015, 0.03, 0.015), Color(0.1, 0.1, 0.1))
	return crab


func _update_crabs(delta: float) -> void:
	var me := player.global_position
	for c in _crabs.duplicate():
		var node: Node3D = c["node"]
		if node.global_position.distance_to(me) > NEAR + 8.0:
			node.queue_free()
			_crabs.erase(c)
			continue
		var dir: Vector3 = c["dir"]
		var speed := 0.35
		var away := node.global_position - me
		away.y = 0.0
		if away.length() < 2.5:  # alguien cerca: huye, deprisa y de lado
			dir = away.normalized()
			speed = 1.4
		c["turn"] = float(c["turn"]) - delta
		if float(c["turn"]) <= 0.0:
			c["turn"] = _rng.randf_range(1.5, 4.0)
			dir = dir.rotated(Vector3.UP, _rng.randf_range(-1.5, 1.5))
		var next := node.global_position + dir * speed * delta
		var y := _sand_height(next)
		if y < 0.0:
			dir = -dir  # se acaba la playa: media vuelta
		else:
			next.y = y
			node.global_position = next
		c["dir"] = dir
		# De lado: mira perpendicular a donde va; un meneo al andar.
		node.rotation.y = atan2(-dir.z, dir.x)
		node.position.y += sin(Time.get_ticks_msec() * 0.03) * 0.002


## Clic izquierdo con la mano: si hay un cangrejo cerca y delante, se coge. Devuelve true.
func try_grab(from: Vector3, dir: Vector3) -> bool:
	for c in _crabs:
		var node: Node3D = c["node"]
		var to := node.global_position + Vector3.UP * 0.05 - from
		if to.length() < 2.6 and to.normalized().dot(dir) > 0.9:
			node.queue_free()
			_crabs.erase(c)
			return true
	return false


# ------------------------------------------------------------------ gaviotas

func _spawn_gull() -> void:
	if _gulls.size() >= MAX_GULLS:
		return
	for attempt in 6:
		var a := _rng.randf() * TAU
		var p := player.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(10.0, NEAR + 10.0)
		if generator.get_ground_height(int(floorf(p.x / voxel_size)), int(floorf(p.z / voxel_size))) > IslandGenerator.SEA_LEVEL + 7:
			continue  # solo sobre la costa o el mar
		var gull := Node3D.new()
		var white := Color(0.95, 0.95, 0.93)
		_box(gull, Vector3.ZERO, Vector3(0.12, 0.08, 0.3), white)
		_box(gull, Vector3(0, 0.03, -0.17), Vector3(0.07, 0.07, 0.08), white)
		_box(gull, Vector3(0, 0.02, -0.23), Vector3(0.03, 0.02, 0.05), Color(0.95, 0.75, 0.2))  # pico
		for s in [-1.0, 1.0]:
			var wing := _box(gull, Vector3(0.22 * s, 0.02, 0), Vector3(0.32, 0.02, 0.13), Color(0.6, 0.62, 0.66))
			wing.name = "wing_l" if s < 0 else "wing_r"
		add_child(gull)
		var center := Vector3(p.x, IslandGenerator.SEA_LEVEL * voxel_size + _rng.randf_range(8.0, 16.0), p.z)
		gull.global_position = center  # ya en su sitio (si no, nace en el origen y se borra por lejana)
		_gulls.append({"node": gull, "center": center, "radius": _rng.randf_range(4.0, 10.0),
			"angle": _rng.randf() * TAU, "speed": _rng.randf_range(0.25, 0.45) * (1.0 if _rng.randf() < 0.5 else -1.0)})
		return


func _update_gulls(delta: float) -> void:
	var me := player.global_position
	var t := Time.get_ticks_msec() * 0.001
	for g in _gulls.duplicate():
		var node: Node3D = g["node"]
		if Vector2(node.global_position.x - me.x, node.global_position.z - me.z).length() > NEAR + 45.0:
			node.queue_free()
			_gulls.erase(g)
			continue
		g["angle"] = float(g["angle"]) + float(g["speed"]) * delta
		var a: float = g["angle"]
		var center: Vector3 = g["center"]
		var r: float = g["radius"]
		node.global_position = center + Vector3(cos(a) * r, sin(t * 0.7 + r) * 0.6, sin(a) * r)
		var tangent := Vector3(-sin(a), 0, cos(a)) * signf(float(g["speed"]))
		node.rotation.y = atan2(-tangent.x, -tangent.z)
		node.rotation.z = -0.25 * signf(float(g["speed"]))  # inclinada en la curva
		var flap := sin(t * 6.0 + r) * 0.4
		(node.get_node("wing_l") as Node3D).rotation.z = flap
		(node.get_node("wing_r") as Node3D).rotation.z = -flap
	_cry_timer -= delta
	if _cry_timer <= 0.0 and not _gulls.is_empty():
		_cry_timer = _rng.randf_range(6.0, 16.0)
		Sfx.play("gaviota", (_gulls[0]["node"] as Node3D).global_position, -4.0, 0.15)


func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	part.material_override = material
	part.position = pos
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part
