extends Node3D
## Mapa de pruebas independiente: nunca lee ni escribe la partida de la isla.
## Abrir scenes/combat_arena.tscn y F6, o ejecutar "Pruebas de combate.bat".
const SAVE_PATH := "user://combat_arena_v1.json"
const SquadScript = preload("res://scripts/creatures/enemy_squad.gd")
var save_path := SAVE_PATH  # las pruebas automáticas usan otro archivo
var player: Player
var _hotbar: Hotbar
var _inventory: InventoryScreen
var _panel: PanelContainer
var _notice: Label
var _clock: Label
var _notice_time := 0.0
var _save_timer := 15.0
var hour := 12.0
var _loading := false

func _ready() -> void:
	Settings.load_settings()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.48, 0.63)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	add_child(sun)
	add_child(Sfx.new())
	_box(Vector3(0, -0.5, -12), Vector3(100, 1, 110), Color(0.26, 0.38, 0.26))
	for x in [-50.0, 50.0]:
		_box(Vector3(x, 1.5, -12), Vector3(1, 3, 110), Color(0.4, 0.43, 0.46))
	for z in [-67.0, 43.0]:
		_box(Vector3(0, 1.5, z), Vector3(100, 3, 1), Color(0.4, 0.43, 0.46))
	# Obstáculos para probar línea de visión, proyectiles y escalones.
	_box(Vector3(-6, 1.0, -12), Vector3(4, 2, 1), Color(0.5, 0.5, 0.55))
	_box(Vector3(7, 0.25, -10), Vector3(3, 0.5, 3), Color(0.55, 0.5, 0.4))
	_sign(Vector3(0, 3, -10), "ENEMIGOS AL NORTE\nANIMALES AL SUR\nF2: panel de pruebas")
	player = Player.new()
	player.position = Vector3(0, 0.3, 0)
	add_child(player)
	player.set_spawn_point(Vector3(0, 0.1, 0))
	var needs := Needs.new()
	needs.player = player
	add_child(needs)
	player.needs = needs
	_build_ui()
	player.notice.connect(_show_notice)
	player.inventory_layout_changed.connect(_bind_hotbar)
	player.combat.before_death.connect(func() -> void:
		_inventory.close()
		_panel.hide()
		get_tree().paused = false)
	player.combat.persistence_requested.connect(save)
	_inventory.closed.connect(func() -> void:
		player.ui_open = false
		player._set_captured(true))
	if not _load():
		_supply()
		reset_population()
	_bind_hotbar()
	_show_notice("Mapa de pruebas: F2 para elegir criaturas, E inventario. Clic derecho recupera la mochila.")

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

func _sign(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.position = at
	label.text = text
	label.font_size = 38
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func spawn_creature(id: String, at: Vector3) -> CreatureActor:
	var actor := CreatureActor.new()
	actor.species = id
	actor.player = player
	actor.position = at
	add_child(actor)
	actor.died.connect(func(_actor: CreatureActor) -> void: save.call_deferred())
	return actor

func reset_population() -> void:
	for node in get_tree().get_nodes_in_group("enemy_squads"):
		node.free()
	for node in get_tree().get_nodes_in_group("creatures"):
		node.free()
	for node in get_tree().get_nodes_in_group("creature_projectiles"):
		node.free()
	for node in get_tree().get_nodes_in_group("player_arrows"):
		node.free()
	var positions := [Vector3(-28, 0.1, -18), Vector3(0, 0.1, -24), Vector3(28, 0.1, -18), Vector3(-24, 0.1, -48), Vector3(24, 0.1, -48), Vector3(0, 0.1, -42)]
	for i in CreatureDB.ENEMIES.size():
		spawn_creature(CreatureDB.ENEMIES[i], positions[i])
	for i in CreatureDB.ANIMALS.size():
		var id: String = CreatureDB.ANIMALS[i]
		var height := 3.0 if CreatureDB.profile(id)["flying"] else 0.1
		spawn_creature(id, Vector3(-32 + (i % 6) * 12, height, 16 + (i / 6) * 16))
	# Dos lobos para comprobar aviso de manada.
	spawn_creature("wolf", Vector3(19, 0.1, 16))
	spawn_random_patrol()
	save()

func spawn_random_patrol() -> void:
	if get_tree().get_nodes_in_group("creatures").size() > 35:
		_show_notice("No cabe otra patrulla: repón las criaturas primero.")
		return
	var squad = SquadScript.new()
	add_child(squad)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var start := Vector3(rng.randf_range(-18.0, 10.0), 0.1, rng.randf_range(-42.0, -30.0))
	var count := rng.randi_range(2, 4)
	for i in count:
		squad.points.append(start + Vector3(i * 5.0, 0, -sin(i * 1.2) * 6.0))
	squad.rest_duration = rng.randf_range(3.0, 7.0)
	var roster := ["captain", "soldier", "archer", "mage"]
	if rng.randf() < 0.5:
		roster.append("tracker")
	for i in roster.size():
		var actor := spawn_creature(roster[i], start + Vector3((i % 3 - 1) * 1.2, 0, (i / 3) * 1.2))
		squad.add_member(actor)
	save()

func _supply() -> void:
	player.set_equipment({"shirt": "shirt", "pants": "pants", "belt": "belt", "backpack": "backpack"})
	for id in ["spear", "stone_axe", "stone_knife", "stone_pick", "cooked_meat", "bow", "arrow", "wooden_shield"]:
		player.inventory.add(id, 8 if id == "cooked_meat" else 1, player.unlocked_slots())
	player.inventory.add("arrow", 31, player.unlocked_slots())
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
	_inventory.stack_dropped.connect(func(stack: Dictionary) -> void:
		var forward := -player.global_basis.z
		ItemDrop.throw_stack(self, player.eye_position() + forward * 0.6, forward, stack))
	_notice = Label.new()
	_notice.position = Vector2(16, 110)
	_notice.add_theme_color_override("font_outline_color", Color.BLACK)
	_notice.add_theme_constant_override("outline_size", 4)
	canvas.add_child(_notice)
	_clock = Label.new()
	_clock.position = Vector2(16, 16)
	canvas.add_child(_clock)
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
	title.text = "PRUEBAS — IA pausada mientras este panel está abierto"
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	column.add_child(grid)
	for id in CreatureDB.ENEMIES + CreatureDB.ANIMALS:
		var button := Button.new()
		button.text = CreatureDB.DATA[id]["name"]
		button.custom_minimum_size = Vector2(150, 36)
		button.pressed.connect(_spawn_ahead.bind(id))
		grid.add_child(button)
	_button(column, "Reponer criaturas del mapa", reset_population)
	_button(column, "Crear patrulla aleatoria (2–4 puntos)", spawn_random_patrol)
	_button(column, "Dar equipo de pruebas", _supply)
	_button(column, "Cambiar día / noche (rutinas)", func() -> void: hour = 23.0 if hour == 12.0 else 12.0)
	_button(column, "Morir para probar la mochila", func() -> void:
		_toggle_panel()
		player.combat.invulnerable = 0.0
		player.combat.take_damage(1000.0, player.global_position))
	_button(column, "Guardar y volver al juego", _toggle_panel)
	_panel.hide()

func _button(parent: Node, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(callback)
	parent.add_child(button)

func _spawn_ahead(id: String) -> void:
	if get_tree().get_nodes_in_group("creatures").size() >= 40:
		_show_notice("Límite de 40 criaturas para las pruebas.")
		return
	var forward := -player.global_basis.z
	var at := player.global_position + forward * 8.0
	at.x = clampf(at.x, -45.0, 45.0)
	at.z = clampf(at.z, -60.0, 38.0)
	at.y = 3.0 if CreatureDB.profile(id)["flying"] else 0.1
	spawn_creature(id, at)
	save()

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

func _bind_hotbar() -> void:
	if _hotbar != null:
		_hotbar.bind(player.active_inventory(), player.creative, player.hotbar_size())

func _process(delta: float) -> void:
	_hotbar.select(player._hotbar_index)
	_clock.text = "ARENA — %02d:00 — F2 panel / E inventario / 1–9 equipo\nClic ligero / mantener: pesado · Derecho guardia · Alt esquiva (doble: voltereta) · Ctrl sigilo" % int(hour)
	_notice_time -= delta
	_notice.visible = _notice_time > 0.0
	for node in get_tree().get_nodes_in_group("creatures"):
		(node as CreatureActor).hour = hour
	_save_timer -= delta
	if _save_timer <= 0.0:
		_save_timer = 15.0
		save()

func _show_notice(message: String) -> void:
	_notice.text = message
	_notice_time = 6.0

func save() -> void:
	if _loading or OS.get_cmdline_user_args().has("--arena-no-save"):
		return
	var creatures: Array = []
	var squads := get_tree().get_nodes_in_group("enemy_squads")
	var squad_data: Array = []
	for group in squads:
		squad_data.append(group.to_data())
	for node in get_tree().get_nodes_in_group("creatures"):
		var actor := node as CreatureActor
		if not actor.dead and not actor.is_queued_for_deletion():
			creatures.append({"species": actor.species, "health": actor.health,
				"position": [actor.global_position.x, actor.global_position.y, actor.global_position.z],
				"home": [actor.home.x, actor.home.y, actor.home.z], "alert_seconds": actor.alert_seconds,
				"squad": squads.find(actor.squad), "squad_slot": actor.squad_slot})
	var bags := get_tree().get_nodes_in_group("death_backpacks").filter(func(b: Node) -> bool: return not b.is_queued_for_deletion()).map(func(b: Node) -> Dictionary: return (b as DeathBackpack).to_data())
	var data := {"inventory": player.inventory.to_data(), "equipment": player.equipment, "gear_wear": player.gear_wear, "combat": player.combat.to_data(), "needs": player.needs.to_data(), "bags": bags, "creatures": creatures, "squads": squad_data, "hour": hour}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))

func _load() -> bool:
	if OS.get_cmdline_user_args().has("--arena-no-save") or not FileAccess.file_exists(save_path):
		return false
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	_loading = true
	player.set_equipment(data.get("equipment", {}), data.get("gear_wear", {}))
	player.inventory.from_data(data.get("inventory", []))
	player.combat.from_data(data.get("combat", {}))
	player.needs.from_data(data.get("needs", {}))
	hour = float(data.get("hour", 12.0))
	for bag in data.get("bags", []):
		DeathBackpack.restore(self, bag)
	var squads: Array = []
	for entry in data.get("squads", []):
		var group = SquadScript.new()
		group.from_data(entry)
		add_child(group)
		squads.append(group)
	for c in data.get("creatures", []):
		if not CreatureDB.DATA.has(str(c.get("species", ""))):
			continue
		var p: Array = c["position"]
		var actor := spawn_creature(c["species"], Vector3(float(p[0]), float(p[1]), float(p[2])))
		actor.health = clampf(float(c.get("health", actor.health)), 1.0, float(actor.stats["hp"]))
		var h: Array = c.get("home", p)
		actor.home = Vector3(float(h[0]), float(h[1]), float(h[2]))
		actor.alert_seconds = clampf(float(c.get("alert_seconds", 0.0)), 0.0, 60.0)
		var group_index := int(c.get("squad", -1))
		if group_index >= 0 and group_index < squads.size():
			squads[group_index].add_member(actor)
			actor.squad_slot = int(c.get("squad_slot", actor.squad_slot))
	_loading = false
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player != null:
		_inventory.close()
		save()
