extends Node3D
## Progresión por días, población persistente y puntos de caminos registrados por el mapa.
signal phase_changed(phase: int)
signal boss_defeated
const SquadScript = preload("res://scripts/creatures/enemy_squad.gd")
const SproutsScript = preload("res://scripts/world/dawn_sprouts.gd")
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
var sprouts: Node3D   # grano de alba en el borde de la corrupción
const SPAWN_DISTANCE := 65.0
var _fires := {}            # id del campamento -> EnemyFire
var _fires_out := {}        # id del campamento -> día en que se apagó
var _vigilant_until := -1.0 # hora absoluta (día*24+hora) hasta la que el campamento está en guardia
const DESPAWN_DISTANCE := 95.0

func configure(p: Player, time: DayNight, gen: IslandGenerator) -> void:
	player = p
	clock = time
	generator = gen
	center = _find_center()
	sprouts = SproutsScript.new()
	sprouts.name = "DawnSprouts"
	sprouts.tower = self
	sprouts.player = p
	add_child(sprouts)

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
	if sprouts != null:
		sprouts.grow_until(day)

func _add_phase(stage: int) -> void:
	# Puestos con sentido (Garrison): torres de vigía, campamentos, ritual, puerta, patrullas.
	var index := 0
	for post: Dictionary in Garrison.posts_for(stage, self):
		var roster: Array = post["roster"]
		var group_id := ""
		if post["kind"] == "patrol":
			group_id = str(post["id"])
			var route: Array = []
			for point: Vector3 in post["route"]:
				route.append(_vec(point))
			_routes[group_id] = {"points": route, "rest_duration": 5.0, "waypoint": 0, "direction": 1}
		for member in roster.size():
			var species := str(roster[member])
			var role := _role(post, member)
			var point: Vector3 = role.get("point", post["point"])
			if post["kind"] == "patrol":
				point = ground_point(point.x + (member % 2) * 1.2, point.z + (member / 2) * 1.2)
			var id := "%d_%d" % [stage, index]
			index += 1
			_records[id] = {"species": species, "position": _vec(point), "home": _vec(point),
				"health": CreatureDB.profile(species)["hp"], "dead": false, "group": group_id,
				"post": _post_data(role)}


## Qué hace en su puesto el miembro 'member' (CreatureActor.post): vigía quieto mirando hacia fuera,
## descanso en el campamento, ritual junto a la torre o trabajo entre las cajas.
func _role(post: Dictionary, member: int) -> Dictionary:
	var spots: Array = post["spots"]
	var spot: Vector3 = spots[member % spots.size()] if not spots.is_empty() else post["point"]
	match str(post["kind"]):
		"watchtower":
			return {"role": "sentry", "point": spot, "facing": post["facing"], "hold": true}
		"gate":
			return {"role": "sentry", "point": spot, "facing": post["facing"]}
		"camp":
			return {"role": "camp", "point": spot, "focus": post["point"], "spots": spots}
		"ritual":
			return {"role": "ritual", "point": spot, "focus": post["point"], "spots": spots}
		"workers":
			return {"role": "worker", "point": spot, "spots": spots}
		"boss":
			return {"point": post["point"]}
	return {}


static func _post_data(role: Dictionary) -> Dictionary:
	if not role.has("role"):
		return {}
	var data := {"role": role["role"], "point": _vec(role["point"]), "facing": float(role.get("facing", 0.0)),
		"hold": bool(role.get("hold", false))}
	if role.has("focus"):
		data["focus"] = _vec(role["focus"])
	var spots: Array = []
	for spot: Vector3 in role.get("spots", []):
		spots.append(_vec(spot))
	data["spots"] = spots
	return data


static func _post_from(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var post := {"role": str(data["role"]), "point": _point(data["point"]), "facing": float(data.get("facing", 0.0)),
		"hold": bool(data.get("hold", false))}
	if data.has("focus"):
		post["focus"] = _point(data["focus"])
	var spots: Array[Vector3] = []
	for spot in data.get("spots", []):
		spots.append(_point(spot))
	post["spots"] = spots
	return post

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
		elif sprouts != null and sprouts.day < clock.day:
			sprouts.grow_until(clock.day)
	if clock != null:
		for camp in _fires_out.keys():
			if clock.day > int(_fires_out[camp]):
				_fires_out.erase(camp)
				if _fires.has(camp) and is_instance_valid(_fires[camp]):
					(_fires[camp] as EnemyFire).relight_if(clock.day)
	if phase == 4:
		for road_id in _roads:
			_add_road_patrol(road_id)
	for id in _records:
		var record: Dictionary = _records[id]
		if record["dead"]:
			continue
		var point := _point(record["position"])
		if not _actors.has(id) and player.global_position.distance_to(point) < SPAWN_DISTANCE:
			_spawn(id)
		if not _actors.has(id) or not is_instance_valid(_actors[id]):
			continue
		var actor: CreatureActor = _actors[id]
		# Muy lejos y tranquilo: se guarda su ficha y se quita de la escena (cientos de enemigos sin
		# que pese: solo existen los cercanos).
		if player.global_position.distance_to(actor.global_position) > DESPAWN_DISTANCE \
				and actor.state not in ["chase", "search", "windup", "charge", "channel", "flee"]:
			record["position"] = _vec(actor.global_position)
			record["health"] = actor.health
			record["alert"] = actor.alert_seconds
			actor.queue_free()
			_actors.erase(id)
			continue
		actor.hour = clock.hour if clock != null else 12.0
		var near := player.global_position.distance_to(actor.global_position) < 22.0
		var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP, actor.global_position + Vector3.DOWN * 2.0, 1)
		ray.exclude = [actor.get_rid(), player.get_rid()]
		var ready := near and not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		actor.set_physics_process(ready)

func _spawn(id: String) -> void:
	if _actors.has(id) and is_instance_valid(_actors[id]):
		return  # ya está en la escena
	var record: Dictionary = _records[id]
	var actor := CreatureActor.new()
	actor.species = record["species"]
	actor.player = player
	# Antes de add_child: _ready toma la posición como casa y destino (si no, irían al origen).
	actor.position = _point(record["position"])
	actor.post = _post_from(record.get("post", {}))
	add_child(actor)
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
		_check_patrol_lost(str(_records[id]["group"]))
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
	# Pista: la base de la torre brilla con el mismo morado que la piedra de la mina.
	_geometry.add_child(ClueModels.make("torre_brillo", "glow_crack", center + Vector3(-2.2, 0.6, 5.35),
		"La piedra de la base tiene grietas que brillan morado, igual que el polvo del joyero."))
	for stage in range(1, phase + 1):
		for post: Dictionary in Garrison.posts_for(stage, self):
			_build_post(post)
	if phase == 4:
		_box(center + Vector3(0, height, 0), Vector3(10.6, 0.6, 10.6), color)

## Lo que se ve de cada puesto (provisional, de cajas): torre de vigía, tiendas y hoguera, piedras
## del ritual, cajas de los trabajadores.
func _build_post(post: Dictionary) -> void:
	var p: Vector3 = post["point"]
	var wood := Color(0.42, 0.28, 0.16)
	match str(post["kind"]):
		"watchtower":
			var h := Garrison.WATCH_HEIGHT
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				_box(p + Vector3(corner.x * 1.1, h * 0.5 - 0.15, corner.y * 1.1), Vector3(0.3, h - 0.3, 0.3), wood)
			_box(p + Vector3(0, h - 0.15, 0), Vector3(2.8, 0.3, 2.8), wood.lightened(0.1))  # suelo del puesto
			for side in [Vector3(1.35, 0, 0), Vector3(-1.35, 0, 0), Vector3(0, 0, 1.35), Vector3(0, 0, -1.35)]:
				var size := Vector3(0.15, 0.6, 2.8) if side.x != 0.0 else Vector3(2.8, 0.6, 0.15)
				_box(p + side + Vector3(0, h + 0.3, 0), size, wood)  # barandilla
			_box(p + Vector3(0, h * 0.5, 1.45), Vector3(0.6, h, 0.1), wood.darkened(0.2))  # escalera
		"camp":
			_box(p + Vector3(0, 0.15, 0), Vector3(0.9, 0.3, 0.9), Color(0.25, 0.22, 0.2))  # leña de la hoguera
			var fire := EnemyFire.new()
			fire.camp_id = str(post["id"])
			fire.lit = not _fires_out.has(fire.camp_id)
			fire.out_day = int(_fires_out.get(fire.camp_id, -1))
			_geometry.add_child(fire)
			fire.global_position = p
			fire.extinguished.connect(_on_fire_out)
			_fires[fire.camp_id] = fire
			var tents := int(post.get("tents", 2))
			for i in tents:
				var a := i * TAU / tents + 0.4
				var at := ground_point(p.x + cos(a) * 6.0, p.z + sin(a) * 6.0)
				_box(at + Vector3(0, 1, 0), Vector3(2.4, 2, 0.3), Color(0.48, 0.3, 0.2))
				if i == 0:  # pista: el ojo cerrado bordado en la lona
					_geometry.add_child(ClueModels.make("emblema_ojo_campamento", "tent_eye", at + Vector3(0, 1.1, -0.17),
						"En la lona hay bordado un ojo cerrado. El mismo que en la puerta del pueblo pesquero."))
				_box(at + Vector3(0, 2, 0.8), Vector3(2.6, 0.25, 2), Color(0.55, 0.35, 0.24))
		"ritual":
			for spot: Vector3 in post["spots"]:
				var stone: Vector3 = spot + (p - spot).normalized() * 1.2
				_box(stone + Vector3(0, 1.0, 0), Vector3(0.7, 2.0, 0.7), Color(0.45, 0.2, 0.6))
		"workers":
			for spot: Vector3 in post["spots"]:
				_box(spot + Vector3(0.9, 0.4, 0), Vector3(0.8, 0.8, 0.8), wood.lightened(0.15))  # cajas
				_box(spot + Vector3(0.9, 1.0, 0.1), Vector3(0.6, 0.4, 0.6), wood)


# ------------------------------------------------------------------ sinergias de la guarnición

## Han apagado la hoguera de un campamento: todos sus miembros se despiertan y buscan alrededor.
func _on_fire_out(fire: EnemyFire) -> void:
	var day := clock.day if clock != null else 1
	fire.out_day = day
	_fires_out[fire.camp_id] = day
	if is_instance_valid(player):
		player.notice.emit("Apagas la hoguera... ¡el campamento se despierta!")
	for id in _actors:
		var actor: CreatureActor = _actors[id]
		if not is_instance_valid(actor) or actor.dead or actor.post.get("role", "") != "camp":
			continue
		var focus: Vector3 = actor.post.get("focus", Vector3.INF)
		if focus.distance_to(fire.global_position) < 1.0:
			actor.alert_seconds = 60.0
			actor._start_search(fire.global_position)


## ¿Está 'point' a oscuras para quien mira desde la hoguera de su campamento ('focus')?
func fire_dark(focus: Vector3, point: Vector3) -> bool:
	for id in _fires:
		var fire: EnemyFire = _fires[id]
		if is_instance_valid(fire) and fire.global_position.distance_to(focus) < 1.0:
			return fire.in_dark(point)
	return false


## Cadena de mando: una patrulla entera no ha vuelto y el campamento está en guardia (no duermen
## y los puestos ven más) durante un día.
func is_vigilant() -> bool:
	if clock == null:
		return false
	return clock.day * 24.0 + clock.hour < _vigilant_until


func _check_patrol_lost(group_id: String) -> void:
	if group_id == "" or not group_id.contains("patrol") and not group_id.contains("scouts"):
		return
	for id in _records:
		if _records[id]["group"] == group_id and not _records[id]["dead"]:
			return
	if clock != null:
		_vigilant_until = clock.day * 24.0 + clock.hour + 24.0
	if is_instance_valid(player):
		player.notice.emit("Una patrulla no volverá al campamento. Allí se darán cuenta...")


## Fuerza del ritual que protege al jefe: magos del ritual vivos / total (0 si no hay ritual).
func ritual_strength() -> float:
	var total := 0
	var alive := 0
	for id in _records:
		var post: Dictionary = _records[id].get("post", {})
		if post.get("role", "") == "ritual":
			total += 1
			if not _records[id]["dead"]:
				alive += 1
	return float(alive) / total if total > 0 else 0.0


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
	return {"phase": phase, "first_day": first_day, "center": _vec(center), "records": _records.duplicate(true), "routes": _routes.duplicate(true), "roads": _roads.duplicate(true), "boss_defeated": guardian_defeated, "fires_out": _fires_out.duplicate(), "vigilant_until": _vigilant_until, "sprouts": sprouts.to_data() if sprouts != null else {}}

func from_data(data: Dictionary) -> void:
	phase = clampi(int(data.get("phase", 0)), 0, 4)
	first_day = maxi(1, int(data.get("first_day", 1)))
	if data.has("center"):
		center = _point(data["center"])
	_records = data.get("records", {}).duplicate(true)
	_routes = data.get("routes", {}).duplicate(true)
	_roads = data.get("roads", {}).duplicate(true)
	guardian_defeated = bool(data.get("boss_defeated", false))
	_fires_out = data.get("fires_out", {}).duplicate()
	_vigilant_until = float(data.get("vigilant_until", -1.0))
	if sprouts != null and data.get("sprouts") is Dictionary:
		sprouts.from_data(data["sprouts"])

static func _vec(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

static func _point(data: Array) -> Vector3:
	return Vector3(float(data[0]), float(data[1]), float(data[2]))
