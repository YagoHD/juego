extends Node3D
class_name Village
## Un pueblo: sus vecinos (fichas persistentes), sus lugares, sus horarios y su ley.
## Niveles de detalle de la IA: cerca del jugador los vecinos piensan y se mueven con física;
## más lejos, sin física, van a paso de persona al sitio que les toca; muy lejos no existen como
## figura, solo su ficha. La muerte es permanente. Ver docs/VECINOS_Y_GUARDIAS.md.

signal notice(text: String)

const NEAR := 45.0            # metros: IA completa
const FAR := 90.0             # metros: más allá, solo la ficha
const WITNESS_RANGE := 18.0   # a qué distancia alguien ve un delito
const WALK := 1.2             # m/s de los vecinos simulados sin física
const PANIC_RANGE := 20.0
## Horarios por oficio: [hora de inicio, lugar, actividad]. "home" es la casa de cada uno;
## "patrol", la ronda de los guardias. Las actividades que empiezan por "Durmiendo" son dormir.
const SCHEDULES := {
	"farmer": [[6, "home", "Desayunando"], [7, "field", "Trabajando en el campo"], [12, "plaza", "Comiendo en la plaza"],
		[13, "field", "Trabajando en el campo"], [19, "plaza", "Charlando en la plaza"], [21, "home", "Durmiendo"]],
	"fisher": [[5, "home", "Desayunando"], [6, "dock", "Pescando en el muelle"], [12, "plaza", "Comiendo en la plaza"],
		[13, "dock", "Remendando redes"], [18, "plaza", "Charlando en la plaza"], [21, "home", "Durmiendo"]],
	"merchant": [[7, "home", "Desayunando"], [8, "market", "Vendiendo en el mercado"], [13, "plaza", "Comiendo en la plaza"],
		[14, "market", "Vendiendo en el mercado"], [19, "plaza", "Charlando en la plaza"], [22, "home", "Durmiendo"]],
	"guard_day": [[6, "barracks", "Preparándose"], [7, "patrol", "Patrullando"], [19, "barracks", "Descansando"],
		[22, "barracks", "Durmiendo"]],
	"guard_night": [[6, "barracks", "Durmiendo"], [14, "barracks", "Descansando"], [19, "patrol", "Patrullando de noche"]],
}
const JOB_NAMES := {"farmer": "granjero", "fisher": "pescador", "merchant": "mercader", "guard_day": "guardia", "guard_night": "guardia de noche"}

var player: Player
var hour := 12.0
var center := Vector3.ZERO
var radius := 35.0
var places := {}              # nombre -> {"point": Vector3, "radius": float}
var patrol: Array[Vector3] = []
var law := VillageLaw.new()
var records: Array = []       # fichas: {id, name, job, species, home, position, health, alive}
var _actors := {}             # id -> Villager
var _check := 0.0
var _collector_met := false   # el guardia que cobra ya llegó junto al jugador
var alarm_point := Vector3.INF  # dónde se vio por última vez al jugador perseguido por la ley


func _ready() -> void:
	law.changed.connect(func(text: String) -> void: notice.emit(text))


## Añade un vecino nuevo (al crear el pueblo). 'home' es dónde vive.
func add_record(id: String, name: String, job: String, home: Vector3) -> void:
	records.append({"id": id, "name": name, "job": job, "species": "guard" if job.begins_with("guard") else "villager",
		"home": _vec(home), "position": _vec(home), "health": -1.0, "alive": true})


func contains(point: Vector3, margin := 0.0) -> bool:
	return Vector2(point.x - center.x, point.z - center.z).length() <= radius + margin


func living_count() -> int:
	return records.filter(func(r: Dictionary) -> bool: return r["alive"]).size()


func active_count() -> int:
	var count := 0
	for actor in _actors.values():
		if is_instance_valid(actor) and actor.is_physics_processing():
			count += 1
	return count


## Qué le toca ahora a un vecino: lugar, punto, radio por el que pasea y actividad.
func plan_for(villager: Villager) -> Dictionary:
	return _plan(_record(villager.villager_id))


func _plan(record: Dictionary) -> Dictionary:
	var entries: Array = SCHEDULES.get(record["job"], SCHEDULES["farmer"])
	var current: Array = entries[entries.size() - 1]  # antes de la primera hora: lo último del día anterior
	for entry in entries:
		if hour >= float(entry[0]):
			current = entry
	var place := str(current[1])
	var activity := str(current[2])
	var point := _point(record["home"])
	var spread := 1.0
	if place == "patrol" and not patrol.is_empty():
		# Cada guardia en un punto de la ronda, avanzando con la hora.
		var step := int(hour * 4.0) + absi(hash(record["id"])) % patrol.size()
		point = patrol[step % patrol.size()]
		spread = 1.5
	elif places.has(place):
		point = places[place]["point"]
		spread = float(places[place]["radius"])
	return {"point": point, "radius": spread, "activity": activity, "sleep": activity.begins_with("Durmiendo")}


func _record(id: String) -> Dictionary:
	for record in records:
		if record["id"] == id:
			return record
	return {}


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not player.is_on_ground_ready():
		return
	_check -= delta
	if _check > 0.0:
		return
	var step := 0.25 - _check
	_check = 0.25
	for record in records:
		if not record["alive"]:
			continue
		var actor: Villager = _actors.get(record["id"])
		if actor != null and not is_instance_valid(actor):
			_actors.erase(record["id"])
			actor = null
		var position := actor.global_position if actor != null else _point(record["position"])
		var distance := player.global_position.distance_to(position)
		if distance < FAR:
			if actor == null:
				actor = _spawn(record)
			actor.hour = hour
			# Con una multa o un delito pendiente, los guardias piensan aunque estén lejos.
			var on_duty: bool = record["species"] == "guard" and (law.wants_payment() or law.guards_attack())
			var near := distance < NEAR or on_duty
			actor.set_physics_process(near)
			if not near:
				actor.global_position = _walk(record, actor.global_position, step)
			record["position"] = _vec(actor.global_position)
			record["health"] = actor.health
		else:
			if actor != null:
				record["health"] = actor.health
				actor.queue_free()
				_actors.erase(record["id"])
			record["position"] = _vec(_walk(record, position, step))
	_watch_collector()
	if law.guards_attack() and witnessed():
		alarm_point = player.global_position  # alguien le ve: los guardias acuden ahí


## Vecino sin física: avanza hacia el sitio que le toca a paso de persona.
func _walk(record: Dictionary, from: Vector3, seconds: float) -> Vector3:
	var goal: Vector3 = _plan(record)["point"]
	return from.move_toward(goal, WALK * seconds)


func _spawn(record: Dictionary) -> Villager:
	var actor := Villager.new()
	actor.species = record["species"]
	actor.player = player
	actor.village = self
	actor.villager_id = record["id"]
	actor.villager_name = record["name"]
	actor.job = record["job"]
	actor.position = _point(record["position"])  # antes de add_child: su casa inicial es aquí
	add_child(actor)
	if float(record["health"]) > 0.0:
		actor.health = clampf(float(record["health"]), 1.0, float(actor.stats["hp"]))
	actor.died.connect(_on_died.bind(record["id"]))
	_actors[record["id"]] = actor
	return actor


func _on_died(_actor: CreatureActor, id: String) -> void:
	var record := _record(id)
	if not record.is_empty():
		record["alive"] = false
		record["health"] = 0.0
	_actors.erase(id)


## ¿Lo ve alguien? Cualquier vecino o guardia vivo cerca y con línea de visión al jugador.
func witnessed() -> bool:
	for actor in _actors.values():
		if is_instance_valid(actor) and not actor.dead and actor.global_position.distance_to(player.global_position) < WITNESS_RANGE and actor.can_see(player):
			return true
	return false


## El jugador ha golpeado (o matado) a un vecino o guardia.
func report_attack(victim: Villager, killed: bool) -> void:
	var seen := witnessed()
	if killed:
		if seen:
			law.murder()
	elif seen:
		law.assault(victim.species == "guard")
	if seen:
		alarm_point = player.global_position
	panic(player.global_position)


## El jugador ha roto o colocado un bloque en 'at'.
func report_block_edit(at: Vector3) -> void:
	if contains(at) and witnessed():
		law.block_edit()


## Los civiles que ven la violencia huyen.
func panic(at: Vector3) -> void:
	for actor in _actors.values():
		if is_instance_valid(actor) and not actor.dead and actor.species != "guard" and actor.global_position.distance_to(at) < PANIC_RANGE and actor.can_see(player):
			actor.scare(6.0)


## El guardia que va a cobrar la multa: el vivo más cercano al jugador.
func collector() -> Villager:
	var best: Villager = null
	for actor in _actors.values():
		if is_instance_valid(actor) and not actor.dead and actor.species == "guard":
			if best == null or actor.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
				best = actor
	return best


## Si el jugador se va sin pagar cuando el guardia ya le ha alcanzado, o sale del pueblo.
func _watch_collector() -> void:
	if not law.wants_payment():
		_collector_met = false
		return
	var guard := collector()
	if guard == null:
		return
	var distance := guard.global_position.distance_to(player.global_position)
	if distance < 4.0:
		_collector_met = true
	elif (_collector_met and distance > 20.0) or not contains(player.global_position, 20.0):
		law.refuse()
		_collector_met = false


## Pagar la multa junto a un guardia (tecla R).
func try_pay() -> bool:
	var guard := collector()
	if law.fine <= 0.0 or guard == null or guard.global_position.distance_to(player.global_position) > 3.5:
		return false
	return law.pay(player.active_inventory(), player.unlocked_slots())


func player_died() -> void:
	law.player_died()
	alarm_point = Vector3.INF


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if is_instance_valid(player) and not player.ui_open and try_pay():
			get_viewport().set_input_as_handled()


func to_data() -> Dictionary:
	for record in records:
		var actor: Villager = _actors.get(record["id"])
		if actor != null and is_instance_valid(actor) and not actor.dead:
			record["position"] = _vec(actor.global_position)
			record["health"] = actor.health
	return {"records": records.duplicate(true), "law": law.to_data()}


## Carga las fichas guardadas encima de las del pueblo recién creado: los muertos siguen muertos.
func from_data(data: Dictionary) -> void:
	for saved in data.get("records", []):
		if not saved is Dictionary:
			continue
		var record := _record(str(saved.get("id", "")))
		if record.is_empty():
			continue
		record["alive"] = bool(saved.get("alive", true))
		record["health"] = float(saved.get("health", -1.0))
		if saved.get("position") is Array and saved["position"].size() == 3:
			record["position"] = saved["position"]
	if data.get("law") is Dictionary:
		law.from_data(data["law"])


static func _vec(point: Vector3) -> Array:
	return [point.x, point.y, point.z]


static func _point(data: Array) -> Vector3:
	return Vector3(float(data[0]), float(data[1]), float(data[2]))
