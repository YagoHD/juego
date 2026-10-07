extends SceneTree
const Arrow = preload("res://scripts/player/player_arrow.gd")
var failures := 0
var arena: Node3D
var p: Player
var combat: PlayerCombat

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

func enemy(at := Vector3(0, 0.1, -1.8)) -> CreatureActor:
	var c: CreatureActor = arena.spawn_creature("tower_guardian", at)
	c.drop_loot = false
	c.set_physics_process(false)
	return c

func reset() -> void:
	combat.cancel_actions()
	combat.invulnerable = 0.0
	combat.health = 100.0
	combat.stamina = 100.0
	combat._cooldown = 0.0
	combat._block_rearm = 0.0
	combat._guard_broken = 0.0
	combat._regen_delay = 0.0
	combat._poison = 0.0
	p._set_captured(true)

func key(code: Key, down := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	p._unhandled_input(event)

func right_click(down := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = down
	p._unhandled_input(event)

func _run() -> void:
	arena = load("res://scenes/combat_arena.tscn").instantiate()
	arena.set("save_path", "user://player_combat_test.json")
	root.add_child(arena)
	await frames(30)
	for c in get_nodes_in_group("creatures"):
		c.free()
	for group in get_nodes_in_group("enemy_squads"):
		group.free()
	p = arena.player
	combat = p.combat
	combat.set_process(false)
	p.set_creative(false)
	p.needs.hunger = 0.0
	p._waiting_for_ground = false
	p.global_position = Vector3(0, 0.01, 0)
	p.rotation = Vector3.ZERO
	p._pitch = 0.0
	p._head.rotation = Vector3.ZERO
	p._spring.basis = Basis.IDENTITY
	await frames(4)
	p.set_physics_process(false)
	p.inventory.clear()
	p.inventory.set_slot(0, {"id": "spear", "count": 1, "dur": 40})
	p._select_slot(0)
	var c := enemy()
	await frames(3)
	reset()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	p._unhandled_input(click)
	check(c.health == 400.0 and combat.charging_melee, "pulsar empieza carga sin lanzar ligero antes del pesado")
	click.pressed = false
	p._unhandled_input(click)
	var light_damage := 400.0 - c.health
	check(light_damage > 0.0 and combat.stamina == 87.0, "clic ligero causa daño y consume resistencia")
	check(combat.try_attack() and 400.0 - c.health == light_damage, "cooldown evita spam de ataques")
	reset()
	c.health = 400.0
	click.pressed = true
	p._unhandled_input(click)
	combat._process(0.6)
	check(c.health == 400.0 and combat.charging_melee, "mantener clic carga sin daño automático")
	click.pressed = false
	p._unhandled_input(click)
	check(is_equal_approx(400.0 - c.health, light_damage * 2.0) and combat._pending.is_empty(), "soltar clic cargado lanza un único pesado sin otra espera")
	reset()
	c.health = 400.0
	click.pressed = true
	p._unhandled_input(click)
	right_click()
	click.pressed = false
	p._unhandled_input(click)
	check(combat.blocking and not combat.charging_melee and c.health == 400.0, "clic derecho cancela carga y pasa a guardia")
	right_click(false)
	check(not combat.blocking, "soltar clic derecho baja guardia")
	reset()
	key(KEY_X)
	key(KEY_G)
	key(KEY_Z)
	check(combat._pending.is_empty() and not combat.blocking and combat._dodge_time == 0.0, "teclas anteriores X G Z dejan de accionar combate")
	reset()
	c.health = 400.0
	combat.try_attack(true)
	check(c.health == 400.0 and not combat._pending.is_empty(), "pesado tiene preparación sin daño inmediato")
	combat._process(0.3)
	check(c.health == 400.0, "pesado aún no impacta antes de su aviso")
	combat._process(0.3)
	check(is_equal_approx(400.0 - c.health, light_damage * 2.0), "pesado impacta después con doble daño")
	reset()
	c.health = 400.0
	combat.try_attack()
	combat._cooldown = 0.0
	combat.try_attack()
	combat._cooldown = 0.0
	combat.try_attack(true)
	check(is_equal_approx(float(combat._pending.get("damage", 0.0)), 18.0 * 2.0 * 1.65), "combo ligero ligero pesado potencia el remate")
	combat._process(0.6)
	check(c.state == "stunned", "remate de combo abre oportunidad aturdiendo")
	reset()
	combat.try_attack()
	combat._cooldown = 0.0
	combat.try_attack(true)
	combat._process(0.6)
	combat._cooldown = 0.0
	var hp := c.health
	combat.try_attack()
	check(is_equal_approx(hp - c.health, light_damage * 1.5), "combo ligero pesado ligero también funciona")
	reset()
	combat.try_attack(true)
	p._select_slot(1)
	combat._process(0.6)
	check(combat._pending.is_empty(), "cambiar arma cancela impacto pesado pendiente")
	p._select_slot(0)
	reset()
	right_click()
	combat.take_damage(20.0, c.global_position, 6.0, c)
	check(combat.health == 100.0 and combat.stamina == 100.0 and c.state == "stunned" and combat._poison == 0.0, "parry no pierde vida/resistencia ni envenena y aturde rival")
	right_click(false)
	right_click()
	combat.invulnerable = 0.0
	combat.take_damage(20.0, c.global_position, 0.0, c)
	check(is_equal_approx(combat.health, 93.0) and combat.stamina == 86.0, "volver a pulsar guardia no regala otro parry")
	reset()
	combat.set_blocking(true)
	combat._block_time = 1.0
	combat.take_damage(20.0, Vector3(0, 0, 2), 0.0, c)
	check(combat.health == 80.0, "guardia no cubre ataques por la espalda")
	reset()
	check(p.equip("offhand", "wooden_shield"), "escudo se equipa en mano secundaria")
	right_click()
	combat._block_time = 1.0
	combat.take_damage(20.0, c.global_position, 0.0, c)
	check(combat.health == 100.0 and combat.stamina == 70.0, "escudo absorbe todo daño con mayor gasto de resistencia")
	reset()
	combat.stamina = 5.0
	combat.set_blocking(true)
	combat._block_time = 1.0
	combat.take_damage(20.0, c.global_position, 0.0, c)
	check(combat.health == 80.0 and combat.stamina == 0.0 and combat._guard_broken > 0.0, "resistencia insuficiente rompe guardia y deja recibir daño")
	p.unequip("offhand")
	reset()
	combat.set_blocking(true)
	combat.take_damage(5.0, c.global_position, 0.0, null, false)
	check(combat.health == 95.0, "daño ambiental no se puede bloquear")
	c.free()
	reset()
	check(combat.dodge(Vector3.RIGHT), "esquiva lateral se inicia")
	var short_speed := combat.movement_velocity().length()
	check(combat.stamina == 88.0 and not combat._roll, "esquiva corta cuesta menos resistencia")
	check(combat.dodge(Vector3.BACK) and combat._roll and combat.stamina == 56.0 and combat.movement_velocity().length() > short_speed, "segunda esquiva rápida se convierte en voltereta larga")
	combat.take_damage(50.0, Vector3(0, 0, -2))
	check(combat.health == 100.0 and combat.invulnerable >= combat._dodge_time, "voltereta da inmunidad durante todo el movimiento")
	check(not combat.dodge(Vector3.RIGHT), "no permite encadenar volteretas durante la misma")
	reset()
	var side := InputEventKey.new()
	side.keycode = KEY_A
	side.pressed = true
	Input.parse_input_event(side.duplicate())
	Input.flush_buffered_events()
	key(KEY_ALT)
	check(combat.movement_velocity().x < 0.0, "Alt con A esquiva hacia la izquierda")
	side.pressed = false
	Input.parse_input_event(side.duplicate())
	Input.flush_buffered_events()
	reset()
	side.keycode = KEY_D
	side.pressed = true
	Input.parse_input_event(side.duplicate())
	Input.flush_buffered_events()
	key(KEY_ALT)
	check(combat.movement_velocity().x > 0.0, "Alt con D esquiva hacia la derecha")
	side.pressed = false
	Input.parse_input_event(side.duplicate())
	Input.flush_buffered_events()
	key(KEY_ALT, false)
	key(KEY_ALT)
	check(combat._roll, "doble toque de Alt activa voltereta")
	reset()
	p.set_physics_process(true)
	var before := p.global_position
	key(KEY_ALT)
	for i in 10:
		combat._process(1.0 / 60.0)
		await frames(1)
	check(p.global_position.z - before.z > 0.3, "esquiva desplaza jugador usando colisión real")
	p.set_physics_process(false)
	reset()
	p.global_position = Vector3(0, 0.01, 0)
	p.set_physics_process(true)
	p.velocity.y = Player.JUMP_VELOCITY
	await frames(2)
	p.set_physics_process(false)
	c = enemy()
	await frames(2)
	combat.try_attack(true)
	check(is_equal_approx(float(combat._pending.get("damage", 0.0)), 18.0 * 2.0 * 1.25), "pesado en salto aplica bonificación aérea")
	reset()
	var air_hp := c.health
	combat.try_attack()
	check(is_equal_approx(air_hp - c.health, light_damage * 1.25), "ligero en salto también aumenta daño")
	c.free()
	reset()
	p.global_position = Vector3(0, 0.01, 0)
	p.inventory.set_slot(0, {"id": "bow", "count": 1, "dur": 50})
	p.inventory.set_slot(1, {"id": "arrow", "count": 4})
	p._select_slot(0)
	p._head.rotation = Vector3.ZERO
	await frames(3)
	click.pressed = true
	p._unhandled_input(click)
	combat._process(1.5)
	check(combat.drawing_bow and combat.stamina < 100.0, "mantener clic tensa arco y gasta resistencia")
	click.pressed = false
	p._unhandled_input(click)
	var arrows := get_nodes_in_group("player_arrows")
	check(arrows.size() == 1 and p.inventory.count_of("arrow") == 3 and int(p.inventory.get_slot(0)["dur"]) == 49, "soltar clic lanza flecha consume munición y desgasta arco")
	if not arrows.is_empty():
		check(is_equal_approx(arrows[0].base_damage, 22.0), "tensión completa alcanza daño base máximo")
		arrows[0].free()
	check(Arrow.damage_multiplier(30, 5, true, true) > Arrow.damage_multiplier(3, 0, false, false), "distancia altura y sigilo aumentan daño")
	check(Arrow.damage_multiplier(10, 0, true, false) == Arrow.damage_multiplier(10, 0, false, false), "enemigo alerta no recibe bonus de sigilo")
	check(PlayerCombat.bow_spread(5) > PlayerCombat.bow_spread(1.5), "tensión excesiva aumenta dispersión")
	reset()
	combat.start_bow_draw()
	combat._process(2.5)
	var stamina_before := combat.stamina
	combat._process(1.0)
	check(combat.stamina < stamina_before - 10.0, "mantener arco demasiado aumenta fatiga sin regenerar")
	combat.stamina = 1.0
	combat._process(1.0)
	check(not combat.drawing_bow and p.inventory.count_of("arrow") == 3, "agotamiento cancela tensión sin consumir flecha")
	reset()
	combat.start_bow_draw()
	p.ui_open = true
	combat._process(0.01)
	check(not combat.drawing_bow and not combat.blocking and combat._dodge_time == 0.0, "abrir interfaz cancela acciones de combate")
	p.ui_open = false
	reset()
	combat.start_bow_draw()
	combat.draw_seconds = 1.5
	var target := enemy(Vector3(0, 0.1, -6))
	await frames(3)
	combat.release_bow()
	await frames(30)
	check(target.health < 400.0, "flecha liberada con arco alcanza criatura y aplica daño real")
	target.free()
	# Colisión real: una flecha rápida no atraviesa el obstáculo del mapa.
	c = enemy(Vector3(-6, 0.1, -14))
	var arrow = Arrow.new()
	arrow.source = p
	arrow.launch_origin = Vector3(-6, 1, -10)
	arrow.velocity = Vector3(0, 0, -30)
	arena.add_child(arrow)
	arrow.global_position = arrow.launch_origin
	await frames(12)
	check(not is_instance_valid(arrow) and c.health == 400.0, "flecha del jugador choca con pared sin dañar detrás")
	c.free()
	print("TOTAL: %d fallos" % failures)
	quit(1 if failures else 0)
