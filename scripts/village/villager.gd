extends CreatureActor
class_name Villager
## Vecino o guardia de un pueblo. Reutiliza el cuerpo, la vida, el movimiento y el combate de
## CreatureActor, pero en vez de patrullar o pastar sigue su horario (lo decide el pueblo según su
## oficio y la hora) y reacciona según la ley del pueblo: los civiles huyen de la violencia; los
## guardias cobran multas y atacan a quien la ley señala. Figura provisional (bola de color).

var village: Node            # el pueblo (Village)
var villager_id := ""
var villager_name := ""
var job := ""
var activity := ""           # lo que hace ahora, para la etiqueta
var _alarm_seen := Vector3.INF   # el último aviso del pueblo al que ha acudido (guardias)
var _bark := ""                  # frase suelta que dice ahora (sobre la cabeza)
var _bark_left := 0.0
var _bark_cooldown := 0.0


func _ready() -> void:
	super._ready()
	drop_loot = species == "guard"
	_set_state("idle")


func _physics_process(delta: float) -> void:
	_bark_left = maxf(0.0, _bark_left - delta)
	_bark_cooldown = maxf(0.0, _bark_cooldown - delta)
	if state == "talk" and not dead:
		# Hablando con el jugador: quieto y mirándole.
		if is_instance_valid(player):
			_face(player.global_position - global_position, delta)
		velocity = Vector3.ZERO
		_update_label()
		return
	if not dead and state in ["idle", "feed", "rest"] and is_on_floor() and _knockback == Vector3.ZERO:
		_still(delta)
		return
	if state == "report" and not dead:
		_run_to_guard(delta)
		return
	if state != "confront" or dead:
		super._physics_process(delta)
		return
	# Cobrar la multa: se acerca al jugador y espera a su lado.
	if not is_instance_valid(player) or not player.is_on_ground_ready():
		return
	_decision -= delta
	if _decision <= 0.0:
		_decision = 0.2
		_choose_target()
	var offset := player.global_position - global_position
	offset.y = 0.0
	_move(offset if offset.length() > 2.2 else Vector3.ZERO, float(stats["speed"]) * 1.5, delta)  # a paso ligero
	_face(offset, delta)
	_update_label()


## Testigo de un delito: corre al guardia más cercano a denunciarlo (se le puede impedir).
func start_report() -> void:
	if dead or species == "guard":
		return
	target = null
	_set_state("report")


func _run_to_guard(delta: float) -> void:
	if is_instance_valid(player) and not player.is_on_ground_ready():
		return
	_timer -= delta
	var guard: Villager = village.nearest_guard(global_position)
	if guard == null:
		_set_state("return")  # no queda ningún guardia a quien avisar
		return
	var offset := guard.global_position - global_position
	offset.y = 0.0
	if offset.length() < 2.5:
		village.reported(self)
		_set_state("return")
		return
	_move(offset, float(stats["speed"]) * 1.8, delta)
	_face(offset, delta)
	_update_label()


## Quieto en el suelo (durmiendo, trabajando, charlando): sin calcular movimiento ni física,
## solo los relojes y, cinco veces por segundo, mirar alrededor. Es lo que más ahorra con muchos.
func _still(delta: float) -> void:
	if is_instance_valid(player) and not player.is_on_ground_ready():
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_aggro = maxf(0.0, _aggro - delta)
	_flash = maxf(0.0, _flash - delta)
	_timer -= delta
	_decision -= delta
	if _decision <= 0.0:
		_decision = 0.2
		_choose_target()
		_update_label()
	if state in ["idle", "feed", "rest"] and _timer <= 0.0:
		_choose_routine()
	velocity = Vector3.ZERO


## Rutina: ir al sitio que le toca a esta hora y, allí, pasear entre puntos o quedarse haciendo
## lo suyo (como el "sandbox" de Skyrim), o dormir.
func _choose_routine() -> void:
	if village == null:
		super._choose_routine()
		return
	var plan: Dictionary = village.plan_for(self)
	activity = plan["activity"]
	var point: Vector3 = plan["point"]
	var spread := float(plan["radius"])
	if global_position.distance_to(point) > spread + 1.0:
		home = point
		_set_state("return")
		return
	if plan["sleep"]:
		_set_state("rest")
		_timer = 6.0
		return
	if _rng.randf() < 0.45:
		_set_state("feed")  # quieto, trabajando o charlando
		_timer = _rng.randf_range(3.0, 7.0)
		return
	var angle := _rng.randf() * TAU
	_destination = point + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(0.0, spread)
	_set_state("roam")
	_timer = 8.0


func _choose_target() -> void:
	if village == null:
		super._choose_target()
		return
	if state in ["windup", "charge", "recover", "stagger", "stunned"]:
		return
	if species == "guard":
		_guard_think()
	else:
		_civilian_think()


func _civilian_think() -> void:
	if state in ["flee", "report"]:
		if _target_valid():
			_last_seen = target.global_position
		return
	# Miedo a quien la ley persigue, si está cerca y a la vista.
	if village.law.guards_attack() and _player_ok() and global_position.distance_to(player.global_position) < 10.0 and can_see(player):
		scare(3.0)


func _guard_think() -> void:
	if not _player_ok():
		_stand_down()
		return
	# Persiguen fuera del pueblo, pero no mucho; más lejos solo si le tienen muy cerca.
	var gap := global_position.distance_to(player.global_position)
	var in_reach: bool = village.contains(player.global_position, Village.CHASE_MARGIN) \
		or (target == player and gap < Village.CLOSE_CHASE and village.contains(player.global_position, Village.CHASE_LIMIT))
	if village.law.guards_attack() and in_reach:
		var close := global_position.distance_to(player.global_position) < float(stats["sense"])
		if target == player or (close and can_see(player)):
			target = player
			_last_seen = player.global_position
			_aggro = 5.0
			if state != "chase":
				_set_state("chase")
			return
		# Sin verle: a buscarle donde le vieron por última vez (nadie sabe dónde está tras una pared).
		var alarm: Vector3 = village.alarm_point
		if alarm.is_finite() and alarm != _alarm_seen:
			_alarm_seen = alarm
			_start_search(alarm)
			return
		if state == "search":
			return
	elif village.law.wants_payment() and village.collector() == self:
		target = null
		_set_state("confront")
		return
	_stand_down()


func _stand_down() -> void:
	if state in ["chase", "confront"]:
		target = null
		_set_state("return")


func _player_ok() -> bool:
	return is_instance_valid(player) and not player.creative and player.combat.health > 0.0


## Empieza o acaba una conversación con el jugador.
func start_talk() -> void:
	target = null
	_set_state("talk")


func end_talk() -> void:
	if state == "talk":
		_set_state("idle")
		_timer = 1.5


## Al pasar el jugador cerca, a veces dice una frase de su oficio (para que se note que viven).
func maybe_bark() -> void:
	if _bark_cooldown > 0.0 or not can_talk() or state == "talk" or activity.begins_with("Durmiendo"):
		return
	_bark_cooldown = _rng.randf_range(25.0, 45.0)
	var lines: Array = DialogueDB.BARKS.get(job, [])
	if lines.is_empty() or _rng.randf() > 0.6:
		return
	_bark = lines[_rng.randi() % lines.size()]
	_bark_left = 3.5
	_update_label()


## ¿Se puede hablar con él ahora? No si pelea, huye, corre a denunciar o la ley va a por el jugador.
func can_talk() -> bool:
	if dead or village == null or village.law.guards_attack():
		return false
	return state not in ["flee", "report", "chase", "windup", "charge", "recover", "stagger", "stunned", "search"]


## Huir del jugador unos segundos (al ver violencia o a un criminal).
func scare(seconds: float) -> void:
	if dead or species == "guard" or not _player_ok() or state == "report":
		return
	target = player
	_last_seen = player.global_position
	_aggro = maxf(_aggro, seconds)
	_set_state("flee")


func take_damage(amount: float, source: Node3D = null) -> void:
	var was_alive := not dead
	super.take_damage(amount, source)
	if village != null and was_alive and source is Player:
		village.report_attack(self, dead)


func _update_label() -> void:
	if _label == null:
		return
	var doing := activity
	match state:
		"flee": doing = "¡Huyendo!"
		"chase": doing = "¡A por ti!"
		"confront": doing = "Paga la multa: tecla R"
		"report": doing = "¡Corre a avisar a la guardia!"
		"talk": doing = "Hablando contigo"
		"return": doing = "De camino: " + activity.to_lower()
		"windup", "recover", "stagger", "stunned": doing = "Peleando"
	var text := "%s  %d/%d\n%s" % [villager_name, ceili(health), int(stats["hp"]), doing]
	if _bark_left > 0.0:
		text = "«%s»\n%s" % [_bark, text]
	if _label.text != text:  # cambiar el texto rehace la etiqueta: solo si cambia
		_label.text = text
