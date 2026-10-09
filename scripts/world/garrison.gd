extends RefCounted
class_name Garrison
## Cómo se despliegan los invasores alrededor de la torre, por días (TowerDirector): en PUESTOS con
## sentido en vez de en grupos amontonados.
##   - scouts: exploradores que patrullan el borde de la corrupción (día 1).
##   - watchtower: torre de vigía de madera con un arquero arriba que vigila hacia fuera.
##   - camp: tiendas alrededor de una hoguera; de día descansan y charlan, de noche duermen.
##   - ritual: piedras moradas junto a la torre donde los magos canalizan.
##   - gate: guardias en la entrada de la torre.
##   - workers: rastreadores que van y vienen entre montones de cajas.
##   - patrol: patrullas que dan la vuelta a la zona.
##   - boss: el guardián, dentro de la torre (día 4).
## Día 1, exploradores; día 2, una torre de vigía y un campamento pequeño; día 3, el campamento
## grande, magos, guardias y patrullas; día 4, el ejército entero (cerca de 150) y el jefe.
##
## Cada puesto: {"id", "kind", "point", "facing" (radianes, hacia dónde mira), "spots" (sitios de
## los miembros: asientos, piedras, cajas), "route" (patrullas), "roster" (especies)}.

const MIX_CAMP := ["captain", "soldier", "soldier", "soldier", "archer", "archer", "tracker", "tracker", "soldier",
	"mage", "archer", "soldier", "tracker"]


## Los puestos que llegan en el día 'stage' (1..4). 'director' da los puntos del terreno.
static func posts_for(stage: int, director: Node) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + stage
	var posts: Array[Dictionary] = []
	match stage:
		1:
			for i in 2:
				posts.append(_patrol("s1_scouts%d" % i, director, i * PI + 0.4, 46.0, ["tracker", "tracker"], 4))
		2:
			posts.append(_watchtower("s2_tower0", director, 0.9, 30.0))
			posts.append(_camp("s2_camp0", director, 2.6, 24.0, ["archer", "tracker", "tracker"], 2, 0))
		3:
			posts.append(_camp("s3_camp0", director, 4.2, 20.0,
				["captain", "soldier", "soldier", "soldier", "soldier", "archer", "archer", "tracker", "tracker"], 4, 1))
			posts.append(_watchtower("s3_tower0", director, 3.3, 32.0))
			posts.append(_watchtower("s3_tower1", director, 5.4, 32.0))
			posts.append(_ritual("s3_ritual", director, 2, 0.0))
			posts.append(_gate("s3_gate", director, ["soldier", "soldier"]))
			posts.append(_patrol("s3_patrol0", director, 1.8, 36.0, ["soldier", "soldier", "tracker"], 6))
		4:
			for i in 7:
				var angle := i * TAU / 7.0 + 0.3
				var size := 10 + rng.randi_range(0, 3)
				posts.append(_camp("s4_camp%d" % i, director, angle, rng.randf_range(30.0, 46.0),
					MIX_CAMP.slice(0, size), 4 + rng.randi_range(0, 2), 2 if i == 0 else -1))
			for i in 5:
				posts.append(_watchtower("s4_tower%d" % i, director, i * TAU / 5.0 + 0.6, rng.randf_range(38.0, 52.0)))
			posts.append(_ritual("s4_ritual", director, 4, PI / 4.0))
			posts.append(_gate("s4_gate", director, ["soldier", "captain"]))
			posts.append(_workers("s4_workers", director, 12))
			for i in 6:
				posts.append(_patrol("s4_patrol%d" % i, director, i * TAU / 6.0, rng.randf_range(22.0, 50.0),
					["soldier", "archer", "tracker", "soldier"], 6))
			posts.append({"id": "s4_boss", "kind": "boss", "point": director.center + Vector3.UP * 0.25,
				"facing": PI / 2.0, "spots": [], "route": [], "roster": ["tower_guardian"]})
	return posts


static func _outward(director: Node, point: Vector3) -> float:
	var away: Vector3 = point - director.center
	return atan2(away.z, away.x)


static func _ring(center: Vector3, count: int, radius: float, director: Node, start := 0.0) -> Array:
	var spots: Array = []
	for i in count:
		var a := start + i * TAU / maxi(count, 1)
		spots.append(director.ground_point(center.x + cos(a) * radius, center.z + sin(a) * radius))
	return spots


static func _patrol(id: String, director: Node, angle: float, radius: float, roster: Array, steps: int) -> Dictionary:
	var route: Array = []
	for step in steps:
		route.append(director.affected_point(angle + step * 0.45, radius))
	return {"id": id, "kind": "patrol", "point": route[0], "facing": angle, "spots": [], "route": route, "roster": roster}


static func _watchtower(id: String, director: Node, angle: float, radius: float) -> Dictionary:
	var point: Vector3 = director.affected_point(angle, radius)
	return {"id": id, "kind": "watchtower", "point": point, "facing": _outward(director, point),
		"spots": [point + Vector3.UP * Garrison.WATCH_HEIGHT], "route": [], "roster": ["archer"]}


## Campamentos del mapa beta1 (letra L, metros): los tres primeros campamentos van ahí si la isla
## los tiene cerca de la torre; si no (otra isla, pruebas), alrededor de la torre como siempre.
const MAP_CAMPS := [Vector2(48, -159), Vector2(77, -203), Vector2(159, -149)]


static func _camp(id: String, director: Node, angle: float, radius: float, roster: Array, tents: int, site := -1) -> Dictionary:
	var point: Vector3 = director.affected_point(angle, radius)
	if site >= 0 and director.get("generator") != null:
		var spot: Vector2 = MAP_CAMPS[site]
		var candidate: Vector3 = director.ground_point(spot.x, spot.y)
		if candidate.distance_to(director.center) < 110.0:
			point = candidate
	return {"id": id, "kind": "camp", "point": point, "facing": 0.0, "tents": tents,
		"spots": _ring(point, maxi(roster.size(), 3), 2.4, director), "route": [], "roster": roster}


static func _ritual(id: String, director: Node, mages: int, start: float) -> Dictionary:
	var center: Vector3 = director.center
	return {"id": id, "kind": "ritual", "point": center, "facing": 0.0,
		"spots": _ring(center, mages, 8.5, director, start), "route": [], "roster": Array(range(mages)).map(func(_i: int) -> String: return "mage")}


static func _gate(id: String, director: Node, roster: Array) -> Dictionary:
	# La entrada de la torre da al sur (+Z): un guardia a cada lado, mirando hacia fuera.
	var center: Vector3 = director.center
	var spots: Array = []
	for i in roster.size():
		var side := -2.6 if i % 2 == 0 else 2.6
		spots.append(director.ground_point(center.x + side, center.z + 6.5 + (i / 2) * 1.5))
	return {"id": id, "kind": "gate", "point": center + Vector3(0, 0, 6.5), "facing": PI / 2.0,
		"spots": spots, "route": [], "roster": roster}


static func _workers(id: String, director: Node, count: int) -> Dictionary:
	var center: Vector3 = director.center
	var roster: Array = []
	for i in count:
		roster.append("tracker")
	return {"id": id, "kind": "workers", "point": center, "facing": 0.0,
		"spots": _ring(center, 6, 14.0, director, 0.5), "route": [], "roster": roster}


## Altura del puesto del arquero en la torre de vigía (metros sobre el suelo).
const WATCH_HEIGHT := 4.3
