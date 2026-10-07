extends Node3D
class_name Village
## Un pueblo: sus vecinos (fichas persistentes), sus lugares, sus horarios y su ley.
## Niveles de detalle de la IA: cerca del jugador los vecinos piensan y se mueven con física;
## más lejos, sin física, van a paso de persona al sitio que les toca; muy lejos no existen como
## figura, solo su ficha. La muerte es permanente. Ver docs/VECINOS_Y_GUARDIAS.md.

signal notice(text: String)
signal payment_requested(guard: Villager)   # abrir la pantalla de pago de la multa

const NEAR := 30.0            # metros: IA completa con física
const FAR := 90.0             # metros: más allá, solo la ficha
const WITNESS_RANGE := 18.0   # a qué distancia alguien ve un delito
const WALK := 1.2             # m/s de los vecinos simulados sin física
const PANIC_RANGE := 20.0
const CHASE_MARGIN := 25.0    # los guardias persiguen hasta este margen fuera del pueblo
const CLOSE_CHASE := 6.0      # ... y más lejos si le tienen así de cerca
const CHASE_LIMIT := 60.0     # pero nunca más allá de este margen
## Horarios por oficio: [hora de inicio, lugar, actividad], ordenados por hora (antes de la primera,
## sigue con la última del día anterior). "home" es la casa de cada uno;
## "patrol", la ronda de los guardias. Las actividades que empiezan por "Durmiendo" son dormir.
const SCHEDULES := {
	"farmer": [[6, "home", "Desayunando"], [7, "field", "Trabajando en el campo"], [12, "plaza", "Comiendo en la plaza"],
		[13, "field", "Trabajando en el campo"], [19, "tavern", "Tomando algo en la taberna"], [21, "home", "Durmiendo"]],
	"fisher": [[5, "home", "Desayunando"], [6, "dock", "Pescando en el muelle"], [12, "plaza", "Comiendo en la plaza"],
		[13, "dock", "Remendando redes"], [18, "plaza", "Charlando en la plaza"], [21, "home", "Durmiendo"]],
	"merchant": [[7, "home", "Desayunando"], [8, "market", "Vendiendo en el mercado"], [13, "plaza", "Comiendo en la plaza"],
		[14, "market", "Vendiendo en el mercado"], [19, "plaza", "Charlando en la plaza"], [22, "home", "Durmiendo"]],
	"blacksmith": [[6, "home", "Desayunando"], [7, "forge", "Trabajando en la fragua"], [13, "tavern", "Comiendo en la taberna"],
		[14, "forge", "Trabajando en la fragua"], [20, "tavern", "Bebiendo en la taberna"], [22, "home", "Durmiendo"]],
	"baker": [[4, "bakery", "Amasando el pan"], [9, "market", "Vendiendo pan"], [13, "home", "Comiendo en casa"],
		[14, "bakery", "Horneando"], [18, "plaza", "Charlando en la plaza"], [20, "home", "Durmiendo"]],
	"innkeeper": [[1, "home", "Durmiendo"], [8, "home", "Desayunando"], [9, "tavern", "Atendiendo la taberna"],
		[15, "market", "Comprando provisiones"], [17, "tavern", "Atendiendo la taberna"]],
	"banker": [[7, "home", "Desayunando"], [8, "bank", "Atendiendo el banco"], [13, "tavern", "Comiendo en la taberna"],
		[14, "bank", "Atendiendo el banco"], [18, "plaza", "Paseando"], [21, "home", "Durmiendo"]],
	"woodcutter": [[5, "home", "Desayunando"], [6, "woods", "Cortando leña"], [12, "woods", "Comiendo junto al bosque"],
		[13, "woods", "Cortando leña"], [18, "tavern", "Tomando algo en la taberna"], [21, "home", "Durmiendo"]],
	"hunter": [[4, "forest_edge", "Revisando las trampas"], [10, "market", "Vendiendo pieles"], [13, "home", "Comiendo en casa"],
		[15, "forest_edge", "Cazando"], [19, "tavern", "Contando historias en la taberna"], [22, "home", "Durmiendo"]],
	"herbalist": [[6, "herb_garden", "Recogiendo hierbas"], [11, "home", "Preparando remedios"], [14, "forest_edge", "Buscando plantas"],
		[18, "plaza", "Charlando en la plaza"], [21, "home", "Durmiendo"]],
	"priest": [[6, "chapel", "Tocando la campana"], [7, "chapel", "Rezando"], [12, "plaza", "Comiendo en la plaza"],
		[13, "refugee_camp", "Ayudando a los refugiados"], [18, "chapel", "Rezando"], [21, "home", "Durmiendo"]],
	"elder": [[8, "home", "Desayunando"], [9, "plaza", "Sentado en la plaza"], [13, "home", "Comiendo en casa"],
		[16, "plaza", "Sentado en la plaza"], [19, "tavern", "Recordando viejos tiempos"], [21, "home", "Durmiendo"]],
	"old_miner": [[9, "home", "Desayunando"], [10, "plaza", "Mirando la montaña"], [13, "tavern", "Bebiendo en la taberna"],
		[18, "chapel", "Rezando"], [19, "tavern", "Bebiendo en la taberna"], [23, "home", "Durmiendo"]],
	"carpenter": [[6, "home", "Desayunando"], [7, "workshop", "Serrando tablas"], [13, "plaza", "Comiendo en la plaza"],
		[14, "workshop", "Arreglando una carreta"], [19, "tavern", "Tomando algo en la taberna"], [21, "home", "Durmiendo"]],
	"refugee": [[7, "refugee_camp", "Desayunando en el campamento"], [9, "field", "Ayudando en el campo"], [13, "refugee_camp", "Comiendo en el campamento"],
		[15, "dock", "Mirando el mar"], [18, "refugee_camp", "Junto al fuego del campamento"], [21, "refugee_camp", "Durmiendo"]],
	"guard_day": [[6, "barracks", "Preparándose"], [7, "patrol", "Patrullando"], [19, "barracks", "Descansando"],
		[22, "barracks", "Durmiendo"]],
	"guard_night": [[6, "barracks", "Durmiendo"], [14, "barracks", "Descansando"], [19, "patrol", "Patrullando de noche"]],
}
const JOB_NAMES := {"farmer": "granjero", "fisher": "pescador", "merchant": "mercader", "blacksmith": "herrero",
	"baker": "panadero", "innkeeper": "tabernero", "banker": "banquero", "woodcutter": "leñador", "hunter": "cazador",
	"herbalist": "herbolaria", "priest": "sacerdote", "elder": "anciana", "old_miner": "viejo minero",
	"carpenter": "carpintero", "refugee": "refugiado", "guard_day": "guardia", "guard_night": "guardia de noche"}

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
var pending: Array = []       # delitos vistos solo por civiles que aún corren a denunciarlos
var knowledge := {}           # lo que el jugador ha descubierto hablando (para el futuro cuaderno)


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
			var on_duty: bool = (record["species"] == "guard" and (law.wants_payment() or law.guards_attack() or not pending.is_empty())) \
				or actor.state == "report"
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
	for actor in _actors.values():  # frases sueltas al pasar cerca
		if is_instance_valid(actor) and not actor.dead and actor.global_position.distance_to(player.global_position) < 5.0:
			actor.maybe_bark()
	if law.guards_attack():
		for witness in witnesses():
			if witness.species == "guard":
				alarm_point = player.global_position  # un guardia le ve: los demás acuden ahí
				break


## Vecino sin física: avanza hacia el sitio que le toca a paso de persona, pegado al suelo.
func _walk(record: Dictionary, from: Vector3, seconds: float) -> Vector3:
	var goal: Vector3 = _plan(record)["point"]
	var flat := Vector3(goal.x, from.y, goal.z)
	var at := from.move_toward(flat, WALK * seconds)
	# Desde la rodilla: desde más arriba el rayo daría en los tejados y los subiría a ellos.
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.8, at + Vector3.DOWN * 4.0, 1)
	var ground := get_world_3d().direct_space_state.intersect_ray(ray)
	if not ground.is_empty():
		at.y = ground["position"].y
	return at


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
	# Un testigo muerto ya no denuncia: si no quedaba nadie más, el delito se olvida.
	for crime in pending.duplicate():
		crime["reporters"].erase(id)
		if crime["reporters"].is_empty():
			pending.erase(crime)
			notice.emit("Nadie ha llegado a denunciarte.")


## Quién ve ahora al jugador: vecinos y guardias vivos cerca y con línea de visión.
func witnesses() -> Array[Villager]:
	var seen: Array[Villager] = []
	for actor in _actors.values():
		if is_instance_valid(actor) and not actor.dead and actor.global_position.distance_to(player.global_position) < WITNESS_RANGE and actor.can_see(player):
			seen.append(actor)
	return seen


func witnessed() -> bool:
	return not witnesses().is_empty()


## Un delito a la vista: si lo ve un guardia, cuenta ya; si solo lo ven vecinos, corren a avisar
## a la guardia y no cuenta hasta que llegue alguno (matarlos o perderlos de vista lo impide).
func _crime(kind: String, guard_victim := false) -> void:
	var seen := witnesses()
	if seen.is_empty():
		return
	var reporters: Array = []
	for witness in seen:
		if witness.species == "guard":
			_apply(kind, guard_victim, player.global_position)
			return
		reporters.append(witness.villager_id)
	pending.append({"kind": kind, "guard": guard_victim, "point": player.global_position, "reporters": reporters})
	for witness in seen:
		witness.start_report()
	notice.emit("Un testigo corre a avisar a la guardia. ¡Aún puedes impedirlo!")


func _apply(kind: String, guard_victim: bool, point: Vector3) -> void:
	match kind:
		"block": law.block_edit()
		"assault": law.assault(guard_victim)
		"murder": law.murder()
	alarm_point = point


## Un testigo ha llegado junto a un guardia: el delito que vio ya cuenta.
func reported(witness: Villager) -> void:
	for crime in pending.duplicate():
		if crime["reporters"].has(witness.villager_id):
			pending.erase(crime)
			_apply(crime["kind"], crime["guard"], crime["point"])


func nearest_guard(from: Vector3) -> Villager:
	var best: Villager = null
	for actor in _actors.values():
		if is_instance_valid(actor) and not actor.dead and actor.species == "guard":
			if best == null or actor.global_position.distance_to(from) < best.global_position.distance_to(from):
				best = actor
	return best


## El jugador ha golpeado (o matado) a un vecino o guardia.
func report_attack(victim: Villager, killed: bool) -> void:
	_crime("murder" if killed else "assault", victim.species == "guard")
	panic(player.global_position)


## El jugador ha roto o colocado un bloque en 'at'.
func report_block_edit(at: Vector3) -> void:
	if contains(at):
		_crime("block")


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


## Pagar la multa junto a un guardia (tecla R o hablarle): abre la pantalla de pago.
func try_pay() -> bool:
	var guard := collector()
	if law.fine <= 0.0 or law.murderer or guard == null or guard.global_position.distance_to(player.global_position) > 3.5:
		return false
	payment_requested.emit(guard)
	return true


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
	return {"records": records.duplicate(true), "law": law.to_data(), "knowledge": knowledge.duplicate()}


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
	if data.get("knowledge") is Dictionary:
		knowledge = data["knowledge"].duplicate()


static func _vec(point: Vector3) -> Array:
	return [point.x, point.y, point.z]


static func _point(data: Array) -> Vector3:
	return Vector3(float(data[0]), float(data[1]), float(data[2]))
