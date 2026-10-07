extends SceneTree
const Squad = preload("res://scripts/creatures/enemy_squad.gd")
var failures := 0
func _init() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	print(("OK: " if ok else "FALLO: ") + message)
	if not ok:
		failures += 1
func _run() -> void:
	var arena = load("res://scenes/combat_arena.tscn").instantiate()
	arena.save_path = "user://squad_tests.json"
	root.add_child(arena)
	for i in 12:
		await physics_frame
	for node in get_nodes_in_group("enemy_squads"):
		node.free()
	for node in get_nodes_in_group("creatures"):
		node.free()
	var group = Squad.new()
	group.points.assign([Vector3(0, 0.1, -25), Vector3(5, 0.1, -25), Vector3(10, 0.1, -25), Vector3(15, 0.1, -25)])
	arena.add_child(group)
	group.set_physics_process(false)
	var actors: Array[CreatureActor] = []
	for id in ["captain", "soldier", "mage", "archer"]:
		var actor: CreatureActor = arena.spawn_creature(id, Vector3(actors.size() * 0.8, 0.1, -25))
		actor.set_physics_process(false)
		group.add_member(actor)
		actors.append(actor)
	await physics_frame
	var sequence: Array[int] = [group.waypoint]
	for i in 6:
		group.advance_route()
		sequence.append(group.waypoint)
	check(sequence == [0, 1, 2, 3, 2, 1, 0], "ruta A B C D C B A")
	for actor in actors:
		actor.global_position = group.destination(actor)
		actor._set_state("patrol")
	await physics_frame
	group._physics_process(0.25)
	check(group.rest_seconds > 0.0, "grupo descansa al alcanzar el punto")
	actors[3].target = arena.player
	actors[3]._set_state("chase")
	group._pulse = 0.0
	group._physics_process(0.25)
	check(actors[3].team_damage == 1.2, "capitán inspira daño de aliados")
	check(actors[3].team_shield == 0.2, "soldado protege al arquero cercano")
	check(actors[3].enchanted_arrow, "mago fusiona magia con flecha del arquero")
	check(group.request_attack(actors[0]) and not group.request_attack(actors[1]), "ataques escalonados por orden compartida")
	actors[0]._set_state("windup")
	actors[1]._set_state("windup")
	group._order_cooldown = 0.0
	check(not group.request_attack(actors[2]), "máximo dos ataques preparándose a la vez")
	actors[3]._attack_kind = "arrow"
	actors[3]._attack_point = arena.player.global_position
	actors[3]._execute_attack()
	var shots := get_nodes_in_group("creature_projectiles")
	check(shots.size() == 1 and shots[0].kind == "enchanted_arrow" and shots[0].damage > 11.0 and not actors[3].enchanted_arrow, "flecha encantada real consume carga una vez")
	actors[0].dead = true
	actors[1].dead = true
	group._pulse = 0.0
	group._physics_process(0.25)
	check(actors[3].team_damage == 1.0 and actors[3].team_shield == 0.0, "matar apoyos elimina sus beneficios")
	var copy = Squad.new()
	copy.from_data(group.to_data())
	check(copy.points == group.points and copy.waypoint == group.waypoint, "ruta y progreso se serializan")
	copy.free()
	arena.player.set_creative(true)
	group.waypoint = 1
	group.rest_seconds = 0.0
	for actor in actors:
		actor.dead = false
		actor.target = null
		actor._set_state("patrol")
		actor.set_physics_process(true)
	var before := actors[1].global_position
	for i in 120:
		await physics_frame
	check(actors[1].global_position.distance_to(before) > 1.0, "patrulla camina realmente hacia siguiente punto")
	arena.save()
	for actor in actors:
		actor.free()
	group.free()
	check(arena._load(), "carga partida con patrullas")
	var restored := get_nodes_in_group("enemy_squads")
	check(restored.size() == 1 and restored[0].living().size() == 4 and restored[0].waypoint == 1, "guardado restaura pertenencia y punto pendiente")
	print("TOTAL: %d fallos" % failures)
	quit(1 if failures else 0)
