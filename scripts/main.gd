extends Node3D
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
const FOG_BEGIN := 450.0
const FOG_END := 1600.0
const FOG_MAX := 0.75  # opacidad máxima de la niebla (1 = tapa del todo)

# Punto de aparición (en voxels): la playa del pueblo junto a la bahía.
const SPAWN_VOXEL := Vector2i(-560, 607)
const MAX_LOAD_SECONDS := 60.0  # tope de seguridad: entrar aunque no haya "terminado"

const WORLD_DIR := "user://world"
const AUTOSAVE_SECONDS := 60.0

var _player: Player
var _hud: Label
var _hotbar: Hotbar
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


# ------------------------------------------------------------------ mundo

func _build_world() -> void:
	var library := VoxelBlockyLibrary.new()
	library.add_model(VoxelBlockyModelEmpty.new())  # 0 AIR
	for id in range(1, Blocks.LAST_ID + 1):
		if id == IslandGenerator.WATER:
			library.add_model(_make_water())
		else:
			library.add_model(_make_cube(Blocks.color_of(id)))
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
	far.build(_generator, Blocks.COLORS, VOXEL_SIZE, FAR_HIDE_RADIUS)
	add_child(far)


func _make_world_stream() -> VoxelStreamSQLite:
	# El mundo se guarda en un archivo: lo ya visitado se lee de ahí (rápido) y conserva lo
	# que el jugador construya. El nombre lleva una "huella" de los mapas y del generador:
	# si cambian, se crea un mundo nuevo.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLD_DIR))
	var file_name := "isla_%s.sqlite" % _world_fingerprint()
	var path := WORLD_DIR.path_join(file_name)
	_world_is_new = not FileAccess.file_exists(path)
	if _world_is_new:
		_delete_old_worlds(file_name)
	var stream := VoxelStreamSQLite.new()
	stream.database_path = ProjectSettings.globalize_path(path)
	stream.save_generator_output = true
	return stream


func _world_fingerprint() -> String:
	var text := ""
	for file in ["height.png", "water.png", "surface.png"]:
		text += FileAccess.get_md5(IslandGenerator.MAP_DIR + file)
	text += FileAccess.get_md5("res://scripts/world/island_generator.gd")
	return text.md5_text().substr(0, 12)


func _delete_old_worlds(keep: String) -> void:
	var dir := DirAccess.open(WORLD_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if file.begins_with("isla_") and file != keep:
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


func _make_cube(color: Color) -> VoxelBlockyModelCube:
	var cube := VoxelBlockyModelCube.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	cube.set_material_override(0, material)
	return cube


func _make_water() -> VoxelBlockyModelCube:
	# Agua de ríos y lagos: translúcida, sin caras internas y atravesable.
	var cube := VoxelBlockyModelCube.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Blocks.color_of(IslandGenerator.WATER)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.08
	cube.set_material_override(0, material)
	cube.transparency_index = 1
	cube.set_mesh_collision_enabled(0, false)
	return cube


func _build_player() -> void:
	# El jugador existe desde el principio (sus observadores cargan el terreno a su alrededor),
	# pero flota quieto hasta que hay suelo con colisión debajo.
	var ground := _generator.get_ground_height(SPAWN_VOXEL.x, SPAWN_VOXEL.y)
	_player = Player.new()
	_player.near_view_voxels = NEAR_VIEW_VOXELS
	_player.position = Vector3(SPAWN_VOXEL.x, ground + 4, SPAWN_VOXEL.y) * VOXEL_SIZE
	add_child(_player)


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
	return AABB(Vector3(SPAWN_VOXEL.x - r, 0, SPAWN_VOXEL.y - r), Vector3(2 * r, 256, 2 * r))


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
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.48, 0.88)
	sky_mat.sky_horizon_color = Color(0.68, 0.82, 0.95)
	sky_mat.ground_horizon_color = Color(0.68, 0.82, 0.95)
	sky_mat.ground_bottom_color = Color(0.20, 0.35, 0.55)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Niebla por distancia: nada hasta FOG_BEGIN y luego una bruma suave del color del horizonte.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = FOG_BEGIN
	env.fog_depth_end = FOG_END
	env.fog_depth_curve = 1.6
	env.fog_density = FOG_MAX
	env.fog_light_color = Color(0.70, 0.82, 0.95)
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.5
	world_env.environment = env
	add_child(world_env)


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


func _process(_delta: float) -> void:
	if _loading:
		_update_loading()
		return
	if _hud == null or _player == null:
		return
	_hotbar.select(_player.get_hotbar_index())
	_hud.text = "FPS: %d\nClic izq. romper · Clic der. colocar · 1-9 / rueda: bloque\nWASD mover · Espacio saltar · F volar · V cámara · Esc ratón" \
		% Engine.get_frames_per_second()
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
			float(_arg("--yaw=", "0")), float(_arg("--up=", "0")) + (0.01 if at != "" else 0.0))
		_capture_frames = int(_arg("--wait=", "90"))
		return
	_capture_frames -= 1
	if _capture_frames == 0:
		get_viewport().get_texture().get_image().save_png(path)
		print("[captura] guardada en ", path)
		get_tree().quit()


func _arg(prefix: String, default := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default
