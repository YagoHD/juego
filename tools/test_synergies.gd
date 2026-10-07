extends SceneTree
## Prueba de las sinergias entre enemigos (docs/PATRULLAS_Y_SINERGIAS.md): marca del rastreador,
## muro de escudos, el mago cura al capitán, último grito, venganza, moral, cuerno de alarma,
## relevo de guardia, cadena de mando, hoguera, ritual que protege al jefe y runas.
const Squad = preload("res://scripts/creatures/enemy_squad.gd")
const Director = preload("res://scripts/world/tower_director.gd")
var failures := 0
var arena


func _init() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	print(("OK: " if ok else "FALLO: ") + message)
	if not ok:
		failures += 1


func clear() -> void:
	for node in get_nodes_in_group("enemy_squads"):
		node.free()
	for node in get_nodes_in_group("creatures"):
		node.free()


func spawn(id: String, at: Vector3, face := Vector3.ZERO) -> CreatureActor:
	var actor: CreatureActor = arena.spawn_creature(id, at)
	actor.set_physics_process(false)
	actor.drop_loot = false
	if face != Vector3.ZERO:
		actor.look_at(at + face, Vector3.UP)
	return actor


func squad_of(actors: Array) -> Node:
	var group = Squad.new()
	arena.add_child(group)
	group.set_physics_process(false)
	for actor in actors:
		group.add_member(actor)
	return group


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://synergy_tests.json"))  # sin restos de otra vez
	arena = load("res://scenes/combat_arena.tscn").instantiate()
	arena.save_path = "user://synergy_tests.json"
	root.add_child(arena)
	for i in 12:
		await physics_frame
	var player: Player = arena.player
	player.set_creative(false)
	player.combat.health = PlayerCombat.MAX_HEALTH
	player.combat.invulnerable = 0.0
	clear()
	await physics_frame

	# 1. Marca del rastreador.
	CreatureActor.clear_mark()
	var tracker := spawn("tracker", Vector3(0, 0.1, -20), Vector3(0, 0, 1))
	var archer := spawn("archer", Vector3(3, 0.1, -40), Vector3(0, 0, 1))
	player.global_position = Vector3(0, 0.1, -15)
	await physics_frame
	var far_before := archer.detects_player()  # a 25 m: fuera de su vista (17)
	tracker._choose_enemy_target()
	var marked := CreatureActor.player_marked()
	var far_after := archer.detects_player()
	check(marked and not far_before and far_after, "rastreador marca: el arquero te ve desde más lejos (%s %s %s)" % [marked, far_before, far_after])
	CreatureActor.clear_mark()
	clear()
	await physics_frame

	# 2. Muro de escudos.
	var s1 := spawn("soldier", Vector3(0, 0.1, -20), Vector3(0, 0, 1))
	var s2 := spawn("soldier", Vector3(1.5, 0.1, -20), Vector3(0, 0, 1))
	var wall_squad := squad_of([s1, s2])
	s1._set_state("chase")
	s2._set_state("chase")
	wall_squad._pulse = 0.0
	wall_squad._physics_process(0.25)
	player.global_position = Vector3(0, 0.1, -17)  # delante
	var hp := s1.health
	s1.take_damage(20.0, player)
	var front := hp - s1.health
	player.global_position = Vector3(0, 0.1, -23)  # detrás
	hp = s1.health
	s1.take_damage(20.0, player)
	var back := hp - s1.health
	check(s1.shield_wall and front < back * 0.5, "muro de escudos: de frente entra mucho menos (%.1f vs %.1f)" % [front, back])
	clear()
	await physics_frame

	# 3. El mago cura al capitán.
	var captain := spawn("captain", Vector3(0, 0.1, -20))
	var mage := spawn("mage", Vector3(3, 0.1, -20))
	var heal_squad := squad_of([captain, mage])
	captain.health = 50.0
	heal_squad._pulse = 0.0
	heal_squad._physics_process(0.25)
	heal_squad._pulse = 0.0
	heal_squad._physics_process(0.25)
	check(mage.state == "heal" and captain.health > 50.0, "el mago cura al capitán herido (%s, %.1f)" % [mage.state, captain.health])
	mage.take_damage(1.0, player)
	heal_squad._pulse = 0.0
	heal_squad._physics_process(0.25)
	check(mage.healing == null, "pegarle interrumpe la curación")
	clear()
	await physics_frame

	# 4. Último grito del capitán (grupo grande: furia; grupo pequeño: huyen).
	var cap := spawn("captain", Vector3(0, 0.1, -20))
	var big := [cap, spawn("soldier", Vector3(2, 0.1, -20)), spawn("soldier", Vector3(-2, 0.1, -20)), spawn("tracker", Vector3(0, 0.1, -22))]
	var big_squad := squad_of(big)
	cap.take_damage(10000.0, player)
	await physics_frame
	check(big_squad.enraged and big[1].vulnerable > 1.0 and big[1].fury > 0.0, "al caer el capitán, los demás atacan con furia y se descuidan")
	clear()
	await physics_frame
	var cap2 := spawn("captain", Vector3(0, 0.1, -20))
	var tr2 := spawn("tracker", Vector3(2, 0.1, -20))
	var so2 := spawn("soldier", Vector3(-2, 0.1, -20))
	squad_of([cap2, tr2, so2])
	cap2.take_damage(10000.0, player)
	await physics_frame
	check(tr2.surrendered and so2.state == "flee", "grupo pequeño sin capitán: el rastreador se rinde y el soldado huye")
	clear()
	await physics_frame

	# 5. Venganza (quien lo ve se enfurece) y 12. moral sin capitán.
	var a := spawn("tracker", Vector3(0, 0.1, -20))
	var b := spawn("tracker", Vector3(3, 0.1, -20))
	var c := spawn("soldier", Vector3(-3, 0.1, -20))
	var d := spawn("soldier", Vector3(0, 0.1, -23))
	squad_of([a, b, c, d])
	c.take_damage(10000.0, player)
	await physics_frame
	check(a.fury > 0.0 and b.fury > 0.0, "venganza: los que lo ven morir se enfurecen")
	d.take_damage(10000.0, player)
	await physics_frame
	check(a.surrendered and b.surrendered, "moral: con la mitad caída, los rastreadores se rinden")
	b.take_damage(1.0, player)
	check(not b.surrendered and b.state == "flee", "si atacas a un rendido, huye")
	clear()
	await physics_frame

	# 6. Cuerno de alarma y 7. relevo de guardia.
	var sentry := spawn("archer", Vector3(0, 0.1, -20), Vector3(0, 0, 1))
	sentry.post = {"role": "sentry", "point": sentry.global_position, "facing": PI / 2.0, "hold": true, "spots": []}
	var camper := spawn("soldier", Vector3(25, 0.1, -30))
	camper.post = {"role": "camp", "point": camper.global_position, "focus": camper.global_position + Vector3(2, 0, 0), "spots": []}
	camper._set_state("sleep")
	player.global_position = Vector3(0, 0.1, -12)
	sentry._choose_enemy_target()
	check(camper.state == "search" and camper.alert_seconds > 0.0, "el vigía toca el cuerno: el campamento despierta y busca")
	sentry.hour = 6.2
	sentry._set_state("idle")
	sentry._post_routine()
	check(sentry.state == "relief" and not sentry.visible and not sentry.detects_player(), "relevo de guardia al amanecer: la torre queda vacía")
	sentry.hour = 12.0
	sentry._post_routine()
	check(sentry.state == "watch" and sentry.visible, "acabado el relevo vuelve a vigilar")
	clear()
	await physics_frame

	# 11. Runas: el mago siente la armadura antigua aunque estés a su espalda.
	var rune_mage := spawn("mage", Vector3(0, 0.1, -20), Vector3(0, 0, -1))
	player.global_position = Vector3(0, 0.1, -12)  # detrás de él, a 8 m
	player.equipment["head"] = ""
	var plain := rune_mage.detects_player()
	player.equipment["head"] = "ancient_helm"
	var runes := rune_mage.detects_player()
	player.equipment["head"] = ""
	check(not plain and runes, "el mago siente las runas de la armadura antigua a su espalda")
	clear()
	await physics_frame

	# Guarnición: 8. ritual, 9. cadena de mando y 10. hoguera.
	var tower = Director.new()
	tower.player = player
	tower.center = Vector3(30, 0.1, -35)
	tower.set_physics_process(false)
	var clock := DayNight.new()
	clock.day = 1
	clock.hour = 22.0
	tower.clock = clock
	arena.add_child(tower)
	tower.advance_to_day(3)
	check(is_equal_approx(tower.ritual_strength(), 1.0), "ritual completo protege al jefe del todo")
	var ritual_ids: Array = []
	for id in tower._records:
		if tower._records[id]["post"].get("role", "") == "ritual":
			ritual_ids.append(id)
	tower._records[ritual_ids[0]]["dead"] = true
	check(tower.ritual_strength() < 1.0 and tower.ritual_strength() > 0.0, "cada mago muerto debilita el escudo")
	for id in ritual_ids:
		tower._records[id]["dead"] = true
	check(tower.ritual_strength() == 0.0, "sin magos no hay escudo")
	# Hoguera: de noche, lo que queda a oscuras apenas se ve; apagarla despierta al campamento.
	var fire: EnemyFire = tower._fires.values()[0]
	check(tower.fire_dark(fire.global_position, fire.global_position + Vector3(10, 0, 0))
		and not tower.fire_dark(fire.global_position, fire.global_position + Vector3(3, 0, 0)), "hoguera: a oscuras a 10 m, iluminado a 3 m")
	var camp_id := ""
	for id in tower._records:
		var post: Dictionary = tower._records[id]["post"]
		if post.get("role", "") == "camp" and Vector3(post["focus"][0], post["focus"][1], post["focus"][2]).distance_to(fire.global_position) < 1.0:
			camp_id = id
	tower._spawn(camp_id)
	var sleeper: CreatureActor = tower._actors[camp_id]
	sleeper._set_state("sleep")
	fire.put_out()
	check(not fire.lit and sleeper.state == "search" and tower.to_data()["fires_out"].has(fire.camp_id), "apagar la hoguera despierta al campamento y se guarda")
	clock.day = 2
	tower._check = 0.0
	tower._physics_process(0.31)
	check(fire.lit, "al día siguiente vuelve a arder")
	# Cadena de mando: si cae una patrulla entera, el campamento está en guardia.
	check(not tower.is_vigilant(), "sin bajas, el campamento duerme tranquilo")
	var patrol := ""
	for id in tower._records:
		if str(tower._records[id]["group"]).contains("patrol"):
			patrol = str(tower._records[id]["group"])
	for id in tower._records:
		if tower._records[id]["group"] == patrol:
			tower._spawn(id)
			(tower._actors[id] as CreatureActor).drop_loot = false
			(tower._actors[id] as CreatureActor).take_damage(10000.0, null)
	await physics_frame
	check(tower.is_vigilant(), "cadena de mando: una patrulla no vuelve y el campamento se pone en guardia")
	clock.free()
	print("TOTAL: %d fallos" % failures)
	print("OK" if failures == 0 else "FALLOS")
	quit(1 if failures else 0)
