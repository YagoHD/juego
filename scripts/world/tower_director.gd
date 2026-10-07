extends Node3D
## Progresión por días, población persistente y puntos de caminos registrados por el mapa.
signal phase_changed(phase: int)
signal boss_defeated
const SquadScript = preload("res://scripts/creatures/enemy_squad.gd")
const REINFORCEMENTS := {
	1: ["tracker", "tracker", "tracker", "tracker"],
	2: ["archer", "archer"],
	3: ["captain", "soldier", "mage", "archer", "soldier", "tracker", "soldier", "archer", "captain", "mage", "soldier", "tracker"],
	4: ["captain", "soldier", "mage", "archer", "tracker", "soldier", "archer", "tracker", "captain", "soldier", "mage", "archer", "tracker", "soldier", "tracker", "tower_guardian"],
}
var player: Player
var clock: DayNight
var generator: IslandGenerator
var voxel_size := 0.5
var center := Vector3.ZERO
var phase := 0
var first_day := 1
var guardian_defeated := false
var _records: Dictionary = {}
var _actors: Dictionary = {}
var _groups: Dictionary = {}
var _routes: Dictionary = {}
var _roads: Dictionary = {}
var _geometry: Node3D
var _check := 0.0

func configure(p: Player, time: DayNight, gen: IslandGenerator) -> void:
	player = p
	clock = time
	generator = gen
	center = _find_center()

func _find_center() -> Vector3:
	var samples: Array[Vector2i] = []
	var average := Vector2.ZERO
	for z in range(-480, 481, 16):
		for x in range(-480, 481, 16):
			var i := generator._index(x, z)
			if i >= 0 and generator.get_surface_map()[i * 3] == IslandGenerator.CORRUPT_SOIL:
				var point := Vector2i(x, z)
				samples.append(point)
				average += Vector2(point)
	if samples.is_empty():
		return Vector3.ZERO  # sin región corrupta: no despliega encuentros
	average /= samples.size()
	var best := samples[0]
	for sample in samples:
		if Vector2(sample).distance_squared_to(average) < Vector2(best).distance_squared_to(average):
			best = sample
	var ground := generator.get_ground_height(best.x, best.y) * voxel_size
	return Vector3(best.x * voxel_size, ground + 0.1, best.y * voxel_size)

func ground_point(x: float, z: float) -> Vector3:
	if generator == null:
		return Vector3(x, center.y, z)
	return Vector3(x, generator.get_ground_height(roundi(x / voxel_size), roundi(z / voxel_size)) * voxel_size + 0.1, z)

func affected_point(angle: float, radius: float) -> Vector3:
	while radius >= 6.0:
		var point := ground_point(center.x + cos(angle) * radius, center.z + sin(angle) * radius)
		if generator == null:
			return point
		var i := generator._index(roundi(point.x / voxel_size), roundi(point.z / voxel_size))
		if i >= 0 and generator.get_surface_map()[i * 3] == IslandGenerator.CORRUPT_SOIL:
			return point
		radius -= 3.0
	return center

func advance_to_day(day: int) -> void:
	if center == Vector3.ZERO and generator != null:
		return
	var desired := clampi(day - first_day + 1, 1, 4)
	while phase < desired:
		phase += 1
		_add_phase(phase)
		phase_changed.emit(phase)
	_build_geometry()

func _add_phase(stage: int) -> void:
	var roster: Array = REINFORCEMENTS[stage]
	var radius: float = [12.0, 20.0, 32.0, 55.0][stage - 1]
	for index in roster.size():
		var id := "%d_%d" % [stage, index]
		var species := str(roster[index])
		var angle := (index / 4) * TAU / ceilf(roster.size() / 4.0) + stage * 0.7
		var point := affected_point(angle, radius)
		point = ground_point(point.x + ((index % 4) % 2) * 1.2, point.z + ((index % 4) / 2) * 1.2)
		var group_id := "stage_%d_%d" % [stage, index / 4]
		if species == "tower_guardian":
			point = center + Vector3.UP * 0.25
			group_id = ""
		_records[id] = {"species": species, "position": _vec(point), "home": _vec(point), "health": CreatureDB.profile(species)["hp"], "dead": false, "group": group_id}
		if group_id != "" and not _routes.has(group_id):
			var route: Array = []
			for step in (4 if stage >= 3 else 2):
				var a := angle + step * 0.35
				route.append(_vec(affected_point(a, radius)))
			_routes[group_id] = {"points": route, "rest_duration": 5.0, "waypoint": 0, "direction": 1}

func register_road(id: String, points: Array[Vector3]) -> void:
	# El editor del mapa puede registrar A/B/C/D cuando se construyan caminos reales.
	if points.size() < 2 or _roads.has(id):
		return
	var data: Array = []
	for point in points:
		data.append(_vec(point))
	_roads[id] = data
	if phase == 4:
		_add_road_patrol(id)

func _add_road_patrol(id: String) -> void:
	var group_id := "road_" + id
	if _routes.has(group_id):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	# Solo algunas rutas tienen patrulla; decisión estable al guardar/cargar.
	if rng.randf() > 0.4:
		return
	_routes[group_id] = {"points": _roads[id], "rest_duration": 6.0, "waypoint": 0, "direction": 1}
	for index in 3:
		var species: String = ["tracker", "archer", "soldier"][index]
		_records[group_id + str(index)] = {"species": species, "position": _roads[id][0], "home": _roads[id][0], "health": CreatureDB.profile(species)["hp"], "dead": false, "group": group_id}

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not player.is_on_ground_ready():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.3
	if clock != null:
		var desired := clampi(clock.day - first_day + 1, 1, 4)
		if desired > phase:
			advance_to_day(clock.day)
	if phase == 4:
		for road_id in _roads:
			_add_road_patrol(road_id)
	for id in _records:
		var record: Dictionary = _records[id]
		if record["dead"]:
			continue
		var point := _point(record["position"])
		if not _actors.has(id) and player.global_position.distance_to(point) < 65.0:
			_spawn(id)
		if not _actors.has(id) or not is_instance_valid(_actors[id]):
			continue
		var actor: CreatureActor = _actors[id]
		actor.hour = clock.hour if clock != null else 12.0
		var near := player.global_position.distance_to(actor.global_position) < 22.0
		var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP, actor.global_position + Vector3.DOWN * 2.0, 1)
		ray.exclude = [actor.get_rid(), player.get_rid()]
		var ready := near and not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		actor.set_physics_process(ready)

func _spawn(id: String) -> void:
	var record: Dictionary = _records[id]
	var actor := CreatureActor.new()
	actor.species = record["species"]
	actor.player = player
	add_child(actor)
	actor.global_position = _point(record["position"])
	actor.home = _point(record["home"])
	actor.health = clampf(float(record["health"]), 1.0, float(actor.stats["hp"]))
	actor.alert_seconds = float(record.get("alert", 0.0))
	if actor.species == "tower_guardian":
		actor.stats["leash"] = 6.0
	actor.set_physics_process(false)
	_actors[id] = actor
	var group_id := str(record["group"])
	if group_id != "":
		if not _groups.has(group_id) or not is_instance_valid(_groups[group_id]):
			var group = SquadScript.new()
			group.from_data(_routes[group_id])
			add_child(group)
			_groups[group_id] = group
		_groups[group_id].add_member(actor)
	actor.died.connect(func(_actor: CreatureActor) -> void:
		_records[id]["dead"] = true
		if actor.species == "tower_guardian":
			guardian_defeated = true
			boss_defeated.emit())

func _build_geometry() -> void:
	if _geometry != null:
		_geometry.free()
	_geometry = Node3D.new()
	_geometry.name = "TowerAndCamp"
	add_child(_geometry)
	var height: float = [3.0, 8.0, 15.0, 24.0][maxi(phase - 1, 0)]
	var color := Color(0.22, 0.19, 0.3)
	# Torre hueca accesible por entrada sur, con suelo y coronación provisionales.
	_box(center + Vector3(0, -0.25, 0), Vector3(10, 0.5, 10), color)
	for x in [-5.0, 5.0]:
		_box(center + Vector3(x, height * 0.5, 0), Vector3(0.6, height, 10), color)
	_box(center + Vector3(0, height * 0.5, -5), Vector3(10, height, 0.6), color)
	for x in [-3.5, 3.5]:
		_box(center + Vector3(x, height * 0.5, 5), Vector3(3, height, 0.6), color)
	if phase >= 2:
		var tents := 2 if phase == 2 else (6 if phase == 3 else 12)
		for i in tents:
			var angle := i * TAU / tents
			var point := ground_point(center.x + cos(angle) * 18, center.z + sin(angle) * 18)
			_box(point + Vector3(0, 1, 0), Vector3(2.4, 2, 0.3), Color(0.48, 0.3, 0.2))
			_box(point + Vector3(0, 2, 0.8), Vector3(2.6, 0.25, 2), Color(0.55, 0.35, 0.24))
	if phase == 4:
		_box(center + Vector3(0, height, 0), Vector3(10.6, 0.6, 10.6), color)

func _box(at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	body.add_child(visual)
	_geometry.add_child(body)

func to_data() -> Dictionary:
	for id in _actors:
		if not is_instance_valid(_actors[id]):
			continue
		var actor: CreatureActor = _actors[id]
		if is_instance_valid(actor) and not actor.dead:
			_records[id]["position"] = _vec(actor.global_position)
			_records[id]["health"] = actor.health
			_records[id]["alert"] = actor.alert_seconds
	for id in _groups:
		if is_instance_valid(_groups[id]):
			_routes[id] = _groups[id].to_data()
	return {"phase": phase, "first_day": first_day, "center": _vec(center), "records": _records.duplicate(true), "routes": _routes.duplicate(true), "roads": _roads.duplicate(true), "boss_defeated": guardian_defeated}

func from_data(data: Dictionary) -> void:
	phase = clampi(int(data.get("phase", 0)), 0, 4)
	first_day = maxi(1, int(data.get("first_day", 1)))
	if data.has("center"):
		center = _point(data["center"])
	_records = data.get("records", {}).duplicate(true)
	_routes = data.get("routes", {}).duplicate(true)
	_roads = data.get("roads", {}).duplicate(true)
	guardian_defeated = bool(data.get("boss_defeated", false))

static func _vec(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

static func _point(data: Array) -> Vector3:
	return Vector3(float(data[0]), float(data[1]), float(data[2]))
