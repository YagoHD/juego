extends SceneTree
## Pruebas de comportamiento real y regresión de mochila, sin tocar la partida de la isla.
var failures := 0
var arena: Node3D
var player: Player

func _init() -> void:
	Engine.max_fps = 120
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	print(("OK: " if condition else "FALLO: ") + message)
	if not condition:
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func actor(id: String, at: Vector3) -> CreatureActor:
	var creature: CreatureActor = arena.spawn_creature(id, at)
	creature.set_physics_process(false)
	creature.drop_loot = false
	return creature

func _run() -> void:
	arena = load("res://scenes/combat_arena.tscn").instantiate()
	arena.set("save_path", "user://combat_arena_test.json")
	root.add_child(arena)
	player = arena.player
	await frames(12)
	for node in get_nodes_in_group("creatures"):
		node.free()
	for node in get_nodes_in_group("death_backpacks"):
		node.free()
	player.set_physics_process(false)
	player._waiting_for_ground = false
	player.global_position = Vector3(0, 0.1, 0)
	player.set_spawn_point(player.global_position)
	player.set_creative(false)
	player.combat.invulnerable = 0.0
	player.combat.health = 100.0
	check(CreatureDB.ENEMIES.size() == 6 and CreatureDB.ANIMALS.size() == 12, "seis enemigos y doce especies")
	for id in CreatureDB.ENEMIES + CreatureDB.ANIMALS:
		var c := actor(id, Vector3(38, 0.1, 30))
		check(c.health > 0.0 and c.get_node_or_null("Visual") != null, "perfil y cuerpo de " + id)
		for stack in CreatureDB.roll_loot(id, RandomNumberGenerator.new()):
			check(ItemDB.exists(stack["id"]), "botín registrado " + stack["id"])
		c.free()
	var tracker := actor("tracker", Vector3(0, 0.1, -1.3))
	await frames(2)
	tracker._choose_target()
	check(tracker.target == player and tracker.state == "chase", "rastreador detecta al jugador visible")
	tracker._begin_attack()
	check(player.combat.health == 100.0 and tracker.state == "windup", "aviso antes de hacer daño")
	tracker._execute_attack()
	check(player.combat.health == 91.0, "golpe aplica daño configurado")
	tracker._execute_attack()
	check(player.combat.health == 91.0, "inmunidad breve evita daño doble en el mismo instante")
	tracker.free()
	player.needs.hunger = 0.0
	player.combat.health = 100.0
	player.combat.invulnerable = 0.0
	var walking := actor("tracker", Vector3(0, 0.1, -4))
	walking.look_at(player.global_position)
	walking.set_physics_process(true)
	await frames(140)
	walking.set_physics_process(false)
	check(walking.global_position.distance_to(walking.home) > 1.0 and player.combat.health < 100.0, "IA en física persigue, camina y completa ataque anunciado")
	walking.home = Vector3(40, 0.1, 0)
	walking._set_state("chase")
	walking._choose_target()
	check(walking.state == "return" and walking.target == null, "límite de persecución devuelve enemigo a su zona")
	walking.free()
	var wall := actor("tracker", Vector3(-6, 0.1, -14))
	player.global_position = Vector3(-6, 0.1, -10)
	await frames(2)
	wall._choose_target()
	check(wall.target == null and not wall.can_see(player), "pared bloquea percepción")
	wall.free()
	player.global_position = Vector3(0, 0.1, 0)
	var pig := actor("pig", Vector3(0, 0.1, -2))
	await frames(2)
	pig._choose_target()
	check(pig.state == "flee", "cerdo huye de una persona cercana")
	pig.take_damage(1.0, player)
	check(pig.state == "flee", "animal tímido no contraataca")
	pig.free()
	var cow := actor("cow", Vector3(0, 0.1, -2))
	cow.take_damage(1.0, player)
	check(cow.target == player and cow.state == "stagger", "vaca se defiende al recibir daño")
	cow.free()
	var boar := actor("boar", Vector3(0, 0.1, -1.2))
	boar.target = player
	boar._begin_attack()
	boar._execute_attack()
	check(boar.state == "charge", "jabalí tiene carga después del aviso")
	boar.free()
	var wolf := actor("wolf", Vector3(0, 0.1, -4))
	var prey := actor("rabbit", Vector3(1, 0.1, -5))
	await frames(2)
	wolf._choose_target()
	check(wolf.target == prey, "depredador caza presas")
	wolf.free()
	prey.free()
	var cat := actor("cat", Vector3(20, 0.1, 10))
	cat.hour = 12.0
	cat._choose_routine()
	check(cat.state == "rest", "gato nocturno descansa de día")
	cat.free()
	var captain := actor("captain", Vector3(0, 0.1, -2))
	captain.target = player
	captain._begin_attack()
	check(captain._combo_left == 1, "capitán prepara dos golpes")
	captain.free()
	var boss := actor("tower_guardian", Vector3(0, 0.1, -3))
	boss.target = player
	boss._begin_attack()
	check(is_instance_valid(boss._telegraph), "jefe muestra zona del golpe")
	player.global_position.x = 5.0
	player.combat.invulnerable = 0.0
	var old_hp := player.combat.health
	boss._execute_attack()
	check(player.combat.health == old_hp, "salir de la zona evita el golpe del jefe")
	boss.health = 150.0
	boss._begin_attack()
	check(boss._attack_kind == "bolt", "jefe cambia patrón por debajo de media vida")
	boss.free()
	var mage := actor("mage", Vector3(-6, 0.1, -14))
	player.global_position = Vector3(-6, 0.1, -10)
	player.needs.hunger = 0.0  # evita que la regeneración cambie la vida durante este chequeo
	var projectile_hp := player.combat.health
	var bolt := CreatureProjectile.launch(arena, mage, mage.eye_position(), player.eye_position(), 14.0)
	await frames(60)
	check(not is_instance_valid(bolt) and player.combat.health == projectile_hp, "proyectil se destruye contra pared sin dañar detrás")
	mage.free()
	player.global_position = Vector3(0, 0.1, 0)
	player.rotation = Vector3.ZERO
	player._pitch = 0.0
	player._head.rotation = Vector3.ZERO
	player._spring.basis = Basis.IDENTITY
	player.inventory.clear()
	player.inventory.set_slot(0, {"id": "spear", "count": 1, "dur": 17})
	player._select_slot(0)
	var victim := actor("soldier", Vector3(0, 0.1, -1.8))
	await frames(4)
	player.combat._cooldown = 0.0
	player.combat.stamina = 100.0
	check(player.combat.try_attack() and victim.health < 85.0, "clic de combate alcanza criatura apuntada")
	var victim_hp := victim.health
	check(player.combat.try_attack() and victim.health == victim_hp, "cooldown impide golpes por spam")
	check(int(player.inventory.get_slot(0)["dur"]) == 16, "golpe desgasta herramienta una sola vez")
	victim.free()
	var snake := actor("snake", Vector3(0, 0.1, -1))
	player.combat.invulnerable = 0.0
	snake._hit_target(player)
	check(player.combat._poison == 6.0, "mordedura aplica veneno")
	snake.free()
	# Muerte: posición original, equipo e inventario con desgaste; recoger desde otro lugar.
	player.inventory.clear()
	player.set_equipment({"shirt": "shirt", "backpack": "backpack"})
	player.inventory.set_slot(0, {"id": "stone_axe", "count": 1, "dur": 13})
	player.inventory.set_slot(9, {"id": "hide", "count": 7})
	player.global_position = Vector3(4, 0.1, 5)
	player.combat.invulnerable = 0.0
	player.combat.take_damage(1000.0, player.global_position)
	await frames(2)
	var bags := get_nodes_in_group("death_backpacks")
	check(bags.size() == 1 and player.inventory.count_of("hide") == 0 and player.equipment["backpack"] == "", "morir vacía inventario y equipo en una mochila")
	check(player.global_position.distance_to(player.get_spawn_point()) < 1.0, "reaparece en punto de descanso")
	var bag := bags[0] as DeathBackpack
	check(Vector2(bag.global_position.x - 4.0, bag.global_position.z - 5.0).length() < 0.1, "mochila permanece en lugar de muerte")
	# JSON real y recarga de arena (mismo camino usado al cerrar/reabrir).
	arena.save()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(arena.save_path))
	check(saved["bags"].size() == 1 and saved["equipment"]["backpack"] == "", "guardado conserva mochila y jugador separado")
	bag.free()
	check(arena._load(), "carga del archivo de arena")
	bag = get_nodes_in_group("death_backpacks")[0] as DeathBackpack
	bag.recover(player)
	check(player.inventory.count_of("hide") == 7 and player.equipment["backpack"] == "backpack", "recuperación devuelve equipo y materiales")
	var axe_dur := 0
	for stack in player.inventory.to_data():
		if stack.get("id", "") == "stone_axe":
			axe_dur = int(stack["dur"])
	check(axe_dur == 13, "recuperación conserva desgaste exacto")
	await frames(2)
	check(get_nodes_in_group("death_backpacks").is_empty(), "mochila vacía se elimina")
	var partial := DeathBackpack.new()
	partial.contents = [{"id": "hide", "count": 9}]
	arena.add_child(partial)
	for index in player.unlocked_slots():
		player.inventory.set_slot(index, {"id": "stone", "count": 64})
	check(not partial.recover(player) and int(partial.contents[0]["count"]) == 9, "inventario lleno no pierde botín de la mochila")
	player.inventory.set_slot(0, {"id": "hide", "count": 30})
	partial.recover(player)
	check(int(player.inventory.get_slot(0)["count"]) == 32 and int(partial.contents[0]["count"]) == 7, "recogida parcial conserva sobrante")
	partial.free()
	# Botín una vez aunque un mismo cuerpo reciba varios daños mortales.
	var dying := actor("pig", Vector3(20, 0.1, 20))
	dying.drop_loot = true
	var before := get_nodes_in_group("item_drops").size()
	dying.take_damage(1000.0, player)
	var after := get_nodes_in_group("item_drops").size()
	dying.take_damage(1000.0, player)
	check(after > before and get_nodes_in_group("item_drops").size() == after, "muerte entrega botín una única vez")
	await frames(2)
	check(Needs.is_food("cooked_meat") and Campfire.COOKS["raw_meat"] == "cooked_meat", "carne integrada con cocina y hambre")
	print("TOTAL: %d fallos" % failures)
	quit(1 if failures > 0 else 0)
