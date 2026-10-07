extends Node
## Coordinación independiente del modelo. La ruta es compartida; no comparte percepción omnisciente.
var members: Array[CreatureActor] = []
var points: Array[Vector3] = []
var waypoint := 0
var travel_direction := 1
var rest_seconds := 0.0
var rest_duration := 5.0
var _order_cooldown := 0.0
var _magic_cooldown := 0.0
var _pulse := 0.0
var initial_size := 0       # miembros al formarse (para la moral)
var enraged := false        # murió el capitán y juraron venganza: más daño, menos defensa
var routed := false         # el grupo se ha roto (huyen o se rinden)

func _ready() -> void:
	add_to_group("enemy_squads")

func add_member(actor: CreatureActor) -> void:
	members.append(actor)
	actor.squad = self
	actor.squad_slot = members.size() - 1
	initial_size = maxi(initial_size, members.size())
	actor.died.connect(_on_member_died)


## Último grito del capitán y moral del grupo.
func _on_member_died(fallen: CreatureActor) -> void:
	var alive := living().filter(func(a: CreatureActor) -> bool: return a != fallen)
	if alive.is_empty():
		return
	var player: Player = fallen.player
	if fallen.species == "captain":
		if alive.size() <= 2:
			_rout(alive, player, "¡Ha caído su capitán: huyen!")
			return
		enraged = true
		for ally: CreatureActor in alive:
			ally.vulnerable = 1.2
			ally.fury = maxf(ally.fury, 10.0)
		if is_instance_valid(player):
			player.notice.emit("¡Ha caído su capitán! Los demás atacan con furia, pero se descuidan.")
		return
	# Moral: con la mitad del grupo caído, la gente corriente (sin máscara) se rinde o huye.
	if not routed and initial_size > 0 and alive.size() * 2 <= initial_size \
			and not alive.any(func(a: CreatureActor) -> bool: return a.species == "captain"):
		_rout(alive, player, "")


func _rout(alive: Array, player: Player, text: String) -> void:
	routed = true
	var any := false
	for ally: CreatureActor in alive:
		if ally.species == "tracker":
			ally.surrender()
			any = true
		elif ally.species in ["soldier", "archer"]:
			ally.target = player
			ally._aggro = 8.0
			ally._set_state("flee")
			any = true
		# Los enmascarados (magos, capitanes) no se rinden nunca.
	if any and is_instance_valid(player):
		player.notice.emit(text if text != "" else "El grupo se rompe: unos se rinden y otros huyen.")

func living() -> Array[CreatureActor]:
	var result: Array[CreatureActor] = []
	for actor in members:
		if is_instance_valid(actor) and not actor.dead and not actor.is_queued_for_deletion():
			result.append(actor)
	return result

func destination(actor: CreatureActor) -> Vector3:
	if points.is_empty():
		return actor.home
	var offset := Vector3((actor.squad_slot % 3 - 1) * 1.2, 0, (actor.squad_slot / 3) * 1.2)
	return points[waypoint] + offset

func request_attack(actor: CreatureActor) -> bool:
	if _order_cooldown > 0.0:
		return false
	var attackers := 0
	for ally in living():
		if ally != actor and ally.state in ["windup", "charge", "channel"]:
			attackers += 1
	if attackers >= 2:
		return false
	_order_cooldown = 0.65
	return true

func _physics_process(delta: float) -> void:
	_order_cooldown = maxf(0.0, _order_cooldown - delta)
	_magic_cooldown = maxf(0.0, _magic_cooldown - delta)
	var alive := living()
	if alive.is_empty():
		queue_free()
		return
	var busy := false
	for actor in alive:
		if actor.state in ["chase", "search", "windup", "charge", "channel", "recover", "stunned", "stagger"]:
			busy = true
	if not busy and not points.is_empty():
		if rest_seconds > 0.0:
			rest_seconds = maxf(0.0, rest_seconds - delta)
			if rest_seconds == 0.0:
				advance_route()
		else:
			var arrived := true
			for actor in alive:
				if actor.global_position.distance_to(destination(actor)) > 1.2:
					arrived = false
			if arrived:
				rest_seconds = rest_duration
	_pulse -= delta
	if _pulse > 0.0:
		return
	_pulse = 0.25
	_heal_captain(alive)
	for actor in alive:
		actor.team_damage = 1.3 if enraged else 1.0
		actor.team_shield = 0.0
		actor.team_role = "Furia" if enraged else ""
		actor.shield_wall = false
		# Muro de escudos: dos soldados juntos y peleando forman una línea que para lo de frente.
		if actor.species == "soldier" and actor.state in ["chase", "windup", "recover"]:
			for ally in alive:
				if ally != actor and ally.species == "soldier" and ally.state in ["chase", "windup", "recover"] \
						and ally.global_position.distance_to(actor.global_position) < 2.5:
					actor.shield_wall = true
					actor.team_role = "Muro de escudos"
		for ally in alive:
			if ally == actor or ally.global_position.distance_to(actor.global_position) > 8.0 or ally.state in ["stunned", "stagger"] or not actor.can_see(ally):
				continue
			if ally.species == "captain":
				actor.team_damage = 1.2
				actor.team_role = "Inspirado"
			if ally.species == "soldier" and actor.species in ["archer", "mage"] and ally.global_position.distance_to(actor.global_position) < 3.0:
				actor.team_shield = 0.2
				actor.team_role = "Protegido"
			if ally.species == "mage" and actor.species == "archer" and actor.state == "chase" and _magic_cooldown <= 0.0:
				actor.enchanted_arrow = true
				_magic_cooldown = 8.0

## El mago cura al capitán herido (por debajo de la mitad): se queda quieto canalizando hasta
## dejarlo bien o hasta que le interrumpen (le pegan o se corta la línea de visión).
func _heal_captain(alive: Array[CreatureActor]) -> void:
	for captain in alive:
		if captain.species != "captain":
			continue
		var hp := float(captain.stats["hp"])
		for mage in alive:
			if mage.species != "mage":
				continue
			if mage.state == "heal":
				if mage.healing != captain or captain.health >= hp * 0.8 or not mage.can_see(captain):
					mage.healing = null
					mage._set_state("chase" if mage._target_valid() else "return")
				else:
					captain.health = minf(hp, captain.health + 6.0 * 0.25)
					mage.team_role = "Curando al capitán"
				continue
			if captain.health < hp * 0.5 and mage.global_position.distance_to(captain.global_position) < 10.0 \
					and mage.state not in ["windup", "charge", "channel", "recover", "stunned", "stagger"] and mage.can_see(captain):
				mage.healing = captain
				mage._set_state("heal")


func advance_route() -> void:
	if points.size() < 2:
		return
	if waypoint == points.size() - 1:
		travel_direction = -1
	elif waypoint == 0:
		travel_direction = 1
	waypoint += travel_direction

func to_data() -> Dictionary:
	var route: Array = []
	for p in points:
		route.append([p.x, p.y, p.z])
	return {"points": route, "waypoint": waypoint, "direction": travel_direction, "rest": rest_seconds, "rest_duration": rest_duration}

func from_data(data: Dictionary) -> void:
	for p in data.get("points", []):
		points.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	waypoint = clampi(int(data.get("waypoint", 0)), 0, maxi(0, points.size() - 1))
	travel_direction = -1 if int(data.get("direction", 1)) < 0 else 1
	rest_seconds = clampf(float(data.get("rest", 0.0)), 0.0, 10.0)
	rest_duration = clampf(float(data.get("rest_duration", 5.0)), 2.0, 10.0)
