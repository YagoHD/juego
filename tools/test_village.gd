extends SceneTree
## Prueba de los vecinos, guardias y delitos en la aldea de pruebas, sin ventana.
## Uso: godot --headless --path . --script res://tools/test_village.gd
##   1. Hay más de 30 vecinos y, con el jugador en el pueblo, casi todos con IA completa.
##   2. Siguen su horario: a las 8, los granjeros van al campo.
##   3. Golpear a un vecino a la vista: multa y un guardia viene a cobrar; pagar la quita.
##   4. Matar a un vecino: muerte permanente y los guardias atacan.
##   5. Guardar y cargar: los muertos siguen muertos y la ley se acuerda.
##   6. Coste: tiempo de física con todos los vecinos.

const TEST_SAVE := "user://village_test_auto.json"
var _scene: Node3D
var _step := 0
var _wait := 0
var _farmer: Villager
var _start_distance := 0.0
var _physics_ms := 0.0
var _samples := 0
var _total := 0


func _init() -> void:
	Engine.max_fps = 60  # sin ventana iría a miles de fotogramas: las esperas serían de décimas
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	_scene = (load("res://scenes/village_test.tscn") as PackedScene).instantiate()
	_scene.set("save_path", TEST_SAVE)
	root.add_child(_scene)


func _check(text: String, ok: bool) -> void:
	print("%s: %s" % [text, "OK" if ok else "FALLO"])


func _villager(job_prefix: String) -> Villager:
	var village: Village = _scene.village
	for actor in village._actors.values():
		if is_instance_valid(actor) and not actor.dead and actor.job.begins_with(job_prefix):
			return actor
	return null


func _process(_delta: float) -> bool:
	var player: Player = _scene.player
	var village: Village = _scene.village
	if player == null or not player.is_on_ground_ready():
		return false
	_wait += 1
	match _step:
		0:
			if _wait < 30:
				return false
			_scene.time_running = false
			_scene.hour = 8.0
			_total = _scene.POPULATION.size()
			_check("Hay %d vecinos con oficios variados" % _total, village.records.size() == _total and _total >= 30 and village.living_count() == _total)
			_check("Cerca del jugador, IA completa (%d); lejos, simplificada" % village.active_count(), village.active_count() >= 5 and village.active_count() < _total)
			_farmer = _villager("farmer")
			_start_distance = _farmer.global_position.distance_to(village.places["field"]["point"])
			_step = 1
			_wait = 0
		1:
			_physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			_samples += 1
			if _wait < 600:
				return false
			var now := _farmer.global_position.distance_to(village.places["field"]["point"])
			_check("A las 8 el granjero va al campo (%.0f m -> %.0f m)" % [_start_distance, now], now < _start_distance - 3.0 or now < 8.0)
			var cost := _physics_ms / maxf(1.0, _samples)
			_check("Coste de física con todos los vecinos: %.2f ms por paso" % cost, cost < 20.0)  # orientativo: la nube es lenta y ruidosa
			# Golpear a un vecino delante de él.
			var victim := _villager("fisher")
			victim.global_position = Vector3(38, 0.2, -34)  # dentro del pueblo, sin guardias a la vista
			player.global_position = victim.global_position + Vector3(1.5, 0.2, 0)
			victim.take_damage(5.0, player)
			_check("Golpear a un vecino sin guardias delante: el testigo corre a avisar", victim.state == "report" and village.law.fine == 0.0 and village.pending.size() == 1)
			_step = 20
			_wait = 0
		20:
			if village.law.fine == 0.0 and _wait < 2400:
				return false
			_check("Al llegar el testigo junto a un guardia: multa (%d)" % village.law.fine, village.law.fine == VillageLaw.FINE_ASSAULT and village.law.wants_payment())
			_step = 2
			_wait = 0
		2:
			var guard := village.collector()
			if _wait < 2400 and (guard == null or guard.state != "confront" or guard.global_position.distance_to(player.global_position) > 3.0):
				return false
			_check("Un guardia viene a cobrar", guard != null and guard.state == "confront" and guard.global_position.distance_to(player.global_position) <= 3.0)
			_check("R junto al guardia abre la pantalla de pago", village.try_pay() and _scene._offer != null and _scene._inventory.visible)
			var offer: OfferPanel = _scene._offer
			var coins := player.inventory.count_of("gold_coin")
			offer.offer.set_slot(0, {"id": "gold_coin", "count": 4})
			offer._on_pressed()
			_check("Con 4 monedas no llega: sigue la multa", village.law.fine == VillageLaw.FINE_ASSAULT)
			offer.offer.set_slot(1, {"id": "rope", "count": 6})  # 4 + 6 x 1,5 = 13: sobra 3
			offer._on_pressed()
			_check("Pagar con monedas y objetos: multa saldada y 3 monedas de cambio", village.law.fine == 0.0 and player.inventory.count_of("gold_coin") == coins + 3 and not _scene._inventory.visible)
			_scene.open_offer("bank", "Olga")
			var bank: OfferPanel = _scene._offer
			bank.offer.set_slot(0, {"id": "gold_nugget", "count": 4})
			bank.offer.set_slot(1, {"id": "rope", "count": 2})
			var before_bank := player.inventory.count_of("gold_coin")
			var rope_before := player.inventory.count_of("rope")
			bank._on_pressed()
			_check("Banco: 4 pepitas dan 6 monedas (con pérdida) y devuelve lo que no es oro",
				player.inventory.count_of("gold_coin") == before_bank + 6 and player.inventory.count_of("rope") == rope_before + 2 and not _scene._inventory.visible)
			# Impedir la denuncia: el testigo muere antes de llegar a la guardia.
			player.global_position = Vector3(0, 0.3, 8)
			var witness := _villager("farmer")
			witness.global_position = Vector3(-30, 0.2, -40)  # otra esquina: el guardia que cobró sigue en la primera  # una esquina sin guardias a la vista
			player.global_position = witness.global_position + Vector3(1.5, 0.2, 0)
			witness.take_damage(5.0, player)
			var reporting := witness.state == "report"
			witness.take_damage(1000.0)  # sin culpable: no es otro delito
			_check("Si el testigo no llega, no hay multa", reporting and village.pending.is_empty() and village.law.fine == 0.0)
			# Matar a un vecino.
			var victim := _villager("merchant")
			player.global_position = victim.global_position + Vector3(1.5, 0.2, 0)
			var victim_id := victim.villager_id
			victim.take_damage(1000.0, player)
			_check("Matar: muerte permanente en su ficha", not village._record(victim_id)["alive"] and village.living_count() == _total - 2)
			_step = 30
			_wait = 0
		30:
			if not village.law.murderer and _wait < 2400:
				return false
			_check("Matar a la vista: cuando avisan, asesino", village.law.murderer and village.law.guards_attack())
			_step = 3
			_wait = 0
		3:
			var chasing := false
			for actor in village._actors.values():
				if is_instance_valid(actor) and actor.species == "guard" and actor.state in ["chase", "windup", "recover"]:
					chasing = true
			if not chasing and _wait < 2400:
				return false
			_check("Los guardias atacan al asesino", chasing)
			# Guardar y cargar en un pueblo nuevo.
			var data := village.to_data()
			var copy := Village.new()
			for record in village.records:
				copy.add_record(record["id"], record["name"], record["job"], Village._point(record["home"]))
			copy.from_data(JSON.parse_string(JSON.stringify(data)))
			_check("Al cargar, los muertos siguen muertos", copy.living_count() == _total - 2)
			_check("Al cargar, la ley se acuerda", copy.law.murderer)
			copy.free()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
			return true
	return false
