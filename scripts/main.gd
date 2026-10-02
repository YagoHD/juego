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
var _hotbar: Hotbar
var _underwater: ColorRect
var _day_night: DayNight
var _inventory_screen: InventoryScreen
var _chests := ChestStorage.new()
var _world_id := ""  # huella del mundo (nombre de sus archivos de guardado)
var _terrain: VoxelTerrain
var _generator: IslandGenerator
var _loading := true
var _loading_label: Label
var _loading_overlay: CanvasLayer
var _elapsed := 0.0
var _world_is_new := false


func _ready() -> void:
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
	if _world_is_new:
		_delete_old_worlds(file_name)
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


func _delete_old_worlds(keep: String) -> void:
	var dir := DirAccess.open(_world_dir())
	if dir == null:
		return
	for file in dir.get_files():
		if (file.begins_with("isla_") or file.begins_with("jugador_")) and not file.contains(keep.get_basename().trim_prefix("isla_")):
			dir.remove(file)


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
	cube.set_tile(VoxelBlockyModel.SIDE_POSITIVE_Y, BlockTextures.tile_of(id, 0))
	cube.set_tile(VoxelBlockyModel.SIDE_NEGATIVE_Y, BlockTextures.tile_of(id, 2))
	for side in [VoxelBlockyModel.SIDE_POSITIVE_X, VoxelBlockyModel.SIDE_NEGATIVE_X,
			VoxelBlockyModel.SIDE_POSITIVE_Z, VoxelBlockyModel.SIDE_NEGATIVE_Z]:
		cube.set_tile(side, BlockTextures.tile_of(id, 1))
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
	_player.block_used.connect(_on_block_used)
	_player.block_broken.connect(_on_block_broken)
	_hotbar.bind(_player.active_inventory(), _player.creative)
	_player.creative_changed.connect(func(on: bool) -> void: _hotbar.bind(_player.active_inventory(), on))


# ------------------------------------------------------------------ pantalla de carga

func _loading_title() -> String:
	if _world_is_new:
		return "Preparando la isla por primera vez..."
	return "Cargando la isla..."


func _build_loading_overlay() -> void:
	_loading_overlay = CanvasLayer.new()
	_loading_overlay.layer = 100  # por encima de todo
	add_child(_loading_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(bg)

	_loading_label = Label.new()
	_loading_label.text = _loading_title()
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_label.add_theme_font_size_override("font_size", 28)
	_loading_overlay.add_child(_loading_label)


func _update_loading() -> void:
	_elapsed += get_process_delta_time()
	_loading_label.text = "%s\n\n%.0f s" % [_loading_title(), _elapsed]

	# Listo cuando la zona detallada alrededor del punto de aparición ya está dibujada.
	var near_ready := _terrain.is_area_meshed(_near_spawn_area())
	if (near_ready and _elapsed > 0.5) or _elapsed > MAX_LOAD_SECONDS:
		_finish_loading()


func _near_spawn_area() -> AABB:
	var r := NEAR_VIEW_VOXELS * 0.8
	return AABB(Vector3(Structures.spawn_voxel().x - r, 0, Structures.spawn_voxel().y - r), Vector3(2 * r, 256, 2 * r))


func _finish_loading() -> void:
	_loading = false
	if _loading_overlay != null:
		_loading_overlay.queue_free()
		_loading_overlay = null
	print("[main] Isla cargada en %.1f s. ¡A jugar!" % _elapsed)
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

	# Pantalla de inventario (y de cofres), por encima del HUD.
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_inventory_screen = InventoryScreen.new()
	ui_layer.add_child(_inventory_screen)
	_inventory_screen.closed.connect(_on_screen_closed)

	# Tinte azul cuando la cabeza está bajo el agua.
	_underwater = ColorRect.new()
	_underwater.color = Color(0.06, 0.30, 0.50, 0.42)
	_underwater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_underwater.set_anchors_preset(Control.PRESET_FULL_RECT)
	_underwater.visible = false
	canvas.add_child(_underwater)
	canvas.move_child(_underwater, 0)  # por debajo del HUD y la barra


func _process(_delta: float) -> void:
	if _loading:
		_update_loading()
		return
	if _hud == null or _player == null:
		return
	_hotbar.select(_player.get_hotbar_index())
	_underwater.visible = _player.is_head_underwater()
	_hud.text = "%s · FPS: %d\nClic izq. romper · Clic der. colocar · 1-9 / rueda: bloque\nWASD mover (W+W correr) · Espacio saltar · F volar · V cámara (mantener V + ratón: distancia) · Alt girar cámara · T (mantener) acelerar el tiempo · Esc ratón" \
		% [_day_night.get_clock_text(), Engine.get_frames_per_second()]
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
		var give := _arg("--give=")  # objetos para la foto: "stone:12,dirt:30"
		if give != "":
			_player.inventory.clear()
			for entry in give.split(","):
				var pair := entry.split(":")
				_player.inventory.add(pair[0], int(pair[1]))
		if _arg("--drop=") != "":  # soltar un objeto delante del jugador para verlo en el suelo
			var forward := -_player.global_basis.z
			ItemDrop.spawn(self, _player.global_position + forward * 1.6 + Vector3.UP, _arg("--drop="), 1)
		if OS.get_cmdline_user_args().has("--inventory"):
			open_inventory()
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
	if _inventory_screen.visible and (key.keycode == KEY_ESCAPE or key.keycode == KEY_E):
		_inventory_screen.close()
		get_viewport().set_input_as_handled()
	elif not _inventory_screen.visible and key.keycode == KEY_E:
		open_inventory()
		get_viewport().set_input_as_handled()


func open_inventory() -> void:
	var inv := _player.active_inventory()
	var title := "Inventario (creativo: bloques infinitos)" if _player.creative else "Inventario"
	var sections: Array[Dictionary] = [
		{"title": title, "inventory": inv, "slots": range(9, inv.size()), "columns": 9},
		{"title": "Barra", "inventory": inv, "slots": range(0, 9), "columns": 9},
	]
	_show_screen(sections)


func _show_screen(sections: Array[Dictionary]) -> void:
	_player.ui_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_inventory_screen.open(sections)


func _on_screen_closed() -> void:
	_player.ui_open = false
	_player._set_captured(true)


# ------------------------------------------------------------------ cofres

func _chests_save_path() -> String:
	return _world_dir().path_join("jugador_%s_cofres.json" % _world_id)


func _on_block_used(cell: Vector3i, block_id: int) -> void:
	if block_id != IslandGenerator.CHEST:
		return
	var chest := _chests.get_or_create(cell)
	var inv := _player.active_inventory()
	var sections: Array[Dictionary] = [
		{"title": "Cofre", "inventory": chest, "slots": range(0, chest.size()), "columns": 9},
		{"title": "Inventario", "inventory": inv, "slots": range(9, inv.size()), "columns": 9},
		{"title": "Barra", "inventory": inv, "slots": range(0, 9), "columns": 9},
	]
	_show_screen(sections)


func _on_block_broken(cell: Vector3i, block_id: int) -> void:
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
