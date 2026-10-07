extends RefCounted
## A* local sobre colisiones actuales. No requiere navmesh horneada de un mundo editable.
const CELL := 1.0
const LIMIT := 20
const BUDGET := 700
static var _frame := -1
static var _requests := 0
var path: Array[Vector3] = []
var _goal := Vector3.INF
var _retry := 0.0
var _last := Vector3.INF
var _stuck := 0.0
var _edge_shape: CapsuleShape3D   # formas de la criatura, creadas una vez (A* hace cientos de consultas)
var _room_shape: CapsuleShape3D

func steer(actor: CharacterBody3D, goal: Vector3, delta: float) -> Vector3:
	_retry -= delta
	if actor.global_position.distance_to(_last) < 0.01:
		_stuck += delta
	else:
		_stuck = 0.0
	_last = actor.global_position
	var offset := goal - actor.global_position
	offset.y = 0.0
	if offset.length() < 0.65:
		return Vector3.ZERO
	if not actor.test_move(actor.global_transform, offset.normalized() * 1.0) and path.is_empty():
		return offset
	if _retry <= 0.0 and (_goal.distance_to(goal) > 2.0 or path.is_empty() or _stuck > 0.8):
		var frame := Engine.get_physics_frames()
		if frame != _frame:
			_frame = frame
			_requests = 0
		if _requests < 2:
			_requests += 1
			path = find_path(actor, goal)
			_goal = goal
			_retry = 1.0 if not path.is_empty() else 2.0
			_stuck = 0.0
	while not path.is_empty() and Vector2(path[0].x - actor.global_position.x, path[0].z - actor.global_position.z).length() < 0.5:
		path.pop_front()
	if not path.is_empty():
		var next := path[0] - actor.global_position
		# Construcciones nuevas invalidan el tramo inmediatamente.
		if actor.test_move(actor.global_transform, next.normalized() * 0.4):
			_retry = minf(_retry, 0.15)
			_goal = Vector3.INF
		return next
	return Vector3.ZERO if _retry > 0.0 else offset

func find_path(actor: CharacterBody3D, goal: Vector3) -> Array[Vector3]:
	var origin := actor.global_position
	var target := Vector2i(roundi(clampf((goal.x - origin.x) / CELL, -LIMIT, LIMIT)), roundi(clampf((goal.z - origin.z) / CELL, -LIMIT, LIMIT)))
	var start := Vector2i.ZERO
	var open: Array[Vector2i] = [start]
	var costs := {start: 0.0}
	var parents := {}
	var positions := {start: origin}
	var samples := {start: origin}
	var closed := {}
	var best := start
	var best_distance := Vector2(start).distance_to(Vector2(target))
	for iteration in BUDGET:
		if open.is_empty():
			break
		var current := open[0]
		var score := INF
		for cell in open:
			var candidate := float(costs[cell]) + Vector2(cell).distance_to(Vector2(target))
			if candidate < score:
				current = cell
				score = candidate
		open.erase(current)
		closed[current] = true
		var distance := Vector2(current).distance_to(Vector2(target))
		if distance < best_distance:
			best = current
			best_distance = distance
		if current == target:
			break
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + step
			if absi(next.x) > LIMIT or absi(next.y) > LIMIT or closed.has(next):
				continue
			var previous: Vector3 = positions[current]
			if not samples.has(next):
				samples[next] = _walkable(actor, Vector3(origin.x + next.x * CELL, previous.y, origin.z + next.y * CELL))
			var point: Vector3 = samples[next]
			if not point.is_finite() or absf(point.y - previous.y) > 0.55:
				continue
			if not _edge_clear(actor, previous, point):
				continue
			var cost := float(costs[current]) + 1.0 + absf(point.y - previous.y)
			if costs.has(next) and float(costs[next]) <= cost:
				continue
			costs[next] = cost
			parents[next] = current
			positions[next] = point
			if not open.has(next):
				open.append(next)
	var result: Array[Vector3] = []
	while best != start and parents.has(best):
		result.push_front(positions[best])
		best = parents[best]
	return result

func _edge_clear(actor: CharacterBody3D, from: Vector3, to: Vector3) -> bool:
	if _edge_shape == null:
		_edge_shape = _capsule(actor, 0.0)
	var capsule := _edge_shape
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	var lift := maxf(0.04, to.y - from.y + 0.04)
	query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * (capsule.height * 0.5 + lift))
	query.motion = Vector3(to.x - from.x, 0, to.z - from.z)
	query.collision_mask = 1
	var exclude: Array[RID] = [actor.get_rid()]
	if is_instance_valid(actor.get("player")):
		exclude.append(actor.get("player").get_rid())
	query.exclude = exclude
	var result := actor.get_world_3d().direct_space_state.cast_motion(query)
	return result[0] >= 0.99

func _walkable(actor: CharacterBody3D, point: Vector3) -> Vector3:
	var exclude: Array[RID] = [actor.get_rid()]
	if is_instance_valid(actor.get("player")):
		exclude.append(actor.get("player").get_rid())
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.6, point + Vector3.DOWN * 1.2, 1)
	ray.exclude = exclude
	var space := actor.get_world_3d().direct_space_state
	var floor_hit := space.intersect_ray(ray)
	if floor_hit.is_empty() or floor_hit["normal"].y < 0.7:
		return Vector3.INF
	point = floor_hit["position"] + Vector3.UP * 0.04
	if _room_shape == null:
		_room_shape = _capsule(actor, 0.08)
	var capsule := _room_shape
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * capsule.height * 0.5)
	query.collision_mask = 1
	query.exclude = exclude
	return point if space.intersect_shape(query, 1).is_empty() else Vector3.INF

func _capsule(actor: CharacterBody3D, margin: float) -> CapsuleShape3D:
	var capsule := CapsuleShape3D.new()
	capsule.radius = float(actor.get("stats")["radius"]) + margin
	capsule.height = maxf(float(actor.get("stats")["height"]), capsule.radius * 2.0)
	return capsule
