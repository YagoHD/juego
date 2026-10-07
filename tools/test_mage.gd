extends SceneTree
var failures := 0
var arena: Node3D
var p: Player

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
	arena = load("res://scenes/combat_arena.tscn").instantiate()
	arena.set("save_path", "user://mage_test.json")
	root.add_child(arena)
	await frames(20)
	for node in get_nodes_in_group("creatures") + get_nodes_in_group("enemy_squads"):
		node.free()
	p = arena.player
	p.set_physics_process(false)
	p.combat.set_process(false)
	p._waiting_for_ground = false
	p.set_creative(false)
	p.combat.invulnerable = 0.0
	p.needs.hunger = 0.0
	p.global_position = Vector3(0, 0.1, 0)
	var mage: CreatureActor = arena.spawn_creature("mage", Vector3(0, 0.1, -6))
	mage.set_physics_process(false)
	mage.drop_loot = false
	mage.target = p
	await frames(3)
	mage._begin_attack()
	check(mage._attack_kind == "bolt", "mago empieza con bola de rayos")
	mage._execute_attack()
	var orbs := get_nodes_in_group("creature_projectiles")
	check(orbs.size() == 1 and orbs[0].kind == "electric_orb" and orbs[0].velocity.length() == 8.0, "bola eléctrica real con velocidad esquivable")
	for orb in orbs:
		orb.free()
	mage._begin_attack()
	check(mage._attack_kind == "lightning" and mage._timer == 2.0 and mage._telegraph != null, "descarga anuncia círculo durante dos segundos")
	var point := mage._attack_point
	mage.set_physics_process(true)
	await frames(90)
	check(p.combat.health == 100.0 and mage.state == "windup", "descarga espera realmente antes de impactar en física")
	p.global_position = Vector3(3, 0.1, 0)
	await frames(2)
	check(mage._attack_point == point, "círculo permanece en lugar inicial y no persigue al jugador")
	await frames(45)
	mage.set_physics_process(false)
	check(p.combat.health == 100.0, "salir del círculo evita la descarga")
	p.global_position = Vector3(0, 0.1, 0)
	await frames(2)
	mage._attack_count = 1
	mage._begin_attack()
	mage._execute_attack()
	check(p.combat.health == 76.0 and mage._telegraph == null, "permanecer dentro recibe daño y desaparece aviso")
	p.combat.health = 100.0
	p.combat.invulnerable = 0.0
	mage._begin_attack()
	check(mage._attack_kind == "beam", "tercer patrón es rayo continuo")
	mage._execute_attack()
	check(mage.state == "channel" and mage._beam_visual != null, "canalización crea rayo visible")
	mage._choose_target()
	check(mage.state == "channel", "percepción no cancela canalización")
	mage._tick_beam(0.65)
	var first := 100.0 - p.combat.health
	check(first > 0.0 and p.combat.movement_factor() == 0.55, "rayo enlazado daña y ralentiza")
	p.combat.invulnerable = 0.0
	var before := p.combat.health
	mage._tick_beam(0.65)
	check(before - p.combat.health > first, "daño aumenta mientras enlace se mantiene")
	p.global_position = Vector3(8, 0.1, 0)
	await frames(2)
	mage._tick_beam(0.01)
	check(mage._beam_link_seconds == 0.0, "desplazamiento lateral rompe enlace y reinicia escalada")
	p.combat._process(0.81)
	check(p.combat.movement_factor() == 1.0, "ralentización expira tras romper enlace")
	mage.stun(1.5)
	check(mage.state == "stunned" and mage._beam_visual == null, "aturdir al mago interrumpe canalización y limpia efecto")
	p.global_position = Vector3(-6, 0.1, -10)
	mage.global_position = Vector3(-6, 0.1, -14)
	await frames(3)
	mage._attack_kind = "beam"
	mage._execute_attack()
	p.combat.invulnerable = 0.0
	before = p.combat.health
	mage._tick_beam(0.65)
	check(p.combat.health == before and mage._beam_link_seconds == 0.0, "pared bloquea rayo y daño")
	mage._begin_recovery()
	p.global_position = Vector3(0, 0.1, 0)
	mage.global_position = Vector3(0, 0.1, -6)
	p.rotation = Vector3.ZERO
	await frames(3)
	mage._attack_kind = "beam"
	mage._execute_attack()
	p.equipment["offhand"] = "wooden_shield"
	p.combat._cooldown = 0.0
	p.combat.set_blocking(true)
	p.combat._block_time = 1.0
	p.combat.stamina = 100.0
	before = p.combat.health
	mage._tick_beam(0.65)
	check(p.combat.health == before and p.combat.stamina < 100.0 and p.combat.movement_factor() == 1.0, "escudo evita daño y ralentización del rayo consumiendo resistencia")
	p.combat.set_blocking(false)
	mage._begin_recovery()
	mage._attack_count = 1
	mage._begin_attack()
	mage.take_damage(1.0, p)
	check(mage.state == "stagger" and mage._telegraph == null, "golpear mago interrumpe descarga antes de caer")
	# Cubierta real sobre jugador: descarga no atraviesa techo.
	arena._box(Vector3(0, 3, 0), Vector3(4, 0.3, 4), Color.GRAY)
	await frames(2)
	mage._attack_count = 1
	mage._begin_attack()
	p.combat.invulnerable = 0.0
	before = p.combat.health
	mage._execute_attack()
	check(p.combat.health == before, "techo bloquea descarga vertical")
	print("TOTAL: %d fallos" % failures)
	quit(1 if failures else 0)
