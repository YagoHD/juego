extends Node3D
class_name IslandVillage
## El pueblo principal en la isla (llano de B4): los vecinos de VillageLayout con sus horarios, la
## ley y los delitos, los diálogos, el banco y las multas, como en la aldea de pruebas, pero con la
## hora del día de la isla, los edificios de bloques (VillageBuilder) y la partida de la isla.
## main.gd lo crea y le pasa el jugador, el reloj, los descubrimientos y la pantalla de inventario.

signal notice(text: String)

var player: Player
var day_night: DayNight
var discoveries: Discoveries
var screen: InventoryScreen
var generator: IslandGenerator
var village: Village
var _dialogue: DialoguePanel
var _offer: OfferPanel
var _talking: Villager


## Crea el pueblo. 'canvas' es la capa de interfaz donde va el panel de diálogo.
func setup(canvas: CanvasLayer) -> void:
	village = Village.new()
	village.name = "Village"
	add_child(village)
	village.player = player
	var center := _ground(Vector2.ZERO)
	village.center = center
	village.radius = VillageLayout.RADIUS
	for place: String in VillageLayout.PLACES:
		var point := _ground(VillageLayout.PLACES[place][0])
		village.places[place] = {"point": point, "radius": VillageLayout.PLACES[place][1]}
		_sign(point + Vector3.UP * 3.2, VillageLayout.PLACE_NAMES[place])
	for p in VillageLayout.patrol():
		village.patrol.append(_ground(p))
	for i in VillageLayout.POPULATION.size():
		var home := VillageLayout.home_of(i) + Vector2(cos(i * 2.4), sin(i * 2.4)) * 1.1
		village.add_record("v%02d" % i, VillageLayout.POPULATION[i][0], VillageLayout.POPULATION[i][1], _ground(home))
	village.notice.connect(func(text: String) -> void: notice.emit(text))
	village.payment_requested.connect(func(guard: Villager) -> void: open_offer("fine", guard.villager_name))
	_dialogue = DialoguePanel.new()
	canvas.add_child(_dialogue)
	_dialogue.closed.connect(_on_dialogue_closed)
	_dialogue.action_chosen.connect(_on_dialogue_action)
	_dialogue.learned.connect(func(flag: String) -> void: discoveries.learn(flag, "diálogo"))
	player.talk_requested.connect(_on_talk)
	player.block_broken.connect(func(cell: Vector3i, _id: int) -> void:
		village.report_block_edit((Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * 0.5))
	player.combat.before_death.connect(village.player_died)
	screen.closed.connect(func() -> void:
		if _offer != null:
			_offer.return_offer()  # lo que no se entregó vuelve al inventario
			_offer = null)


## Punto del suelo (metros) a 'offset' metros del centro del pueblo.
func _ground(offset: Vector2) -> Vector3:
	var p := VillageLayout.ISLAND_CENTER + offset
	var h := generator.get_ground_height(roundi(p.x * 2.0), roundi(p.y * 2.0)) * 0.5 if generator != null else 0.0
	return Vector3(p.x, h + 0.1, p.y)


func _sign(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.position = at
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = 40.0
	add_child(label)


func _process(_delta: float) -> void:
	if village == null or day_night == null:
		return
	village.hour = day_night.hour
	village.day = day_night.day


## ¿Está abierto el diálogo? (Esc lo cierra antes que el menú de pausa.)
func dialogue_open() -> bool:
	return _dialogue != null and _dialogue.is_open()


func close_dialogue() -> void:
	_dialogue.close()


## Pantalla de pago de una multa ("fine") o de cambio de oro en el banco ("bank").
func open_offer(kind: String, who: String) -> void:
	if screen.visible:
		return
	_offer = OfferPanel.new(player, screen, village, kind, who)
	player.ui_open = true
	player._set_captured(false)
	screen.open(_offer.sections(), _offer)


func _on_talk(villager: Node3D) -> void:
	if screen.visible or _dialogue.is_open() or not villager is Villager:
		return
	_talking = villager as Villager
	_talking.start_talk()
	_dialogue.knowledge = discoveries.known
	player.ui_open = true
	player._set_captured(false)
	_dialogue.open(_talking, village)


func _on_dialogue_closed() -> void:
	if is_instance_valid(_talking):
		_talking.end_talk()
	_talking = null
	if not screen.visible:
		player.ui_open = false
		player._set_captured(true)


func _on_dialogue_action(action: String, villager: Villager) -> void:
	match action:
		"pay":
			open_offer("fine", villager.villager_name)
		"bank":
			open_offer("bank", villager.villager_name)
		"teach_furnace":
			if player.learn("furnace"):
				notice.emit("%s te enseña a montar un horno de piedra (piedras y arcilla): funde allí las pepitas en monedas. Está en el diario (J)." % villager.villager_name)
			else:
				notice.emit("%s: «Ya te lo expliqué: horno de piedra, buen fuego y paciencia.»" % villager.villager_name)


func to_data() -> Dictionary:
	return village.to_data() if village != null else {}


func from_data(data: Dictionary) -> void:
	if village != null:
		village.from_data(data)
