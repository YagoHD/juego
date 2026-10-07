extends SceneTree
var failures := 0
func _init() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	print(("OK: " if ok else "FALLO: ") + message)
	if not ok:
		failures += 1
func _run() -> void:
	var arena = load("res://scenes/combat_arena.tscn").instantiate()
	arena.save_path = "user://stealth_test.json"
	root.add_child(arena)
	for i in 12:
		await physics_frame
	for node in get_nodes_in_group("creatures"):
		node.free()
	var p: Player = arena.player
	p.set_physics_process(false)
	p._waiting_for_ground = false
	p.set_creative(false)
	p.combat.invulnerable = 0.0
	p.global_position = Vector3(0, 0.1, 2)
	p._sneaking = true
	var c: CreatureActor = arena.spawn_creature("soldier", Vector3(0, 0.1, 0))
	c.set_physics_process(false)
	c.drop_loot = false
	await physics_frame
	check(not c.detects_player(), "agachado detrás no es detectado")
	check(c.can_backstab(p), "espalda desprevenida permite crítico")
	c.backstab(12.0, p)
	check(c.state == "stunned" and c.health < 85.0, "soldado recibe daño grande y aturdimiento")
	check(not c.can_backstab(p), "no encadena críticos mientras está alerta")
	c.free()
	c = arena.spawn_creature("tracker", Vector3.ZERO)
	c.set_physics_process(false)
	c.drop_loot = false
	c.backstab(12.0, p)
	check(c.dead, "rastreador muere de un crítico")
	await process_frame
	c = arena.spawn_creature("soldier", Vector3(0, 0.1, 0))
	c.set_physics_process(false)
	p.global_position = Vector3(0, 0.1, -7)
	await physics_frame
	check(not c.detects_player(), "agacharse reduce alcance de detección frontal")
	p._sneaking = false
	var ally: CreatureActor = arena.spawn_creature("mage", Vector3(5, 0.1, 0))
	ally.set_physics_process(false)
	c._choose_target()
	check(c.state == "chase" and ally.alert_seconds > 0.0 and ally.state == "search", "ver jugador avisa aliados antes de recibir golpes")
	var remembered := c._last_seen
	p.global_position = Vector3(0, 0.1, 15)
	c._choose_target()
	check(c.state == "search" and c.target == null and c._last_seen == remembered, "busca lugar conocido sin seguir posición oculta")
	c._search_seconds = 0.0
	c._decision = 1.0
	c._physics_process(0.1)
	check(c.state == "return" and c.alert_seconds > 0.0, "agotada búsqueda regresa manteniendo alerta")
	c._physics_process(61.0)
	check(c.alert_seconds == 0.0, "alerta desaparece con tiempo de juego")
	print("TOTAL: %d fallos" % failures)
	quit(1 if failures else 0)
