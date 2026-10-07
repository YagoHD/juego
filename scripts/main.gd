extends Node3D
class_name Main
## Mundo jugable: la isla de la Beta (diseñada en tools/island_baker y guardada en disco),
## jugador en primera persona, romper (clic izq.) y colocar (clic der.) bloques.
##
## Dibujado en 3 capas:
##   1. Cerca del jugador: voxels con todo el detalle (editables).
##   2. Lejos: la isla entera como una malla simplificada (FarTerrain), siempre visible.
##   3. Niebla por distancia: visión limpia hasta media isla y luego bruma suave.

# Tamaño de cada voxel en metros. 1.0 = estilo Minecraft; 0.5 = cada cubo se parte en 8
# (estilo Cube World, personaje de ~4 cubos de alto). Baja este valor para más detalle.
const VOXEL_SIZE := 0.5
# Radio de voxels detallados alrededor del jugador: el de los ajustes (Gráficos > Distancia de
# detalle, en metros; se aplica al entrar en la partida). Más lejos, la isla simplificada.
var _near_voxels := 256
# La malla lejana se recorta un poco antes de donde acaban los voxels, para que se solapen.
var _far_hide_radius := 113.0

# Niebla: limpia hasta FOG_BEGIN metros, y se va difuminando hasta FOG_END.
const FOG_BEGIN := 280.0
const FOG_END := 1300.0
const FOG_MAX := 0.9   # opacidad máxima de la niebla (1 = tapa del todo)

# El punto de aparición lo decide el naufragio (Structures.spawn_voxel): la playa junto al barco.
const MAX_LOAD_SECONDS := 60.0  # tope de seguridad: entrar aunque no haya "terminado"

const WORLD_DIR := "user://world"
const TEST_WORLD_DIR := "user://world_test"


## Modo prueba (pruebas automáticas y capturas): usa un mundo aparte que se crea limpio cada vez,
## para no tocar nunca el mundo guardado del jugador.
static var test_mode := false
static var test_tower_mode := false  # integración explícita, aislada de la partida del usuario
static var keep_test_world := false  # pruebas de guardar y cargar: no borrar el mundo de pruebas
const AUTOSAVE_SECONDS := 60.0

var _player: Player
var _hud: Label
var _ground: GroundCrafting     # objetos dejados en el suelo para fabricar
var _prompt: Label             # avisos cortos sobre la barra (de momento sin uso)
var _notice: Label             # mensajes cortos ("Has aprendido...")
var _notice_time := 0.0
var _journal: Journal
var _ui_layer: CanvasLayer
var _pause: PauseMenu
var _help: Control             # ayuda de controles (F1)
var _help_on := false
var _sfx: Sfx
var _sea_check := 0.0
var _objectives: Objectives
var _last_drift_day := 1        # último día en que el mar trajo restos
var _open_chest: ChestVisual       # el cofre que se está mirando (con la tapa levantada)
var _capture: CaptureMode          # modo captura (solo con "--capture="; si no, null)
var _session: CraftSession     # inventario de rodillas y vista de fabricar
var _crosshair: Label
var _needs: Needs
var _sleeping := false  # fundido de dormir en marcha
var _hunger_bar: ProgressBar
var _micro_ship: Node3D  # el barco de cubitos
var _salvage: Salvage    # restos de la playa que se desmontan
var _thirst_bar: ProgressBar
var _rest_bar: ProgressBar
var _hotbar: Hotbar
var _underwater: ColorRect
var _day_night: DayNight
const TowerScript = preload("res://scripts/world/tower_director.gd")
var _tower: Node3D
var _inventory_screen: InventoryScreen
var _screen_sections := Callable()  # rehace las secciones de la pantalla abierta
var _chests := ChestStorage.new()
var _world_id := ""  # huella del mundo (nombre de sus archivos de guardado)
var _terrain: VoxelTerrain
var _generator: IslandGenerator
var _tree_generator: TreeGenerator  # el de los árboles detallados (null en la sala de muestras)
var _loading := true
var _title: TitleScreen
var _waiting_play := false   # el mundo ya está listo; la pantalla de título espera a "Jugar"
var _elapsed := 0.0
var _world_is_new := false


func _ready() -> void:
	Settings.load_settings()
	_near_voxels = int(Settings.view_distance / VOXEL_SIZE)
	_far_hide_radius = _near_voxels * VOXEL_SIZE - 15.0
	if _arg("--capture=") != "":
		_capture = CaptureMode.new()
		_capture.main = self
		add_child(_capture)
	if _showroom():
		test_mode = true  # mundo de pruebas: no toca la partida
	if _arg("--textures=") != "":  # capturas: probar un paquete de texturas
		Settings.texture_pack = _arg("--textures=")
	UiTheme.apply_cursor()
	PerfStats.enable(get_viewport(), true)  # tiempos de la gráfica para el F3
	Settings.apply_graphics(get_tree())  # suavizado (las sombras y el relieve, al crearse)
	_sfx = Sfx.new()
	add_child(_sfx)
	_build_world()
	if not _showroom():  # la sala de muestras no tiene isla lejana
		_build_far_terrain()
	_build_environment()
	_build_hud()
	_build_player()
	if (not _is_test() or test_tower_mode) and not _showroom():
		_tower = TowerScript.new()
		add_child(_tower)
		_tower.configure(_player, _day_night, _generator)
		if FileAccess.file_exists(_player_save_path()):
			var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(_player_save_path()))
			if stored is Dictionary:
				_tower.from_data(stored.get("tower", {}))
		_tower.advance_to_day(_day_night.day)
		_tower.set_physics_process(false)
		_tower.phase_changed.connect(func(stage: int) -> void: _show_notice("La torre avanza a la fase %d." % stage))
		_tower.boss_defeated.connect(func() -> void: _save_world.call_deferred())
	_build_loading_overlay()
	print("[main] %s" % _loading_title())

	var autosave := Timer.new()
	autosave.wait_time = AUTOSAVE_SECONDS
	autosave.autostart = true
	autosave.timeout.connect(_save_world)
	add_child(autosave)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_world()


func _save_world() -> void:
	# Guarda en disco los bloques que el jugador ha cambiado.
	if _terrain != null and not _loading:
		StutterLog.mark("guardado automático")
		_terrain.save_modified_blocks()
		if WorldVoxels.tool() != null and WorldVoxels.tool().trees != null:
			WorldVoxels.tool().trees.save_modified_blocks()  # los árboles talados, en su terreno
		_save_player()
		_chests.save_to(_chests_save_path())
		_ground.save_to(_ground_save_path())


# ------------------------------------------------------------------ mundo

func _build_world() -> void:
	_generator = ShowroomGenerator.new() if _showroom() else IslandGenerator.new()
	var library := BlockModels.build_library(_generator)

	var mesher := VoxelMesherBlocky.new()
	mesher.library = library

	var terrain := VoxelTerrain.new()
	terrain.mesher = mesher
	terrain.generator = _generator
	terrain.stream = null if _showroom() else _make_world_stream()  # la sala no se guarda
	terrain.generate_collisions = not _arg("--debug-nocol=").contains("ground")  # (experimento de tirones)
	# Solo existen voxels dentro de la isla y entre el fondo marino y las cimas.
	terrain.bounds = AABB(Vector3(-IslandGenerator.MAP_HALF, 0, -IslandGenerator.MAP_HALF), Vector3(IslandGenerator.MAP_HALF * 2.0, 256, IslandGenerator.MAP_HALF * 2.0))
	# Mallas de 32³ voxels: 8 veces menos objetos de malla y colisión que con 16³.
	terrain.mesh_block_size = 32
	terrain.max_view_distance = _near_voxels + 64
	terrain.scale = Vector3.ONE * VOXEL_SIZE  # voxels más pequeños (estilo Cube World)
	terrain.add_to_group("voxel_terrain")
	add_child(terrain)
	_terrain = terrain
	# Los árboles detallados, en un terreno aparte con menos distancia (más allá se ven los
	# sencillos de FarTrees): los árboles son casi todo lo que cuesta dibujar. WorldVoxels hace
	# que el resto del juego vea los dos terrenos como uno.
	var trees: VoxelTerrain = null
	if not _showroom():
		_generator.skip_trees = true
		_tree_generator = TreeGenerator.new()
		trees = VoxelTerrain.new()
		trees.name = "TreeTerrain"
		trees.mesher = mesher
		trees.generator = _tree_generator
		trees.stream = _make_world_stream("arboles")
		trees.generate_collisions = not _arg("--debug-nocol=").contains("trees")  # (experimento de tirones)
		trees.bounds = terrain.bounds
		trees.mesh_block_size = 16  # trozos pequeños: cada uno se prepara rápido (sin tirones al cargar)
		trees.max_view_distance = int(Settings.tree_distance / VOXEL_SIZE)
		trees.scale = terrain.scale
		add_child(trees)
	WorldVoxels.setup(terrain, trees)
	var water_flow := WaterFlow.new()  # el agua que corre al abrirle hueco
	water_flow.name = "WaterFlow"
	water_flow.terrain = terrain
	add_child(water_flow)

	if not _showroom():
		_build_sea()
		_build_micro_wreck()


func _build_far_terrain() -> void:
	var far := FarTerrain.new()
	# Colores de lejos = color medio de la cara de arriba de cada textura, para que la isla lejana
	# tenga el mismo tono que los bloques texturizados de cerca.
	var colors := {}
	for id in Blocks.COLORS:
		colors[id] = BlockTextures.average_color(id, 0)
	colors[IslandGenerator.WATER] = Blocks.color_of(IslandGenerator.WATER)
	# Con los árboles sencillos a lo lejos, el bosque son árboles; sin ellos, un manto de copas.
	far.build(_generator, colors, VOXEL_SIZE, _far_hide_radius, not Settings.far_trees)
	add_child(far)
	if Settings.far_trees:
		var trees := FarTrees.new()
		add_child(trees)
		# Se esconden donde ya hay árboles detallados (el terreno de los árboles).
		trees.start(_generator, VOXEL_SIZE, Settings.tree_distance)


func _make_world_stream(part := "") -> VoxelStreamSQLite:
	# El mundo se guarda en un archivo: lo ya visitado se lee de ahí (rápido) y conserva lo
	# que el jugador construya. El nombre lleva una "huella" de los mapas y del generador:
	# si cambian, se crea un mundo nuevo.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_world_dir()))
	if _is_test() and part == "":  # (una sola vez: con el terreno principal)
		if not keep_test_world:
			_clear_test_world()  # cada prueba empieza con el mundo recién creado
	_world_id = _world_fingerprint()
	var file_name := ("isla_%s.sqlite" % _world_id) if part == "" else ("isla_%s_%s.sqlite" % [_world_id, part])
	var path := _world_dir().path_join(file_name)
	if part == "":
		_world_is_new = not FileAccess.file_exists(path)
	# Las huellas distintas crean mapas separados. Conservamos los anteriores para que cambiar
	# los mapas o volver a una versión anterior no borre construcciones, inventario ni cofres.
	var stream := VoxelStreamSQLite.new()
	stream.database_path = ProjectSettings.globalize_path(path)
	stream.save_generator_output = true
	return stream


func _world_fingerprint() -> String:
	# Huella de los datos que el generador ha cargado de verdad (no de los PNG en disco: Godot
	# usa su copia importada, que puede ir por detrás) + la del propio generador.
	var text := _generator.get_maps_fingerprint()
	text += FileAccess.get_md5("res://scripts/world/island_generator.gd")
	text += FileAccess.get_md5("res://scripts/world/structures.gd")
	text += FileAccess.get_md5("res://scripts/world/tree_generator.gd")
	# Las piezas horneadas (árboles, rocas...): si cambia la forma de una, el mundo se rehace.
	for n: String in PrefabLibrary.NAMES:
		if FileAccess.file_exists(PrefabLibrary.DIR + n + ".res"):
			text += FileAccess.get_md5(PrefabLibrary.DIR + n + ".res")
	text += FileAccess.get_md5("res://scripts/world/prefab_library.gd") + str(PrefabLibrary.last_id())
	return text.md5_text().substr(0, 12)


func _build_sea() -> void:
	# Plano de agua al nivel del mar, con color según la profundidad (turquesa en la orilla).
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	water.mesh = plane
	# Un pelín por debajo del tope del bloque de arena para evitar z-fighting con el terreno.
	water.position = Vector3(0, IslandGenerator.SEA_LEVEL * VOXEL_SIZE - 0.08, 0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/sea.gdshader")
	water.material_override = mat
	add_child(water)


func _build_player() -> void:
	# El jugador existe desde el principio (sus observadores cargan el terreno a su alrededor),
	# pero flota quieto hasta que hay suelo con colisión debajo.
	var ground := _generator.get_ground_height(Structures.spawn_voxel().x, Structures.spawn_voxel().y)
	_player = Player.new()
	_player.near_view_voxels = _near_voxels
	_player.position = Vector3(Structures.spawn_voxel().x, ground + 4, Structures.spawn_voxel().y) * VOXEL_SIZE
	add_child(_player)
	_player.rotation.y = Structures.spawn_yaw()  # mirando al barco naufragado
	if _salvage != null:
		_salvage.player = _player
		_player.salvage = _salvage
	_aim_at_micro_ship()
	if _showroom():
		_player.rotation.y = PI  # mirando a la fila de muestras
		_build_micro_showcase()
	_chests.load_from(_chests_save_path())
	if _showroom():
		ShowroomGenerator.stock_item_chests(_chests)
	_ground = GroundCrafting.new()
	add_child(_ground)
	_ground.player = _player
	_ground.crafted.connect(func(recipe_id: String) -> void: _objectives.mark("hecho_" + recipe_id))
	_objectives.player = _player
	var fish_school := FishSchool.new()
	add_child(fish_school)
	fish_school.player = _player
	fish_school.generator = _generator
	fish_school.voxel_size = VOXEL_SIZE
	_player.fish = fish_school
	var wildlife := Wildlife.new()
	add_child(wildlife)
	wildlife.player = _player
	wildlife.generator = _generator
	wildlife.voxel_size = VOXEL_SIZE
	_player.wildlife = wildlife
	var weather := Weather.new()
	add_child(weather)
	weather.player = _player
	weather.day_night = _day_night
	_player.weather = weather
	var exploration := Exploration.new()
	exploration.name = "Exploration"
	add_child(exploration)
	exploration.player = _player
	var farming := Farming.new()
	farming.name = "Farming"
	add_child(farming)
	farming.terrain = _terrain
	_player.farm = farming
	var regrowth := TreeRegrowth.new()  # los árboles talados rebrotan de su tocón
	regrowth.name = "TreeRegrowth"
	regrowth.terrain = _terrain
	regrowth.generator = _tree_generator if _tree_generator != null else _generator
	regrowth.player = _player
	add_child(regrowth)
	_needs = Needs.new()
	add_child(_needs)
	_needs.player = _player
	_player.needs = _needs
	_needs.warned.connect(_show_notice)
	_needs.collapsed.connect(func() -> void: _sleep(_player.global_position, false))
	_session = CraftSession.new()
	add_child(_session)
	_session.player = _player
	_session.ground = _ground
	_session.screen = _inventory_screen
	_session.ended.connect(func() -> void:
		_player.ui_open = false
		_player._set_captured(true))
	_player.ground = _ground
	_load_player()  # después de crear hambre, cultivos... (la partida guardada los rellena)
	_ground.load_from(_ground_save_path())
	_player.notice.connect(_show_notice)
	_player.combat.before_death.connect(func() -> void:
		if _session.active():
			_session.end()
		_inventory_screen.close())
	_player.combat.persistence_requested.connect(_save_world)
	_player.sleep_requested.connect(_sleep)
	_player.block_used.connect(_on_block_used)
	_player.block_broken.connect(_on_block_broken)
	_rebind_hotbar()
	_player.inventory_layout_changed.connect(_on_layout_changed)


# ------------------------------------------------------------------ pantalla de carga

func _loading_title() -> String:
	if _world_is_new:
		return "Preparando la isla por primera vez..."
	return "Cargando la isla..."


func _build_loading_overlay() -> void:
	# Pantalla de título: tapa el mundo mientras se prepara y, al estar listo, espera a "Jugar".
	_title = TitleScreen.new()
	add_child(_title)
	_title.set_status(_loading_title())
	_title.play_pressed.connect(_enter_game)
	_title.quit_pressed.connect(func() -> void: get_tree().quit())
	_player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _update_loading() -> void:
	if _waiting_play:
		if OS.get_cmdline_user_args().has("--title"):  # captura de la pantalla de título
			_capture.frames += 1
			if _capture.frames == 60:
				get_viewport().get_texture().get_image().save_png(_arg("--capture="))
				print("[captura] guardada en ", _arg("--capture="))
				get_tree().quit()
		return
	_elapsed += get_process_delta_time()
	_title.set_status("%s   %.0f s" % [_loading_title(), _elapsed])

	# Listo cuando la zona detallada alrededor del punto de aparición ya está dibujada.
	var near_ready := _terrain.is_area_meshed(_near_spawn_area())
	if (near_ready and _elapsed > 0.5) or _elapsed > MAX_LOAD_SECONDS:
		if _auto_enter():
			_finish_loading()
		else:
			_waiting_play = true
			_title.set_ready()
			Sfx.play("aprender", null, -8.0)


## Pruebas, capturas y mediciones entran solas, sin esperar a "Jugar".
func _auto_enter() -> bool:
	if OS.get_cmdline_user_args().has("--title"):
		return false
	return _is_test() or _arg("--capture=") != "" or OS.get_cmdline_user_args().has("--quit-after-load") \
		or DisplayServer.get_name() == "headless"


func _enter_game() -> void:
	if _waiting_play:
		_finish_loading()


func _near_spawn_area() -> AABB:
	var r := _near_voxels * 0.8
	return AABB(Vector3(Structures.spawn_voxel().x - r, 0, Structures.spawn_voxel().y - r), Vector3(2 * r, 256, 2 * r)).intersection(_terrain.bounds)  # sin salirse del mundo (si no, nunca termina)


func _finish_loading() -> void:
	var stutters := StutterLog.new()  # registro de tirones (user://tirones.txt)
	stutters.name = "StutterLog"
	add_child(stutters)
	_loading = false
	if _tower != null:
		_tower.set_physics_process(true)
	if _title != null:
		_title.queue_free()
		_title = null
	_player.ui_open = false
	_player._set_captured(true)
	print("[main] Isla cargada en %.1f s. ¡A jugar!" % _elapsed)
	_place_journal_if_lost()
	if _arg("--capture=") == "":
		_show_notice("F1: ver los controles  ·  Esc: pausa y opciones")
	# Modo medición: "godot --headless --path . -- --quit-after-load" sale al terminar de cargar.
	if OS.get_cmdline_user_args().has("--quit-after-load"):
		get_tree().quit()


# ------------------------------------------------------------------ ambiente y HUD

func _build_environment() -> void:
	# Sol, luna, cielo, luz ambiental, niebla y nubes: todo lo gestiona el ciclo de día y noche.
	_day_night = DayNight.new()
	add_child(_day_night)
	_day_night.setup(self, FOG_BEGIN, FOG_END, FOG_MAX)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	_hud = Label.new()
	_hud.position = Vector2(12, 8)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE  # no robar clics del juego
	_hud.add_theme_color_override("font_color", Color.WHITE)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 4)
	canvas.add_child(_hud)

	# Punto de mira, centrado de verdad (la etiqueta se centra sobre el centro de la pantalla).
	var crosshair := Label.new()
	_crosshair = crosshair
	crosshair.text = "+"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE  # no robar clics del juego
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 22)
	crosshair.add_theme_color_override("font_color", Color.WHITE)
	crosshair.add_theme_color_override("font_outline_color", Color.BLACK)
	crosshair.add_theme_constant_override("outline_size", 3)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-15, -17)
	crosshair.size = Vector2(30, 30)
	canvas.add_child(crosshair)

	_hotbar = Hotbar.new()
	canvas.add_child(_hotbar)
	_hunger_bar = _make_need_bar(canvas, 0, "Hambre", Color(0.85, 0.55, 0.2), "hunger", "orange")
	_thirst_bar = _make_need_bar(canvas, 1, "Sed", Color(0.3, 0.6, 0.9), "thirst", "blue")
	_rest_bar = _make_need_bar(canvas, 2, "Sueño", Color(0.6, 0.5, 0.85), "rest", "purple")  # llena = descansado
	_objectives = Objectives.new()
	add_child(_objectives)
	_objectives.build_ui(canvas)
	_objectives.completed.connect(func(text: String) -> void:
		_show_notice(text)
		Sfx.play("aprender"))

	_prompt = _make_center_label(canvas, -130.0, 20)
	_notice = _make_center_label(canvas, -175.0, 22)
	_notice.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))

	# Pantalla de inventario (y de cofres), por encima del HUD.
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_ui_layer = ui_layer
	_inventory_screen = InventoryScreen.new()
	_inventory_screen.hotbar = _hotbar
	ui_layer.add_child(_inventory_screen)
	_inventory_screen.closed.connect(_on_screen_closed)
	_inventory_screen.overflow.connect(_drop_in_front)
	_inventory_screen.stack_dropped.connect(func(stack: Dictionary) -> void:
		var forward := -_player.global_basis.z
		ItemDrop.throw_stack(self, _player.eye_position() + forward * 0.6, forward, stack))

	# Menú de pausa (Esc), por encima de todo.
	var pause_layer := CanvasLayer.new()
	pause_layer.layer = 20
	add_child(pause_layer)
	_pause = PauseMenu.new()
	pause_layer.add_child(_pause)
	_pause.resumed.connect(_on_screen_closed)
	_pause.quit_requested.connect(func() -> void:
		_save_world()
		get_tree().quit())

	# Ayuda de controles (F1), a la derecha.
	var help := PanelContainer.new()
	var help_style := UiTheme.panel(0.88, 18.0)
	help.add_theme_stylebox_override("panel", help_style)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.add_child(PauseMenu.controls_grid())
	help.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	help.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # crece hacia la izquierda, según su contenido
	help.grow_vertical = Control.GROW_DIRECTION_BOTH
	help.offset_left = -16
	help.offset_right = -16
	help.visible = false
	canvas.add_child(help)
	_help = help

	# Tinte azul cuando la cabeza está bajo el agua.
	_underwater = ColorRect.new()
	_underwater.color = Color(0.06, 0.30, 0.50, 0.42)
	_underwater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_underwater.set_anchors_preset(Control.PRESET_FULL_RECT)
	_underwater.visible = false
	canvas.add_child(_underwater)
	canvas.move_child(_underwater, 0)  # por debajo del HUD y la barra


func _process(delta: float) -> void:
	if _loading:
		_update_loading()
		return
	if _hud == null or _player == null:
		return
	_hotbar.select(_player.get_hotbar_index())
	var reading := _journal != null and _journal.visible  # con el diario abierto, nada encima
	var kneeling := _session != null and _session.active()  # de rodillas: el inventario ya enseña la barra
	_hotbar.visible = not reading and not kneeling
	_hunger_bar.get_parent().get_parent().visible = _hotbar.visible and not _player.creative  # las dos barras
	if _needs != null:
		_hunger_bar.value = _needs.hunger
		_thirst_bar.value = _needs.thirst
		_rest_bar.value = 100.0 - _needs.fatigue
	_crosshair.visible = not kneeling
	_hud.visible = not reading
	_prompt.visible = not reading
	_objectives.show_panel(not reading and not _help_on and not kneeling)
	_underwater.visible = _player.is_head_underwater()
	_prompt.text = ""  # (los avisos de fabricar están ahora en la vista de fabricar)
	_notice_time -= delta
	_notice.modulate.a = clampf(_notice_time, 0.0, 1.0)
	_hud.text = _day_night.get_clock_text()
	if Settings.show_fps:
		_hud.text += "  ·  " + PerfStats.text(get_viewport())
	_help.visible = _help_on and not reading
	_update_ambience(delta)
	# Cada mañana, el mar trae restos del naufragio a la orilla.
	if _day_night.day > _last_drift_day and _day_night.hour >= 6.5 and not _is_test():
		_last_drift_day = _day_night.day
		_drift_ashore()
	if _help.visible:  # ajustada a su contenido, pegada a la derecha y centrada en alto
		var help_size := _help.get_combined_minimum_size()
		_help.offset_left = -16 - help_size.x
		_help.offset_top = -help_size.y * 0.5
		_help.offset_bottom = help_size.y * 0.5
	if _capture != null:
		_capture.update()


# ------------------------------------------------------------------ capturas (para pruebas)


func _arg(prefix: String, default := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default


# ------------------------------------------------------------------ inventario y jugador guardado

func _player_save_path() -> String:
	return _world_dir().path_join("jugador_%s.json" % _world_id)


func _save_player() -> void:
	if _player == null:
		return
	var data := {
		"inventory": _player.inventory.to_data(),
		"creative": _player.creative,
		"equipment": _player.equipment,
		"gear_wear": _player.gear_wear,
		"recipes": _player.known_recipes,
		"journal": _player.has_journal,
		"objectives": _objectives.to_data(),
		"drift_day": _last_drift_day,
		"needs": _needs.to_data(),
		"combat": _player.combat.to_data(),
		"skills": _player.skills.to_data(),
		"death_backpacks": get_tree().get_nodes_in_group("death_backpacks").filter(func(b: Node) -> bool: return not b.is_queued_for_deletion()).map(func(b: Node) -> Dictionary: return (b as DeathBackpack).to_data()),
		"explored": (get_node("Exploration") as Exploration).to_data(),
		"farm": _player.farm.to_data() if _player.farm != null else {},
		"stumps": (get_node("TreeRegrowth") as TreeRegrowth).to_data(),
		"rafts": get_tree().get_nodes_in_group("rafts").map(func(r: Node) -> Dictionary: return (r as Raft).to_data()),
		"spawn": [_player.get_spawn_point().x, _player.get_spawn_point().y, _player.get_spawn_point().z],
		"hour": _day_night.hour,
		"day": _day_night.day,
		"tower": _tower.to_data() if _tower != null else {},
	}
	var file := FileAccess.open(_player_save_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))


func _load_player() -> void:
	if not FileAccess.file_exists(_player_save_path()):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_player_save_path()))
	if not data is Dictionary:
		return
	var d: Dictionary = data
	if d.get("inventory") is Array:
		_player.inventory.from_data(d["inventory"])
	if d.get("equipment") is Dictionary:
		_player.set_equipment(d["equipment"], d.get("gear_wear", {}) if d.get("gear_wear") is Dictionary else {})
	_player.has_journal = bool(d.get("journal", false))
	_last_drift_day = int(d.get("drift_day", 1))
	if d.get("explored") is String:
		(get_node("Exploration") as Exploration).from_data(d["explored"])
	if d.get("needs") is Dictionary:
		_needs.from_data(d["needs"])
	if d.get("combat") is Dictionary:
		_player.combat.from_data(d["combat"])
	if d.get("skills") is Dictionary:
		_player.skills.from_data(d["skills"])
	for bag in d.get("death_backpacks", []):
		if bag is Dictionary:
			DeathBackpack.restore(self, bag)
	if d.get("farm") is Dictionary and _player.farm != null:
		_player.farm.from_data(d["farm"])
	if d.get("stumps") is Dictionary:
		(get_node("TreeRegrowth") as TreeRegrowth).from_data(d["stumps"])
	for r in d.get("rafts", []):
		_spawn_raft(r)
	var spawn: Array = d.get("spawn", [])
	if spawn.size() == 3:
		_player.set_spawn_point(Vector3(float(spawn[0]), float(spawn[1]), float(spawn[2])))
	if d.get("objectives") is Dictionary:
		_objectives.from_data(d["objectives"])
	if d.get("recipes") is Array:
		for recipe_id in d["recipes"]:
			_player.learn(str(recipe_id))
	_player.set_creative(bool(d.get("creative", false)))
	_day_night.day = int(d.get("day", 1))
	_day_night.set_hour(float(d.get("hour", DayNight.START_HOUR)))


func _input(event: InputEvent) -> void:
	# Abrir/cerrar el inventario (E) y cerrar cualquier pantalla con Esc. Se gestiona aquí, antes
	# que el jugador, para que Esc no le suelte además el ratón.
	if _loading or _player == null:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _journal != null and _journal.visible:
		if key.keycode == KEY_ESCAPE or key.keycode == KEY_J:
			_journal.close()
			get_viewport().set_input_as_handled()
	elif not _inventory_screen.visible and key.keycode == KEY_J:
		open_journal()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F1:
		_help_on = not _help_on
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F3:
		Settings.show_fps = not Settings.show_fps
		Settings.save_settings()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and not _inventory_screen.visible:
		_player.ui_open = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_pause.open()
		get_viewport().set_input_as_handled()
	elif _inventory_screen.visible and (key.keycode == KEY_ESCAPE or key.keycode == KEY_E):
		_inventory_screen.close()
		get_viewport().set_input_as_handled()
	elif not _inventory_screen.visible and key.keycode == KEY_E and not _session.active():
		open_inventory()
		get_viewport().set_input_as_handled()


func open_inventory() -> void:
	var title := "Inventario (creativo: bloques infinitos)" if _player.creative else "Inventario"
	_screen_sections = _player_sections.bind(title)
	var side: Control = null
	if not _player.creative:  # equipo (en creativo no hace falta)
		side = EquipmentPanel.new(_player, _inventory_screen)
	_show_screen(_screen_sections.call(), side)
	_session.begin()  # de rodillas (si se puede); si no, el inventario normal


## Huecos del jugador que se ven en pantalla: solo los disponibles según su ropa y mochila.
func _player_sections(title: String) -> Array[Dictionary]:
	var inv := _player.active_inventory()
	var storage := {"title": title, "inventory": inv, "columns": 9,
		"slots": range(Hotbar.SLOTS, Hotbar.SLOTS + _player.storage_size())}
	if not _player.creative and _player.equipment["backpack"] == "":
		storage["hint"] = "Sin mochila solo cabe esto. Busca una en el naufragio."
	var bar := {"title": "Barra", "inventory": inv, "columns": 9, "slots": range(0, _player.hotbar_size())}
	if not _player.creative and _player.hotbar_size() < Hotbar.SLOTS:
		bar["hint"] = "La ropa con bolsillos da más huecos a mano."
	var out: Array[Dictionary] = [storage, bar]
	return out


func _show_screen(sections: Array[Dictionary], side: Control = null) -> void:
	_player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_inventory_screen.open(sections, side)


func _rebind_hotbar() -> void:
	_hotbar.bind(_player.active_inventory(), _player.creative, _player.hotbar_size())


## Al cambiar de ropa o de modo: la barra y la pantalla abierta muestran los huecos nuevos.
func _on_layout_changed() -> void:
	_rebind_hotbar()
	if _inventory_screen.visible and _screen_sections.is_valid():
		_inventory_screen.set_sections(_screen_sections.call())


## Tira al suelo, delante del jugador, lo que no cabe.
func _drop_in_front(id: String, count: int) -> void:
	var forward := -_player.global_basis.z
	ItemDrop.spawn(self, _player.global_position + forward * 1.2 + Vector3.UP * 1.2, id, count)


func _on_screen_closed() -> void:
	if _open_chest != null and is_instance_valid(_open_chest):
		_open_chest.close()  # la tapa baja
	_open_chest = null
	_screen_sections = Callable()
	if _session != null and _session.active():
		_session.end()  # el jugador recupera el control cuando la cámara vuelve (ended)
		return
	_player.ui_open = false
	_player._set_captured(true)


# ------------------------------------------------------------------ cofres

func _chests_save_path() -> String:
	return _world_dir().path_join("jugador_%s_cofres.json" % _world_id)


func _on_block_used(cell: Vector3i, block_id: int) -> void:
	if block_id != IslandGenerator.CHEST and block_id != IslandGenerator.CHEST_OPEN:
		return
	Sfx.play("cofre", (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * VOXEL_SIZE)
	_objectives.mark("cofre_abierto")
	var chest := _chests.get_or_create(cell)
	if _open_chest == null or not is_instance_valid(_open_chest):
		_open_chest = ChestVisual.open_at(self, _terrain, cell, chest)  # la tapa se levanta: se ve lo de dentro
	_screen_sections = _chest_sections.bind(chest)
	_show_screen(_screen_sections.call())


func _chest_sections(chest: Inventory) -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"title": "Cofre", "inventory": chest, "slots": range(0, chest.size()), "columns": 9},
	]
	out.append_array(_player_sections("Inventario"))
	return out


func _on_block_broken(cell: Vector3i, block_id: int) -> void:
	_ground.on_block_removed(cell)  # lo dejado encima cae
	if block_id != IslandGenerator.CHEST and block_id != IslandGenerator.CHEST_OPEN:
		return
	# Al romper un cofre, su contenido cae al suelo.
	var contents := _chests.remove(cell)
	var center := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * VOXEL_SIZE
	for i in contents.size():
		var stack := contents.get_slot(i)
		if not stack.is_empty():
			ItemDrop.spawn(self, center, stack["id"], int(stack["count"]))


func _world_dir() -> String:
	return TEST_WORLD_DIR if _is_test() else WORLD_DIR


## Sala de muestras (ShowroomGenerator): "godot --path . -- --showroom".
func _showroom() -> bool:
	return OS.get_cmdline_user_args().has("--showroom")


func _is_test() -> bool:
	var args := OS.get_cmdline_user_args()
	return test_mode or args.has("--quit-after-load") or _arg("--capture=") != ""


func _clear_test_world() -> void:
	var dir := DirAccess.open(TEST_WORLD_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)


# ------------------------------------------------------------------ fabricar en el suelo

func _ground_save_path() -> String:
	return _world_dir().path_join("jugador_%s_suelo.json" % _world_id)


## Etiqueta centrada a lo ancho, a 'from_bottom' píxeles del borde de abajo.
func _make_center_label(canvas: CanvasLayer, from_bottom: float, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -500.0
	label.offset_right = 500.0
	label.offset_top = from_bottom
	label.offset_bottom = from_bottom + 30.0
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	canvas.add_child(label)
	return label


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice_time = 4.0


# ------------------------------------------------------------------ diario del capitán

func open_journal() -> void:
	if not _player.has_journal:
		_show_notice("Aún no tienes ningún diario. Quizá haya algo entre los restos del naufragio...")
		return
	if _journal == null:
		_journal = Journal.new(_player)
		_ui_layer.add_child(_journal)
		_journal.closed.connect(_on_screen_closed)
	_player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_journal.open()
	_objectives.mark("diario_leido")


## Al empezar: si el jugador aún no tiene el diario y no está en el suelo, se deja en la playa,
## unos pasos delante, camino del barco.
func _place_journal_if_lost() -> void:
	if _player.has_journal or _ground.has_item("captain_journal"):
		return
	var f := -_player.global_basis.z
	var p := _player.global_position + Vector3(f.x, 0, f.z).normalized() * 3.0
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 6.0))
	if hit.is_empty():
		return
	var point: Vector3 = hit.position
	var support := Vector3i((point / VOXEL_SIZE - Vector3(0, 0.5, 0)).floor())
	_ground.place(point, "captain_journal", randf() * TAU, support)


## Ambiente sonoro: olas según lo cerca que esté el mar; pájaros de día y grillos de noche.
func _update_ambience(delta: float) -> void:
	_sfx.daylight = 0.0 if _day_night.is_night() else 1.0
	_sea_check -= delta
	if _sea_check > 0.0:
		return
	_sea_check = 0.5
	# Muestras alrededor del jugador: cuántas son mar (el terreno queda bajo el nivel del mar).
	var center := Vector2i(int(_player.global_position.x / VOXEL_SIZE), int(_player.global_position.z / VOXEL_SIZE))
	var sea := 0
	for i in 12:
		var a := TAU * i / 12.0
		var p := center + Vector2i(int(cos(a) * 36.0), int(sin(a) * 36.0))
		if _generator.get_ground_height(p.x, p.y) < IslandGenerator.SEA_LEVEL:
			sea += 1
	var height_above := _player.global_position.y / VOXEL_SIZE - IslandGenerator.SEA_LEVEL
	_sfx.sea_amount = (sea / 12.0) * clampf(1.0 - height_above / 30.0, 0.0, 1.0) * 1.6


# ------------------------------------------------------------------ el mar trae cosas

## Lo que puede venir en una caja a la deriva: [objeto, mínimo, máximo, probabilidad].
const DRIFT_LOOT := [
	["cloth", 1, 3, 0.7], ["rope", 1, 2, 0.5], ["planks", 2, 5, 0.5], ["board", 1, 2, 0.35],
	["wood", 1, 2, 0.3], ["berries", 2, 5, 0.5], ["shell", 1, 2, 0.3], ["sticks", 1, 3, 0.3],
	["pants", 1, 1, 0.12], ["belt", 1, 1, 0.08], ["resin", 1, 2, 0.15], ["flint", 1, 1, 0.15],
]


## 2 o 3 cajas aparecen en la arena de la orilla, cerca del naufragio, con restos al azar.
func _drift_ashore() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tool := WorldVoxels.tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	var ship := Structures.ship_voxel()
	var placed := 0
	var wanted := rng.randi_range(2, 3)
	for attempt in 80:
		if placed >= wanted:
			break
		var x := ship.x + rng.randi_range(-70, 70)
		var z := ship.y + rng.randi_range(-70, 70)
		var h := _generator.get_ground_height(x, z)
		if h < IslandGenerator.SEA_LEVEL or h > IslandGenerator.SEA_LEVEL + 2:
			continue  # solo en la franja de arena junto al agua
		var cell := Vector3i(x, h, z)
		if tool.get_voxel(cell - Vector3i.UP) != IslandGenerator.SAND or tool.get_voxel(cell) != IslandGenerator.AIR:
			continue
		tool.set_voxel(cell, IslandGenerator.CHEST)
		var box := _chests.get_or_create(cell)
		var any := false
		for entry in DRIFT_LOOT:
			if rng.randf() < float(entry[3]):
				box.add(entry[0], rng.randi_range(int(entry[1]), int(entry[2])))
				any = true
		if not any:
			box.add("cloth", 1)
		placed += 1
	if placed > 0:
		_show_notice("El mar ha traído restos a la orilla durante la noche.")
		Sfx.play("aprender", null, -8.0)


# ------------------------------------------------------------------ dormir

## Clic derecho en un saco de dormir: de noche, se duerme hasta la mañana (fundido a negro); de
## día no. En los dos casos el saco queda como el sitio donde reaparecer.
## Dormir en el saco (bed) o caer desmayado de cansancio (sin cama). De noche se duerme hasta el
## amanecer; de día solo si se está cansado, y es una siesta de unas horas. Lo bien que se
## descanse depende del sitio (SleepSpot).
func _sleep(at: Vector3, bed := true) -> void:
	if _sleeping:
		return
	if bed:
		_player.set_spawn_point(at + Vector3.UP * 0.3)
	var h := _day_night.hour
	var night := h >= 19.0 or h < 6.0
	if bed and not night and _needs.fatigue < Needs.TIRED:
		_show_notice("Aún es de día y no tienes sueño. (Este saco será tu sitio para reaparecer.)")
		return
	if not bed:  # desmayo: se cierra lo que hubiera abierto (fabricación, inventario)
		if _session.active():
			_session.end()
		_inventory_screen.close()
	var spot := SleepSpot.evaluate(get_world_3d().direct_space_state, at, [_player.get_rid()], bed)
	var rest: Dictionary = SleepSpot.REST[spot]
	_sleeping = true
	_player.ui_open = true
	if _player.combat != null:
		_player.combat.cancel_actions()
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(black)
	var tween := create_tween()
	tween.tween_property(black, "color:a", 1.0, 0.6 if not bed else 1.2)
	tween.tween_callback(func() -> void:
		if night:
			if h >= 19.0:
				_day_night.day += 1
			_day_night.set_hour(6.5)
		else:
			var wake := h + 4.0  # siesta
			if wake >= 24.0:
				_day_night.day += 1
			_day_night.set_hour(fmod(wake, 24.0))
		_needs.wake(rest)
		if _player.combat != null:
			var combat := _player.combat
			combat.health = minf(minf(combat.health + float(rest["heal"]), float(rest["cap"])), PlayerCombat.MAX_HEALTH)
			combat.health = maxf(combat.health, 1.0)
		if bed:
			_objectives.mark("dormido")
		_save_world())
	tween.tween_interval(0.8)
	tween.tween_property(black, "color:a", 0.0, 1.5)
	tween.tween_callback(func() -> void:
		black.queue_free()
		_player.ui_open = false
		_sleeping = false
		_show_notice(str(rest["text"])))


## Barrita de hambre o sed, abajo a la izquierda (fila 0 o 1).
func _make_need_bar(canvas: CanvasLayer, row: int, text: String, color: Color, icon_name: String, fill_name: String) -> ProgressBar:
	var holder: Control
	if row == 0:
		holder = VBoxContainer.new()
		holder.name = "Necesidades"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
		holder.offset_left = 16
		holder.offset_bottom = -18
		(holder as VBoxContainer).add_theme_constant_override("separation", 4)
		canvas.add_child(holder)
	else:
		holder = canvas.get_node("Necesidades")
	var row_box := HBoxContainer.new()
	row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row_box)
	var icon := UiTheme.icon(icon_name)
	if icon != null:  # el icono dibujado (pan, gota); si no, el nombre
		var picture := TextureRect.new()
		picture.texture = icon
		picture.custom_minimum_size = Vector2(26, 26)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.tooltip_text = text
		row_box.add_child(picture)
	else:
		var label := Label.new()
		label.text = text
		label.custom_minimum_size = Vector2(60, 0)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		row_box.add_child(label)
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(150, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	if icon != null:
		bar.custom_minimum_size = Vector2(150, 22)
		UiTheme.style_bar(bar, fill_name)
	row_box.add_child(bar)
	return bar


## Pone en el mar una balsa guardada.
func _spawn_raft(data: Variant) -> void:
	if not data is Dictionary or not (data as Dictionary).get("pos") is Array:
		return
	var pos: Array = data["pos"]
	var boat := Raft.new()
	boat.generator = _generator
	boat.voxel_size = _terrain.scale.x
	add_child(boat)
	boat.add_to_group("rafts")
	boat.global_position = Vector3(float(pos[0]), boat.sea_y(), float(pos[1]))
	boat.rotation.y = float(data.get("yaw", 0.0))


## Prueba visual (sala de muestras): el barco naufragado y restos hechos de cubitos pequeños
## (MicroVoxels), como en el arte conceptual "posible". Solo decoración: no se rompen.
func _build_micro_showcase() -> void:
	var c := ShowroomGenerator.center()
	var floor_y := float(_generator.get_ground_height(c.x, c.y) + 1) * VOXEL_SIZE
	var size := VOXEL_SIZE / MicroVoxels.RES
	var holder := Node3D.new()
	holder.name = "MicroVoxeles"
	add_child(holder)
	# Barco: de costado, escorado y medio enterrado, a la derecha de la fila de muestras.
	var ship := WreckModel.make_node()
	ship.position = Vector3((c.x - 44) * VOXEL_SIZE, floor_y - 1.1, (c.y + 10) * VOXEL_SIZE)
	ship.rotation.y = deg_to_rad(18.0)
	holder.add_child(ship)
	# Restos por la arena: cajas, un barril, troncos.
	var wood := Color(0.5, 0.33, 0.19)
	var bits := [
		[MicroVoxels.crate(Vector3i(12, 11, 12), wood), Vector3(-17, 0, 3), 20.0],
		[MicroVoxels.crate(Vector3i(10, 9, 14), wood.darkened(0.1)), Vector3(-19, 0, 6), -35.0],
		[MicroVoxels.barrel(4.5, 14, Color(0.45, 0.29, 0.16)), Vector3(-15, 0, 7), 0.0],
		[MicroVoxels.log_x(48, 3.2, Color(0.33, 0.24, 0.16), Color(0.72, 0.56, 0.36)), Vector3(-14, 0, -1), 60.0],
		[MicroVoxels.log_x(30, 2.6, Color(0.36, 0.26, 0.17), Color(0.75, 0.6, 0.4)), Vector3(-22, 0, 1), -10.0],
	]
	for bit: Array in bits:
		var node := MicroVoxels.make_node(bit[0], size)
		var at: Vector3 = bit[1]
		node.position = Vector3((c.x + at.x) * VOXEL_SIZE, floor_y, (c.y + at.z) * VOXEL_SIZE)
		node.rotation.y = deg_to_rad(bit[2])
		holder.add_child(node)


## El barco naufragado de cubitos pequeños, encallado en la orilla, y los restos de la arena
## (Salvage: se desmontan a golpes y dan material).
func _build_micro_wreck() -> void:
	var spot := Structures.micro_wreck()
	if spot == Vector3.ZERO:
		return
	var ship := WreckModel.make_node(-6.0)
	ship.position = spot * VOXEL_SIZE - Vector3(0, 0.2, 0)  # la quilla, un poco enterrada
	ship.rotation.y = Structures.micro_wreck_yaw()
	add_child(ship)
	_micro_ship = ship
	_aim_at_micro_ship()
	_build_debris()


func _build_debris() -> void:
	_salvage = Salvage.new()
	_salvage.name = "Restos"
	add_child(_salvage)
	_salvage.load_from(_world_dir().path_join("jugador_%s_restos.json" % _world_id))
	var wood := Color(0.5, 0.33, 0.19)
	for d: Array in Structures.debris():
		var x := int(d[2])
		var z := int(d[3])
		var ground := _generator.get_ground_height(x, z)
		if ground < IslandGenerator.SEA_LEVEL:
			continue
		var cells: Dictionary
		match String(d[1]):
			"plank": cells = MicroVoxels.plank(28 + (x * 7 + z) % 14, wood.lerp(Color(0.4, 0.38, 0.33), float(abs(x + z) % 5) * 0.08))
			"planks": cells = MicroVoxels.plank_pile(wood)
			"crate": cells = MicroVoxels.crate(Vector3i(11, 10, 11), wood.darkened(0.08))
			"barrel": cells = MicroVoxels.barrel(4.0, 13, Color(0.45, 0.29, 0.16))
			"log": cells = MicroVoxels.log_x(40, 3.0, Color(0.36, 0.27, 0.18), Color(0.74, 0.6, 0.42))
			"cloth": cells = MicroVoxels.cloth(Vector2i(22, 16), Color(0.85, 0.79, 0.66))
		var pos := Vector3(x + 0.5, ground + 1, z + 0.5) * VOXEL_SIZE - Vector3(0, 0.03, 0)
		_salvage.add(String(d[0]), String(d[1]), cells, pos, float(d[4]))
	_salvage.player = _player
	if _player != null:
		_player.salvage = _salvage


## Capturas de prueba ("--mirar-barco"): el jugador, en el agua delante del barco de cubitos.
func _aim_at_micro_ship() -> void:
	if not OS.get_cmdline_user_args().has("--mirar-barco") or _micro_ship == null or _player == null:
		return
	_player.position = _micro_ship.position + Vector3(2, 0, 15).rotated(Vector3.UP, _micro_ship.rotation.y)
	_player.position.y = IslandGenerator.SEA_LEVEL * VOXEL_SIZE + 1.2
	_player._flying = true  # quieto sobre el agua (si no, se hunde hasta el fondo)
	var to := _micro_ship.position + Vector3(8, 0, 0).rotated(Vector3.UP, _micro_ship.rotation.y) - _player.position
	_player.rotation.y = atan2(-to.x, -to.z)
