extends SceneTree
const Director = preload("res://scripts/world/tower_director.gd")
var failures := 0
func _init() -> void:
	Engine.max_fps = 120
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	print(("OK: " if ok else "FALLO: ") + message)
	if not ok:
		failures += 1
func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame
func _run() -> void:
	var arena = load("res://scenes/combat_arena.tscn").instantiate()
	arena.save_path = "user://nav_tower_test.json"
	root.add_child(arena)
	await frames(20)
	for node in get_nodes_in_group("creatures") + get_nodes_in_group("enemy_squads"):
		node.free()
	arena.player.set_creative(true)
	# Pared larga entre actor y destino: A* debe buscar una esquina lateral.
	arena._box(Vector3(0, 1.5, -30), Vector3(10, 3, 1), Color.GRAY)
	var actor: CreatureActor = arena.spawn_creature("soldier", Vector3(0, 0.05, -26))
	actor.drop_loot = false
	actor.set_physics_process(false)
	await frames(3)
	var goal := Vector3(0, 0.05, -35)
	var path: Array[Vector3] = actor.navigator.find_path(actor, goal)
	check(not path.is_empty() and path[-1].distance_to(goal) < 1.5, "navegación encuentra ruta tras pared larga")
	var bends := false
	for point in path:
		if absf(point.x) > 5.0:
			bends = true
	check(bends, "ruta rodea esquina en vez de atravesar pared")
	actor._destination = goal
	actor._timer = 100.0
	actor._set_state("patrol")
	actor.set_physics_process(true)
	await frames(550)
	check(actor.global_position.z < -31.0, "actor recorre físicamente el rodeo")
	actor.set_physics_process(false)
	var blocked_point: Vector3 = path[path.size() / 2]
	arena._box(blocked_point + Vector3.UP * 1.5, Vector3(2, 3, 2), Color.GRAY)
	await frames(2)
	actor.global_position = Vector3(0, 0.05, -26)
	var changed: Array[Vector3] = actor.navigator.find_path(actor, goal)
	check(changed != path, "construcción nueva cambia ruta sobre colisiones actuales")
	var cliff: Vector3 = actor.navigator._walkable(actor, Vector3(70, 0, -26))
	check(not cliff.is_finite(), "suelo inexistente o precipicio no se considera transitable")
	actor.free()
	var tower = Director.new()
	tower.player = arena.player
	tower.center = Vector3(30, 0.1, -35)
	tower.set_physics_process(false)
	arena.add_child(tower)
	tower.advance_to_day(1)
	check(tower.phase == 1 and tower._records.size() == 4, "día uno genera solo cuatro exploradores")
	var allowed := true
	for record in tower._records.values():
		allowed = allowed and record["species"] == "tracker"
	check(allowed, "día uno no incluye arqueros ni enemigos fuertes")
	tower._records["1_0"]["dead"] = true
	var time := DayNight.new()
	time.day = 2
	tower.clock = time
	tower._physics_process(0.31)
	check(tower.phase == 2, "cambio de día del reloj activa fase automáticamente")
	tower.clock = null
	time.free()
	tower.advance_to_day(2)
	check(tower._records.size() == 8 and tower._records["2_0"]["species"] == "archer", "día dos añade arqueros y mini campamento")
	check(tower._records["2_0"]["post"]["role"] == "sentry" and tower._records["2_0"]["post"]["hold"], "el arquero vigila desde su torre")
	check(tower._records["2_1"]["post"]["role"] == "camp", "el campamento pequeño descansa junto a su hoguera")
	check(tower._records["1_0"]["dead"], "avanzar día no resucita enemigos muertos")
	tower.advance_to_day(3)
	var species: Array = []
	for record in tower._records.values():
		if not species.has(record["species"]):
			species.append(record["species"])
	check(species.has("captain") and species.has("mage") and species.has("soldier") and not species.has("tower_guardian"), "día tres incluye todos los normales sin jefe")
	var roles := {}
	for record in tower._records.values():
		if not record["post"].is_empty():
			roles[record["post"]["role"]] = true
	check(roles.has("ritual") and roles.has("camp") and roles.has("sentry") and tower._routes.size() >= 3, "día tres: magos en ritual, campamento, guardias y patrullas")
	tower.advance_to_day(4)
	var boss_id := ""
	for id in tower._records:
		if tower._records[id]["species"] == "tower_guardian":
			boss_id = id
	check(tower.phase == 4 and tower._records.size() >= 120 and boss_id != "", "día cuatro: ejército de %d y jefe" % tower._records.size())
	var count: int = tower._records.size()
	tower.advance_to_day(20)
	check(tower._records.size() == count, "días posteriores no duplican refuerzos")
	var data: Dictionary = tower.to_data()
	var restored = Director.new()
	restored.from_data(data)
	check(restored.phase == 4 and restored._records["1_0"]["dead"] and restored._routes == tower._routes, "guardado conserva fases bajas y rutas")
	var road: Array[Vector3] = [Vector3(20, 0.1, -35), Vector3(30, 0.1, -35)]
	for i in 10:
		tower.register_road("future_" + str(i), road)
	var road_groups := 0
	for group in tower._routes:
		if str(group).begins_with("road_"):
			road_groups += 1
	check(road_groups > 0 and road_groups < 10, "solo algunos caminos registrados reciben patrulla aleatoria estable")
	# Puestos: el vigía se queda arriba mirando hacia fuera; dormido no ve lo que despierto vería.
	tower._spawn("2_0")
	var sentry: CreatureActor = tower._actors["2_0"]
	var post_point: Vector3 = sentry.post["point"]
	sentry.set_physics_process(true)
	for i in 120:
		await physics_frame
	check(sentry.global_position.distance_to(post_point) < 1.2 and sentry.state in ["watch", "patrol", "idle"], "el vigía se queda en su torre (%s, a %.1f m)" % [sentry.state, sentry.global_position.distance_to(post_point)])
	tower._spawn("2_1")
	var camper: CreatureActor = tower._actors["2_1"]
	var saved_position: Vector3 = arena.player.global_position
	arena.player.set_creative(false)
	arena.player.global_position = camper.global_position - camper.global_basis.z * 8.0
	camper.state = "sit"
	var awake: bool = camper.detects_player()
	camper.state = "sleep"
	var asleep: bool = camper.detects_player()
	arena.player.global_position = saved_position
	arena.player.set_creative(true)
	check(awake and not asleep, "dormido no ve a quien despierto vería a 8 m (despierto %s, dormido %s)" % [awake, asleep])
	tower._spawn(boss_id)
	var boss: CreatureActor = tower._actors[boss_id]
	check(boss.global_position.distance_to(tower.center) < 1.0, "guardián nace en interior de torre")
	boss.drop_loot = false
	boss.take_damage(10000.0, arena.player)
	check(tower.guardian_defeated and tower._records[boss_id]["dead"], "muerte del jefe permanece registrada")
	await frames(2)
	data = tower.to_data()
	check(data["records"][boss_id]["dead"], "guardar después de eliminar cuerpo del jefe conserva baja")
	var gen := IslandGenerator.new()
	var mapped = Director.new()
	mapped.configure(arena.player, null, gen)
	var center: Vector3 = mapped.center
	var map_index := gen._index(roundi(center.x / 0.5), roundi(center.z / 0.5))
	check(center != Vector3.ZERO and gen.get_surface_map()[map_index * 3] == IslandGenerator.CORRUPT_SOIL, "torre se ubica realmente en región corrupta de la isla")
	print("Centro de torre: ", center)
	mapped.free()
	restored.free()
	print("TOTAL: %d fallos" % failures)
	quit(1 if failures else 0)
