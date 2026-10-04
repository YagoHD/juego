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

# Radio de voxels detallados alrededor del jugador (en voxels; 320 = 160 m).
const NEAR_VIEW_VOXELS := 320
# La malla lejana se recorta un poco antes de donde acaban los voxels, para que se solapen.
const FAR_HIDE_RADIUS := NEAR_VIEW_VOXELS * VOXEL_SIZE - 15.0

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
var _session: CraftSession     # inventario de rodillas y vista de fabricar
var _crosshair: Label
var _needs: Needs
var _hunger_bar: ProgressBar
var _thirst_bar: ProgressBar
var _hotbar: Hotbar
var _underwater: ColorRect
var _day_night: DayNight
var _inventory_screen: InventoryScreen
var _screen_sections := Callable()  # rehace las secciones de la pantalla abierta
var _chests := ChestStorage.new()
var _world_id := ""  # huella del mundo (nombre de sus archivos de guardado)
var _terrain: VoxelTerrain
var _generator: IslandGenerator
var _loading := true
var _title: TitleScreen
var _waiting_play := false   # el mundo ya está listo; la pantalla de título espera a "Jugar"
var _elapsed := 0.0
var _world_is_new := false


func _ready() -> void:
	Settings.load_settings()
	if _arg("--textures=") != "":  # capturas: probar un paquete de texturas
		Settings.texture_pack = _arg("--textures=")
	UiTheme.apply_cursor()
	_sfx = Sfx.new()
	add_child(_sfx)
	_build_world()
	_build_far_terrain()
	_build_environment()
	_build_hud()
	_build_player()
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
		_terrain.save_modified_blocks()
		_save_player()
		_chests.save_to(_chests_save_path())
		_ground.save_to(_ground_save_path())


# ------------------------------------------------------------------ mundo

func _build_world() -> void:
	var library := VoxelBlockyLibrary.new()
	library.add_model(VoxelBlockyModelEmpty.new())  # 0 AIR
	# Todos los bloques comparten un material con el atlas de texturas (se dibujan más rápido);
	# el agua lleva su propia versión translúcida.
	var solid := BlockTextures.make_material()
	_generator = IslandGenerator.new()
	var water := _make_water_material()
	for id in range(1, Blocks.LAST_ID + 1):
		if id == IslandGenerator.WATER_FALL:
			library.add_model(_make_flow(1.0, water))
		elif id >= IslandGenerator.WATER_FLOW_1 and id <= Blocks.LAST_ID:
			library.add_model(_make_flow(WaterFlow.level_of(id) / 8.0, water))
		elif id == IslandGenerator.WATER:
			library.add_model(_make_water(water))
		elif id == IslandGenerator.WORKBENCH:
			library.add_model(_make_bench())
		elif id == IslandGenerator.CLOTH:
			library.add_model(_make_carpet(id, solid))
		elif id == IslandGenerator.ORE:
			library.add_model(_make_cube(id, _glowing(solid)))  # el mineral brilla un poco
		elif Blocks.is_decor(id):
			library.add_model(DecorModels.make_model(id))  # hierba, flores, piedrecitas...
		else:
			library.add_model(_make_cube(id, solid))
	# Huecos hasta los prefabs (ids libres para bloques futuros) y las piezas de los prefabs.
	for id in range(Blocks.LAST_ID + 1, PrefabLibrary.FIRST_ID):
		library.add_model(VoxelBlockyModelEmpty.new())
	for id in range(PrefabLibrary.FIRST_ID, PrefabLibrary.last_id() + 1):
		library.add_model(PrefabLibrary.make_model(id))  # palmeras, rocas... troceadas
	library.bake()

	var mesher := VoxelMesherBlocky.new()
	mesher.library = library


	var terrain := VoxelTerrain.new()
	terrain.mesher = mesher
	terrain.generator = _generator
	terrain.stream = _make_world_stream()
	terrain.generate_collisions = true
	# Solo existen voxels dentro de la isla y entre el fondo marino y las cimas.
	terrain.bounds = AABB(Vector3(-IslandGenerator.MAP_HALF, 0, -IslandGenerator.MAP_HALF), Vector3(IslandGenerator.MAP_HALF * 2.0, 256, IslandGenerator.MAP_HALF * 2.0))
	# Mallas de 32³ voxels: 8 veces menos objetos de malla y colisión que con 16³.
	terrain.mesh_block_size = 32
	terrain.max_view_distance = NEAR_VIEW_VOXELS + 64
	terrain.scale = Vector3.ONE * VOXEL_SIZE  # voxels más pequeños (estilo Cube World)
	terrain.add_to_group("voxel_terrain")
	add_child(terrain)
	_terrain = terrain
	var water_flow := WaterFlow.new()  # el agua que corre al abrirle hueco
	water_flow.name = "WaterFlow"
	water_flow.terrain = terrain
	add_child(water_flow)

	_build_sea()


func _build_far_terrain() -> void:
	var far := FarTerrain.new()
	# Colores de lejos = color medio de la cara de arriba de cada textura, para que la isla lejana
	# tenga el mismo tono que los bloques texturizados de cerca.
	var colors := {}
	for id in Blocks.COLORS:
		colors[id] = BlockTextures.average_color(id, 0)
	colors[IslandGenerator.WATER] = Blocks.color_of(IslandGenerator.WATER)
	far.build(_generator, colors, VOXEL_SIZE, FAR_HIDE_RADIUS)
	add_child(far)


func _make_world_stream() -> VoxelStreamSQLite:
	# El mundo se guarda en un archivo: lo ya visitado se lee de ahí (rápido) y conserva lo
	# que el jugador construya. El nombre lleva una "huella" de los mapas y del generador:
	# si cambian, se crea un mundo nuevo.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_world_dir()))
	if _is_test():
		if not keep_test_world:
			_clear_test_world()  # cada prueba empieza con el mundo recién creado
	_world_id = _world_fingerprint()
	var file_name := "isla_%s.sqlite" % _world_id
	var path := _world_dir().path_join(file_name)
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


func _make_cube(id: int, material: Material) -> VoxelBlockyModelCube:
	# Cubo con las texturas del atlas: arriba, lados y abajo según BlockTextures.FACES.
	var cube := VoxelBlockyModelCube.new()
	cube.atlas_size_in_tiles = BlockTextures.atlas_size_in_tiles()
	var sides := {
		VoxelBlockyModel.SIDE_POSITIVE_Y: Vector3i.UP, VoxelBlockyModel.SIDE_NEGATIVE_Y: Vector3i.DOWN,
		VoxelBlockyModel.SIDE_POSITIVE_X: Vector3i.RIGHT, VoxelBlockyModel.SIDE_NEGATIVE_X: Vector3i.LEFT,
		VoxelBlockyModel.SIDE_POSITIVE_Z: Vector3i.BACK, VoxelBlockyModel.SIDE_NEGATIVE_Z: Vector3i.FORWARD,
	}
	for side: int in sides:
		cube.set_tile(side, BlockTextures.side_tile(id, sides[side]))
	cube.set_material_override(0, material)
	return cube


func _make_carpet(id: int, material: Material) -> VoxelBlockyModelCube:
	# Capa fina tumbada en el suelo (como la alfombra de Minecraft): 1/16 de bloque de alto.
	# No tapa las caras de los bloques vecinos (si no, el suelo de debajo se vería hueco).
	var cube := _make_cube(id, material)
	cube.height = 1.0 / 16.0
	cube.culls_neighbors = false
	return cube


## Material del agua (ríos, lagos y la que corre): color liso con ondas que siguen la corriente.
func _make_water_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/water.gdshader")
	mat.set_shader_parameter("flow_map", ImageTexture.create_from_image(_generator.build_flow()))
	mat.set_shader_parameter("map_half", IslandGenerator.MAP_HALF)
	mat.set_shader_parameter("voxel_size", VOXEL_SIZE)
	mat.set_shader_parameter("water_color", Color(0.13, 0.6, 0.72, 0.74))  # turquesa, como en el concepto
	mat.set_shader_parameter("foam_color", Color(0.78, 0.96, 0.97))
	return mat


## Agua que corre: una caja de la altura de su nivel (1 = bloque entero, la que cae).
func _make_flow(height: float, material: Material) -> VoxelBlockyModelMesh:
	var box := BoxMesh.new()
	box.size = Vector3(1.0, height, 1.0)
	var arrays := box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] += Vector3(0.5, height * 0.5, 0.5)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var model := VoxelBlockyModelMesh.new()
	model.mesh = mesh
	model.set_material_override(0, material)
	model.transparency_index = 1  # como el agua quieta: no se dibujan las caras entre aguas
	model.culls_neighbors = true
	model.set_mesh_collision_enabled(0, false)
	model.collision_aabbs = []
	return model


func _make_water(material: Material) -> VoxelBlockyModelCube:
	# Agua de ríos y lagos: translúcida, sin caras internas y atravesable.
	var cube := _make_cube(IslandGenerator.WATER, material)
	cube.transparency_index = 1
	cube.set_mesh_collision_enabled(0, false)
	return cube


func _build_player() -> void:
	# El jugador existe desde el principio (sus observadores cargan el terreno a su alrededor),
	# pero flota quieto hasta que hay suelo con colisión debajo.
	var ground := _generator.get_ground_height(Structures.spawn_voxel().x, Structures.spawn_voxel().y)
	_player = Player.new()
	_player.near_view_voxels = NEAR_VIEW_VOXELS
	_player.position = Vector3(Structures.spawn_voxel().x, ground + 4, Structures.spawn_voxel().y) * VOXEL_SIZE
	add_child(_player)
	_player.rotation.y = Structures.spawn_yaw()  # mirando al barco naufragado
	_chests.load_from(_chests_save_path())
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
	_needs = Needs.new()
	add_child(_needs)
	_needs.player = _player
	_player.needs = _needs
	_needs.warned.connect(_show_notice)
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
			_capture_frames += 1
			if _capture_frames == 60:
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
	var r := NEAR_VIEW_VOXELS * 0.8
	return AABB(Vector3(Structures.spawn_voxel().x - r, 0, Structures.spawn_voxel().y - r), Vector3(2 * r, 256, 2 * r)).intersection(_terrain.bounds)  # sin salirse del mundo (si no, nunca termina)


func _finish_loading() -> void:
	_loading = false
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
	_hunger_bar = _make_need_bar(canvas, 0, "Hambre", Color(0.85, 0.55, 0.2))
	_thirst_bar = _make_need_bar(canvas, 1, "Sed", Color(0.3, 0.6, 0.9))
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
	ui_layer.add_child(_inventory_screen)
	_inventory_screen.closed.connect(_on_screen_closed)
	_inventory_screen.overflow.connect(_drop_in_front)

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
		_hud.text += "  ·  %d FPS" % Engine.get_frames_per_second()
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
	_update_capture()


# ------------------------------------------------------------------ capturas (para pruebas)

# Modo captura: arranca, coloca la cámara, guarda una imagen y sale. Sirve para revisar el
# aspecto del juego sin tener que jugar. Ejemplo:
#   godot --path . -- --capture=C:/tmp/foto.png --tp --pitch=-0.3 --yaw=40 --up=30
var _capture_frames := -1

func _update_capture() -> void:
	var path := _arg("--capture=")
	if path == "":
		return
	if _capture_frames < 0:
		if not _player.is_on_ground_ready():
			return
		var at := _arg("--at=")  # "x,z" en voxels: teletransporte (volando) a ese punto
		if at != "":
			var xz := at.split(",")
			var vx := int(xz[0])
			var vz := int(xz[1])
			var ground := _generator.get_ground_height(vx, vz)
			_player.global_position = Vector3(vx, ground + 2, vz) * VOXEL_SIZE
		_player.debug_pose(OS.get_cmdline_user_args().has("--tp"), float(_arg("--pitch=", "0")),
			float(_arg("--yaw=", str(rad_to_deg(_player.rotation.y)))), float(_arg("--up=", "0")) + (0.01 if at != "" else 0.0))
		var wear := _arg("--wear=")  # ropa para la foto: "shirt,pants,belt,backpack"
		if wear != "":
			for id in wear.split(","):
				_player.equip(ItemDB.wear_slot(id), id)
		var give := _arg("--give=")  # objetos para la foto: "stone:12,dirt:30"
		if give != "":
			_player.inventory.clear()
			for entry in give.split(","):
				var pair := entry.split(":")
				_player.pick_up(pair[0], int(pair[1]))
		if OS.get_cmdline_user_args().has("--rain"):  # que llueva ya
			_player.weather.force(true)
		if OS.get_cmdline_user_args().has("--campfire"):  # hoguera encendida delante
			var cf := -_player.global_basis.z
			var cp: Vector3 = _player.global_position + Vector3(cf.x, 0, cf.z).normalized() * 2.2
			var chit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cp + Vector3.UP * 3.0, cp + Vector3.DOWN * 6.0))
			if not chit.is_empty():
				var cpt: Vector3 = chit.position
				var fire := _ground.place(cpt, "campfire", 0.0, Vector3i((cpt / VOXEL_SIZE - Vector3(0, 0.5, 0)).floor()))
				fire.campfire.set_state({"lit": true, "fuel": 300.0})
		if OS.get_cmdline_user_args().has("--torches"):  # dos antorchas clavadas delante
			var fwd := -_player.global_basis.z
			for k in [-1.2, 1.2]:
				var p: Vector3 = _player.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 3.0 + _player.global_basis.x * float(k)
				var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 6.0))
				if not hit.is_empty():
					var pt: Vector3 = hit.position
					_ground.place(pt, "torch", 0.0, Vector3i((pt / VOXEL_SIZE - Vector3(0, 0.5, 0)).floor()))
		if OS.get_cmdline_user_args().has("--showcase"):  # modelos voxelizados delante (pruebas de estilo)
			var fwd := -_player.global_basis.z
			fwd.y = 0.0
			var names := ["palmera", "roca", "setas"]
			for k in names.size():
				var model_path := "res://assets/models/voxel/%s.res" % names[k]
				if not ResourceLoader.exists(model_path):
					continue
				var show := MeshInstance3D.new()
				show.mesh = load(model_path)
				add_child(show)
				var p: Vector3 = _player.global_position + fwd.normalized() * (4.0 + k * 0.5) + _player.global_basis.x * (float(k) - 1.0) * 2.2
				var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 8.0))
				show.global_position = hit.position if not hit.is_empty() else p
		if OS.get_cmdline_user_args().has("--bench"):
			_debug_bench()
		var shape := _arg("--shape=")  # receta dibujada en el suelo delante del jugador
		if shape != "":
			_debug_lay_shape(shape)
		if OS.get_cmdline_user_args().has("--working"):
			_player.debug_work_pose()
		if _arg("--drop=") != "":  # soltar un objeto delante del jugador para verlo en el suelo
			var forward := -_player.global_basis.z
			ItemDrop.spawn(self, _player.global_position + forward * 1.6 + Vector3.UP, _arg("--drop="), 1)
		if OS.get_cmdline_user_args().has("--journal"):  # recoger el diario y abrirlo en la página --page
			_player.find_journal()
			for r in _arg("--learn=").split(",", false):
				_player.learn(r)
			open_journal()
			_journal._spread = int(_arg("--page=", "0"))
			_journal.open()
		if _arg("--cracks=") != "":  # grietas en el bloque apuntado, con ese avance (0..1)
			var t := _player._target()
			if t.has("voxel"):
				_player.debug_cracks = true
				_player._cracks.show_on(_terrain.to_global(Vector3(t["voxel"])), VOXEL_SIZE, float(_arg("--cracks=")))
		if OS.get_cmdline_user_args().has("--pause"):  # menú de pausa a la vista (sin pausar: la foto debe salir)
			_pause.visible = true
		if OS.get_cmdline_user_args().has("--help"):
			_help_on = true
		if OS.get_cmdline_user_args().has("--inventory"):
			open_inventory()
		if OS.get_cmdline_user_args().has("--craft"):  # inventario de rodillas y vista de fabricar
			_player.inventory.add("fiber", 3)
			open_inventory()
			_session._enter_craft()
			_player.learn("rope")
			var c := GroundRecipes.CELL
			var base := (_session._area_center / c).floor() * c + Vector3(0.5, 0, 0.5) * c
			for i in 3:
				var p := base + Vector3(c * (i - 1) + randf_range(-0.07, 0.07), 0, randf_range(-0.07, 0.07))
				p.y = _session._ground_y(p)
				_session._placed.append(_ground.place(p, "fiber", randf() * TAU, Vector3i((p / VOXEL_SIZE - Vector3(0, 0.5, 0)).floor())))
		if OS.get_cmdline_user_args().has("--open-chest"):  # abrir el cofre de la playa del naufragio
			var cells: Array = Structures._chest_loot.keys()
			_on_block_used(cells[cells.size() - 1], IslandGenerator.CHEST)
		var time := _arg("--time=")  # hora del día para la foto, p. ej. "19.4" (atardecer)
		if time != "":
			_day_night.set_hour(float(time))
		var action := _arg("--action=")  # "nombre:t", p. ej. "voltereta:0.5"
		if action != "":
			var parts := action.split(":")
			_player.debug_avatar_action(parts[0], float(parts[1]))
		_capture_frames = int(_arg("--wait=", "90"))
		return
	_capture_frames -= 1
	var swing_at := int(_arg("--swing=", "-1"))  # frames antes de la foto en que lanzar un golpe
	if _capture_frames == swing_at:
		_player.debug_swing()
	if _capture_frames == 0:
		get_viewport().get_texture().get_image().save_png(path)
		print("[captura] guardada en ", path)
		get_tree().quit()


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
		"recipes": _player.known_recipes,
		"journal": _player.has_journal,
		"objectives": _objectives.to_data(),
		"drift_day": _last_drift_day,
		"needs": _needs.to_data(),
		"explored": (get_node("Exploration") as Exploration).to_data(),
		"farm": _player.farm.to_data() if _player.farm != null else {},
		"rafts": get_tree().get_nodes_in_group("rafts").map(func(r: Node) -> Dictionary: return (r as Raft).to_data()),
		"spawn": [_player.get_spawn_point().x, _player.get_spawn_point().y, _player.get_spawn_point().z],
		"hour": _day_night.hour,
		"day": _day_night.day,
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
		_player.set_equipment(d["equipment"])
	_player.has_journal = bool(d.get("journal", false))
	_last_drift_day = int(d.get("drift_day", 1))
	if d.get("explored") is String:
		(get_node("Exploration") as Exploration).from_data(d["explored"])
	if d.get("needs") is Dictionary:
		_needs.from_data(d["needs"])
	if d.get("farm") is Dictionary and _player.farm != null:
		_player.farm.from_data(d["farm"])
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
	if block_id != IslandGenerator.CHEST:
		return
	Sfx.play("cofre", (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * VOXEL_SIZE)
	_objectives.mark("cofre_abierto")
	var chest := _chests.get_or_create(cell)
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
	if block_id != IslandGenerator.CHEST:
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


## Solo capturas: aprende la receta y deja su forma en el suelo, delante del jugador.
func _debug_lay_shape(recipe_id: String) -> void:
	_player.learn(recipe_id)
	# Ejes del mundo más parecidos a "delante" y "derecha" (la cuadrícula invisible va alineada
	# con el mundo), y el origen en el centro de una celda.
	var f := -_player.global_basis.z
	var forward := Vector3(signf(f.x), 0, 0) if absf(f.x) > absf(f.z) else Vector3(0, 0, signf(f.z))
	var right := forward.cross(Vector3.UP)
	var origin := _player.global_position + forward * 1.1 - right * 0.3
	origin = (origin / GroundRecipes.CELL).floor() * GroundRecipes.CELL + Vector3(0.5, 0, 0.5) * GroundRecipes.CELL
	var space := get_world_3d().direct_space_state
	var cells := GroundRecipes.cells_of(recipe_id)
	for c: Vector2i in cells:
		var p := origin + right * (c.x * GroundRecipes.CELL) + forward * (c.y * GroundRecipes.CELL) \
			+ Vector3(randf_range(-0.08, 0.08), 0, randf_range(-0.08, 0.08))  # sueltos, sin anclar
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 4.0))
		if hit.is_empty():
			continue
		var point: Vector3 = hit.position
		var support := Vector3i((point / VOXEL_SIZE - Vector3(0, 0.5, 0)).floor())
		_ground.place(point, cells[c], randf() * TAU, support)


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


## Solo capturas: dos mesas de trabajo delante del jugador, con el pico a medio montar encima.
func _debug_bench() -> void:
	var f := -_player.global_basis.z
	var forward := Vector3i(int(signf(f.x)), 0, 0) if absf(f.x) > absf(f.z) else Vector3i(0, 0, int(signf(f.z)))
	var right := Vector3i(Vector3(forward).cross(Vector3.UP))
	var feet := Vector3i((_player.global_position / VOXEL_SIZE).floor())
	var tool := _terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_TYPE
	var cells := [feet + forward * 3, feet + forward * 3 + right]
	for c: Vector3i in cells:
		tool.set_voxel(c, IslandGenerator.WORKBENCH)
		tool.set_voxel(c + Vector3i.UP, IslandGenerator.AIR)
	_player.learn("stone_pick")
	var top := (Vector3(cells[0]) + Vector3(0.25, 1.0, 0.25)) * VOXEL_SIZE
	var cell := GroundRecipes.CELL
	var a := _ground.place(top, "sticks", 0.3, cells[0])
	_ground.place(top + Vector3(0, 0, cell), "sticks", -0.2, cells[0])
	_ground.place(top + Vector3(cell, 0, 0), "rope", 0.5, cells[0])
	_ground.stack_on(a, "stone", 0.1)


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
	var tool := _terrain.get_voxel_tool()
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
func _sleep(at: Vector3) -> void:
	_player.set_spawn_point(at + Vector3.UP * 0.3)
	var h := _day_night.hour
	if h >= 6.0 and h < 19.0:
		_show_notice("Aún es de día: solo se puede dormir al anochecer. (Este saco será tu sitio para reaparecer.)")
		return
	_player.ui_open = true
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(black)
	var tween := create_tween()
	tween.tween_property(black, "color:a", 1.0, 1.2)
	tween.tween_callback(func() -> void:
		if h >= 19.0:
			_day_night.day += 1
		_day_night.set_hour(6.5)
		_objectives.mark("dormido")
		_save_world())
	tween.tween_interval(0.8)
	tween.tween_property(black, "color:a", 0.0, 1.5)
	tween.tween_callback(func() -> void:
		black.queue_free()
		_player.ui_open = false
		_show_notice("Has dormido hasta el amanecer."))


## Barrita de hambre o sed, abajo a la izquierda (fila 0 o 1).
func _make_need_bar(canvas: CanvasLayer, row: int, text: String, color: Color) -> ProgressBar:
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
	row_box.add_child(bar)
	return bar


## El mismo material de los bloques, pero que brilla un poco (para el mineral verde).
func _glowing(base: StandardMaterial3D) -> StandardMaterial3D:
	var m := base.duplicate() as StandardMaterial3D
	m.emission_enabled = true
	m.emission_texture = base.albedo_texture
	m.emission = Color(0.4, 1.0, 0.55)
	m.emission_energy_multiplier = 0.6
	return m


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


## Mesa de trabajo: el modelo de cubitos del arte conceptual (tools/bake_prefabs.gd), que choca
## como un bloque entero (el martillo y el trapo que sobresalen no estorban).
func _make_bench() -> VoxelBlockyModelMesh:
	var model := PrefabLibrary.make_model(PrefabLibrary.first_id("workbench"))
	model.collision_aabbs = [AABB(Vector3.ZERO, Vector3.ONE)]
	return model
