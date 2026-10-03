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
var _session: CraftSession     # inventario de rodillas y vista de fabricar
var _crosshair: Label
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
	var water := BlockTextures.make_material(true)
	for id in range(1, Blocks.LAST_ID + 1):
		if id == IslandGenerator.WATER:
			library.add_model(_make_water(water))
		elif id == IslandGenerator.CLOTH:
			library.add_model(_make_carpet(id, solid))
		elif Blocks.is_decor(id):
			library.add_model(DecorModels.make_model(id))  # hierba, flores, piedrecitas...
		else:
			library.add_model(_make_cube(id, solid))
	library.bake()

	var mesher := VoxelMesherBlocky.new()
	mesher.library = library

	_generator = IslandGenerator.new()

	var terrain := VoxelTerrain.new()
	terrain.mesher = mesher
	terrain.generator = _generator
	terrain.stream = _make_world_stream()
	terrain.generate_collisions = true
	# Solo existen voxels dentro de la isla y entre el fondo marino y las cimas.
	terrain.bounds = AABB(Vector3(-1024, 0, -1024), Vector3(2048, 256, 2048))
	# Mallas de 32³ voxels: 8 veces menos objetos de malla y colisión que con 16³.
	terrain.mesh_block_size = 32
	terrain.max_view_distance = NEAR_VIEW_VOXELS + 64
	terrain.scale = Vector3.ONE * VOXEL_SIZE  # voxels más pequeños (estilo Cube World)
	terrain.add_to_group("voxel_terrain")
	add_child(terrain)
	_terrain = terrain

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
	_load_player()
	_chests.load_from(_chests_save_path())
	_ground = GroundCrafting.new()
	add_child(_ground)
	_ground.player = _player
	_ground.crafted.connect(func(recipe_id: String) -> void: _objectives.mark("hecho_" + recipe_id))
	_objectives.player = _player
	_session = CraftSession.new()
	add_child(_session)
	_session.player = _player
	_session.ground = _ground
	_session.screen = _inventory_screen
	_session.ended.connect(func() -> void:
		_player.ui_open = false
		_player._set_captured(true))
	_player.ground = _ground
	_ground.load_from(_ground_save_path())
	_player.notice.connect(_show_notice)
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
	return AABB(Vector3(Structures.spawn_voxel().x - r, 0, Structures.spawn_voxel().y - r), Vector3(2 * r, 256, 2 * r))


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
	var help_style := PauseMenu.panel_style()
	help_style.bg_color.a = 0.82
	help_style.set_content_margin_all(14)
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
		if OS.get_cmdline_user_args().has("--torches"):  # dos antorchas clavadas delante
			var fwd := -_player.global_basis.z
			for k in [-1.2, 1.2]:
				var p: Vector3 = _player.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * 3.0 + _player.global_basis.x * float(k)
				var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 6.0))
				if not hit.is_empty():
					var pt: Vector3 = hit.position
					_ground.place(pt, "torch", 0.0, Vector3i((pt / VOXEL_SIZE - Vector3(0, 0.5, 0)).floor()))
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
