extends Node3D
## Aldea de pruebas: 31 vecinos y guardias con horario, ley y delitos, sin tocar la isla.
## Abrir scenes/village_test.tscn y F6, o "Pruebas de aldea.bat". F2: panel de pruebas.
const SAVE_PATH := "user://village_test_v1.json"
## Los vecinos: nombre y oficio. Los guardias viven en el cuartel; los refugiados, en su campamento.
const POPULATION := [
	["Aldo", "farmer"], ["Berta", "farmer"], ["Ciro", "farmer"], ["Dalia", "farmer"], ["Elio", "farmer"],
	["Fela", "fisher"], ["Gil", "fisher"], ["Hilda", "fisher"],
	["Iván", "merchant"], ["Juana", "merchant"],
	["Lope", "blacksmith"], ["Marta", "baker"], ["Nuño", "innkeeper"], ["Olga", "banker"],
	["Pelayo", "woodcutter"], ["Quiteria", "woodcutter"], ["Ramiro", "hunter"], ["Sancha", "herbalist"],
	["Fray Tello", "priest"], ["Abuela Urraca", "elder"], ["Viejo Bermudo", "old_miner"], ["Vela", "carpenter"],
	["Ximena", "refugee"], ["Yáñez", "refugee"], ["Zoila", "refugee"],
	["Rodrigo", "guard_day"], ["Gonzalo", "guard_day"], ["Munio", "guard_day"],
	["Fruela", "guard_night"], ["Ordoño", "guard_night"], ["Sisebuto", "guard_night"],
]
const PLACE_NAMES := {"plaza": "Plaza", "field": "Campo", "dock": "Muelle", "market": "Mercado", "barracks": "Cuartel",
	"forge": "Fragua", "bakery": "Horno", "tavern": "Taberna", "bank": "Banco", "woods": "Bosque", "forest_edge": "Linde del bosque",
	"herb_garden": "Huerto de hierbas", "chapel": "Capilla", "workshop": "Carpintería", "refugee_camp": "Campamento de refugiados"}
const HOUR_SECONDS := 30.0    # segundos reales por hora del pueblo (un día en 12 minutos)

var save_path := SAVE_PATH    # las pruebas automáticas usan otro archivo
var player: Player
var village: Village
var hour := 8.0
var time_running := true
var _hotbar: Hotbar
var _inventory: InventoryScreen
var _panel: PanelContainer
var _notice: Label
var _info: Label
var _notice_time := 0.0
var _save_timer := 15.0
var _offer: OfferPanel         # pantalla de pago o de banco abierta
var _dialogue: DialoguePanel
var _talking: Villager


func _ready() -> void:
	Settings.load_settings()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.6, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	add_child(sun)
	add_child(Sfx.new())
	_box(Vector3(0, -0.5, 0), Vector3(130, 1, 130), Color(0.33, 0.45, 0.28))
	village = Village.new()
	village.name = "Village"
	add_child(village)
	_build_village()
	player = Player.new()
	player.position = Vector3(0, 0.3, 8)
	add_child(player)
	player.set_spawn_point(Vector3(0, 0.1, 8))
	var needs := Needs.new()
	needs.player = player
	add_child(needs)
	player.needs = needs
	village.player = player
	_build_ui()
	player.notice.connect(_show_notice)
	village.notice.connect(_show_notice)
	player.inventory_layout_changed.connect(_bind_hotbar)
	player.combat.before_death.connect(func() -> void:
		_inventory.close()
		_panel.hide()
		get_tree().paused = false
		village.player_died())
	_inventory.closed.connect(func() -> void:
		if _offer != null:
			_offer.return_offer()  # lo que no se entregó vuelve al inventario
			_offer = null
		player.ui_open = false
		player._set_captured(true))
	village.payment_requested.connect(func(guard: Villager) -> void: open_offer("fine", guard.villager_name))
	player.talk_requested.connect(_on_talk)
	if not _load():
		_supply()
	_bind_hotbar()
	_show_notice("Aldea de pruebas: F2 panel, E inventario. Pegar o matar a vecinos es delito; R paga la multa junto a un guardia.")


## Lugares, casas y ronda de los guardias; y los 20 vecinos.
func _build_village() -> void:
	village.center = Vector3.ZERO
	village.radius = 46.0
	var places := {"plaza": [Vector3(0, 0.1, 0), 5.0], "field": [Vector3(-24, 0.1, -16), 7.0],
		"dock": [Vector3(26, 0.1, -18), 4.0], "market": [Vector3(12, 0.1, 12), 4.0], "barracks": [Vector3(-14, 0.1, 20), 3.0],
		"forge": [Vector3(8, 0.1, -8), 2.0], "bakery": [Vector3(-8, 0.1, -8), 2.0], "tavern": [Vector3(-10, 0.1, 6), 3.5],
		"bank": [Vector3(6, 0.1, 22), 2.0], "woods": [Vector3(-44, 0.1, 10), 6.0], "forest_edge": [Vector3(-40, 0.1, 34), 6.0],
		"herb_garden": [Vector3(20, 0.1, 30), 3.0], "chapel": [Vector3(0, 0.1, -24), 3.0], "workshop": [Vector3(18, 0.1, 0), 2.5],
		"refugee_camp": [Vector3(36, 0.1, 12), 5.0]}
	for place in places:
		village.places[place] = {"point": places[place][0], "radius": places[place][1]}
		_sign(places[place][0] + Vector3.UP * 3.2, PLACE_NAMES[place])
	for place in ["forge", "bakery", "tavern", "bank", "chapel", "workshop"]:
		_shelter(places[place][0], Vector3(5, 2.8, 5))
	for i in 8:  # árboles provisionales del bosque
		_box(Vector3(-48 + (i % 4) * 4.0, 2.0, 2 + (i / 4) * 14.0), Vector3(0.6, 4, 0.6), Color(0.35, 0.25, 0.15))
	_box(Vector3(-24, 0.02, -16), Vector3(14, 0.04, 14), Color(0.5, 0.42, 0.25))   # campo
	_box(Vector3(26, 0.15, -18), Vector3(6, 0.3, 10), Color(0.45, 0.32, 0.2))     # muelle
	_box(Vector3(12, 0.5, 15), Vector3(5, 1, 1), Color(0.6, 0.45, 0.3))           # puestos del mercado
	_shelter(Vector3(-14, 0, 20), Vector3(6, 2.6, 6))                            # cuartel
	for i in 6:
		var angle := i * TAU / 6.0
		village.patrol.append(Vector3(cos(angle) * 22.0, 0.1, sin(angle) * 22.0))
	for home in _homes():
		_shelter(home, Vector3(4, 2.4, 4))
	_build_village_records()


## Las 13 casas, en corro alrededor de la plaza (dos vecinos en cada una).
func _homes() -> Array[Vector3]:
	var homes: Array[Vector3] = []
	for i in 13:
		var angle := 0.2 + i * TAU / 13.0
		homes.append(Vector3(cos(angle) * 30.0, 0.1, sin(angle) * 30.0))
	return homes


func _box(at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	body.add_child(visual)
	add_child(body)


## Casa provisional: tejado sobre cuatro postes (se entra por cualquier lado).
func _shelter(at: Vector3, size: Vector3) -> void:
	var wood := Color(0.5, 0.36, 0.22)
	for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		_box(at + Vector3(corner.x * size.x * 0.45, size.y * 0.5, corner.z * size.z * 0.45), Vector3(0.3, size.y, 0.3), wood)
	_box(at + Vector3(0, size.y, 0), Vector3(size.x, 0.25, size.z), Color(0.6, 0.3, 0.2))


func _sign(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.position = at
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _supply() -> void:
	player.set_equipment({"shirt": "shirt", "pants": "pants", "belt": "belt", "backpack": "backpack"})
	for id in ["stone_knife", "stone_axe", "spear", "cooked_meat"]:
		player.inventory.add(id, 6 if id == "cooked_meat" else 1, player.unlocked_slots())
	player.inventory.add("gold_coin", 30, player.unlocked_slots())  # para pagar multas
	player.inventory.add("gold_nugget", 6, player.unlocked_slots())  # para el banco
	player.inventory.add("rope", 20, player.unlocked_slots())
	_bind_hotbar()


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	_hotbar = Hotbar.new()
	canvas.add_child(_hotbar)
	_inventory = InventoryScreen.new()
	_inventory.hotbar = _hotbar
	canvas.add_child(_inventory)
	_notice = Label.new()
	_notice.position = Vector2(16, 110)
	_notice.add_theme_color_override("font_outline_color", Color.BLACK)
	_notice.add_theme_constant_override("outline_size", 4)
	canvas.add_child(_notice)
	_info = Label.new()
	_info.position = Vector2(16, 150)  # debajo de la vida y de los avisos
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 4)
	canvas.add_child(_info)
	_dialogue = DialoguePanel.new()
	canvas.add_child(_dialogue)
	_dialogue.closed.connect(_on_dialogue_closed)
	_dialogue.action_chosen.connect(_on_dialogue_action)
	_dialogue.learned.connect(func(_flag: String) -> void: _show_notice("Lo apuntas en tu memoria (más adelante, en el cuaderno)."))
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(crosshair)
	_panel = PanelContainer.new()
	_panel.position = Vector2(160, 145)
	canvas.add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	var title := Label.new()
	title.text = "PRUEBAS DE LA ALDEA (el tiempo se para con el panel abierto)"
	column.add_child(title)
	for h in [6, 8, 12, 13, 19, 22]:
		_button(column, "Ir a las %02d:00" % h, func() -> void: hour = float(h))
	_button(column, "Parar / seguir el reloj", func() -> void: time_running = not time_running)
	_button(column, "Perdonar todos los delitos", func() -> void: village.law.from_data({}))
	_button(column, "Recrear el pueblo (resucita a todos)", func() -> void:
		for actor in village._actors.values():
			if is_instance_valid(actor):
				actor.queue_free()
		village._actors.clear()
		village.records.clear()
		village.law.from_data({})
		_build_village_records())
	_button(column, "Dar equipo de pruebas", _supply)
	_button(column, "Guardar y volver", _toggle_panel)
	_panel.hide()


## Las fichas de los vecinos (los guardias viven en el cuartel; los refugiados, en su campamento).
func _build_village_records() -> void:
	var homes := _homes()
	var next_home := 0
	for i in POPULATION.size():
		var job: String = POPULATION[i][1]
		var home: Vector3
		if job.begins_with("guard"):
			home = village.places["barracks"]["point"]
		elif job == "refugee":
			home = village.places["refugee_camp"]["point"]
		else:
			home = homes[(next_home / 2) % homes.size()]
			next_home += 1
		# Cada uno en su sitio dentro de la casa (dos cuerpos en el mismo punto se empujan hacia arriba).
		village.add_record("v%02d" % i, POPULATION[i][0], job, home + Vector3(cos(i * 2.4), 0, sin(i * 2.4)) * 1.1)


func _button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


func _toggle_panel() -> void:
	if _inventory.visible:
		_inventory.close()
	_panel.visible = not _panel.visible
	get_tree().paused = _panel.visible
	player.ui_open = _panel.visible
	player._set_captured(not _panel.visible)
	if not _panel.visible:
		save()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and _dialogue.is_open():
		_dialogue.close()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_F2 or event.keycode == KEY_ESCAPE:
		if _inventory.visible:
			_inventory.close()
		else:
			_toggle_panel()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_E and not _panel.visible:
		if _inventory.visible:
			_inventory.close()
		else:
			player.ui_open = true
			player._set_captured(false)
			var inv := player.active_inventory()
			var sections: Array[Dictionary] = [
				{"title": "Inventario", "inventory": inv, "columns": 9, "slots": range(Hotbar.SLOTS, Hotbar.SLOTS + player.storage_size())},
				{"title": "Barra rápida", "inventory": inv, "columns": 9, "slots": range(0, player.hotbar_size())},
			]
			_inventory.open(sections, EquipmentPanel.new(player, _inventory))
		get_viewport().set_input_as_handled()


## Pantalla de pago de una multa ("fine") o de cambio de oro en el banco ("bank").
func open_offer(kind: String, who: String) -> void:
	if _inventory.visible:
		return
	_offer = OfferPanel.new(player, _inventory, village, kind, who)
	player.ui_open = true
	player._set_captured(false)
	_inventory.open(_offer.sections(), _offer)


## Clic derecho a un vecino: se abre el diálogo.
func _on_talk(villager: Node3D) -> void:
	if _inventory.visible or _dialogue.is_open():
		return
	_talking = villager as Villager
	_talking.start_talk()
	_dialogue.knowledge = village.knowledge
	player.ui_open = true
	player._set_captured(false)
	_dialogue.open(_talking, village)


func _on_dialogue_closed() -> void:
	if is_instance_valid(_talking):
		_talking.end_talk()
	_talking = null
	if not _inventory.visible:
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
				_show_notice("%s te enseña a montar un horno de piedra (piedras y arcilla): funde allí las pepitas en monedas. Está en el diario (J)." % villager.villager_name)
			else:
				_show_notice("%s: «Ya te lo expliqué: horno de piedra, buen fuego y paciencia.»" % villager.villager_name)


func _bind_hotbar() -> void:
	if _hotbar != null:
		_hotbar.bind(player.active_inventory(), player.creative, player.hotbar_size())


func _process(delta: float) -> void:
	if time_running and not get_tree().paused:
		hour = fmod(hour + delta / HOUR_SECONDS, 24.0)
	village.hour = hour
	_hotbar.select(player._hotbar_index)
	var law := village.law
	var status := "en paz"
	if law.murderer:
		status = "ASESINO: los guardias te matan si te ven"
	elif law.hostile:
		status = "los guardias te persiguen (multa %d)" % ceili(law.fine)
	elif law.fine > 0.0:
		status = "multa pendiente: %d (R junto a un guardia)" % ceili(law.fine)
	elif law.warnings > 0:
		status = "avisos: %d de %d" % [law.warnings, VillageLaw.WARNINGS]
	_info.visible = not _inventory.visible and not _dialogue.is_open()
	_info.text = "ALDEA — %02d:%02d — vivos %d/%d, con IA completa %d — %d FPS, física %.1f ms\nLey: %s\nF2 panel · E inventario · R pagar multa" % [
		int(hour), int(fmod(hour, 1.0) * 60.0), village.living_count(), village.records.size(), village.active_count(),
		Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, status]
	_notice_time -= delta
	_notice.visible = _notice_time > 0.0
	_save_timer -= delta
	if _save_timer <= 0.0:
		_save_timer = 15.0
		save()


func _show_notice(message: String) -> void:
	_notice.text = message
	_notice_time = 6.0


func save() -> void:
	if OS.get_cmdline_user_args().has("--village-no-save"):
		return
	var data := {"inventory": player.inventory.to_data(), "equipment": player.equipment, "combat": player.combat.to_data(),
		"hour": hour, "village": village.to_data()}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))


func _load() -> bool:
	if OS.get_cmdline_user_args().has("--village-no-save") or not FileAccess.file_exists(save_path):
		return false
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	player.set_equipment(data.get("equipment", {}))
	player.inventory.from_data(data.get("inventory", []))
	player.combat.from_data(data.get("combat", {}))
	hour = float(data.get("hour", 8.0))
	if data.get("village") is Dictionary:
		village.from_data(data["village"])
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player != null:
		_inventory.close()
		save()
