extends Node3D
## Grano de alba: la única cafeína de la isla. Brota poco, solo en el borde de la zona corrompida
## (la energía de la torre lo alimenta): un motivo para acercarse al peligro. Cada día nuevo brotan
## unos pocos más, sin pasar de un tope; se cosecha al pasar por encima. Figura provisional: un
## tallo con un grano que brilla (el modelo de verdad va en docs/PROMPTS_MESHY.md).
const PER_DAY := 2
const MAX_SPROUTS := 5
const VISIBLE_DISTANCE := 60.0
const PICK_RADIUS := 1.1

var tower: Node3D           # el director de la torre: sabe dónde está la zona corrompida
var player: Player
var day := 0                # último día en que brotaron
var _points: Array = []     # brotes sin cosechar: [x, y, z]
var _nodes: Dictionary = {} # índice del punto -> figura en el mundo
var _rng := RandomNumberGenerator.new()
var _check := 0.0


## Llamar al cambiar de día (y al cargar): brotan los de los días que falten.
func grow_until(today: int) -> void:
	if tower == null or tower.center == Vector3.ZERO:
		return
	_rng.seed = hash(today) ^ 0x5eed
	while day < today:
		day += 1
		for i in PER_DAY:
			if _points.size() >= MAX_SPROUTS:
				break
			# El borde: lo más lejos del centro que sigue siendo suelo corrompido, en un ángulo al azar.
			var point: Vector3 = tower.affected_point(_rng.randf() * TAU, _rng.randf_range(24.0, 48.0))
			if point.distance_to(tower.center) > 8.0:
				_points.append([point.x, point.y, point.z])


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not player.is_on_ground_ready():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.2
	for i in range(_points.size() - 1, -1, -1):
		var at := Vector3(float(_points[i][0]), float(_points[i][1]), float(_points[i][2]))
		var distance := player.global_position.distance_to(at)
		if distance < PICK_RADIUS and player.can_pick_up("dawn_bean"):
			player.pick_up("dawn_bean", 1)
			Sfx.play("recoger", null, -6.0, 0.15)
			player.notice.emit("Has cogido un grano de alba: brilla un poco y se puede comer.")
			_points.remove_at(i)
			_rebuild()
			return
		if distance < VISIBLE_DISTANCE and not _nodes.has(i):
			_nodes[i] = _make_sprout(at)


func _rebuild() -> void:
	for node in _nodes.values():
		node.queue_free()
	_nodes.clear()


func _make_sprout(at: Vector3) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.012
	stem_mesh.bottom_radius = 0.02
	stem_mesh.height = 0.35
	stem.mesh = stem_mesh
	stem.position.y = 0.175
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.35, 0.45, 0.2)
	stem.material_override = green
	root.add_child(stem)
	var bean := MeshInstance3D.new()
	var bean_mesh := SphereMesh.new()
	bean_mesh.radius = 0.05
	bean_mesh.height = 0.08
	bean.mesh = bean_mesh
	bean.position.y = 0.37
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.72, 0.3)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.6, 0.2)
	glow.emission_energy_multiplier = 1.5
	bean.material_override = glow
	root.add_child(bean)
	return root


func to_data() -> Dictionary:
	return {"day": day, "points": _points.duplicate(true)}


func from_data(data: Dictionary) -> void:
	day = int(data.get("day", 0))
	_points = []
	for p in data.get("points", []):
		if p is Array and p.size() == 3:
			_points.append(p)
	_rebuild()
