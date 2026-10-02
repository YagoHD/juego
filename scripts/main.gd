extends Node3D
## Mundo jugable: la isla de la Beta (generada desde los mapas de assets/island/),
## jugador en primera persona, romper (clic izq.) y colocar (clic der.) bloques.

# Tamaño de cada voxel en metros. 1.0 = estilo Minecraft; 0.5 = cada cubo se parte en 8
# (estilo Cube World, personaje de ~4 cubos de alto). Baja este valor para más detalle.
const VOXEL_SIZE := 0.5

# Punto de aparición (en voxels): la playa del pueblo junto a la bahía.
const SPAWN_VOXEL := Vector2i(-560, 607)

# Región central que debe estar mallada antes de entrar (en voxels, dentro de la distancia de carga).
const LOAD_AREA := AABB(Vector3(-900, -8, -900), Vector3(1800, 260, 1800))
const MAX_LOAD_SECONDS := 180.0  # tope de seguridad: entrar aunque no haya "terminado"

const BLOCK_NAMES := {
	IslandGenerator.GRASS: "Hierba",
	IslandGenerator.DIRT: "Tierra",
	IslandGenerator.STONE: "Piedra",
	IslandGenerator.SAND: "Arena",
	IslandGenerator.SNOW: "Nieve",
	IslandGenerator.WOOD: "Madera",
	IslandGenerator.LEAVES: "Hoja",
	IslandGenerator.WATER: "Agua",
	IslandGenerator.WHEAT: "Trigo",
}

var _player: Player
var _hud: Label
var _terrain: VoxelTerrain
var _generator: IslandGenerator
var _loading := true
var _loading_label: Label
var _loading_overlay: CanvasLayer
var _elapsed := 0.0
var _settled_frames := 0


func _ready() -> void:
	_build_world()
	_build_environment()
	_build_hud()
	_build_loading_overlay()
	print("[main] Generando la isla completa...")


func _build_world() -> void:
	var library := VoxelBlockyLibrary.new()
	library.add_model(VoxelBlockyModelEmpty.new())                 # 0 AIR
	library.add_model(_make_cube(Color(0.37, 0.65, 0.33)))         # 1 GRASS
	library.add_model(_make_cube(Color(0.55, 0.40, 0.26)))         # 2 DIRT
	library.add_model(_make_cube(Color(0.50, 0.50, 0.52)))         # 3 STONE
	library.add_model(_make_cube(Color(0.88, 0.80, 0.56)))         # 4 SAND
	library.add_model(_make_cube(Color(0.95, 0.96, 0.98)))         # 5 SNOW
	library.add_model(_make_cube(Color(0.45, 0.30, 0.17)))         # 6 WOOD
	library.add_model(_make_cube(Color(0.24, 0.52, 0.22)))         # 7 LEAVES
	library.add_model(_make_water())                               # 8 WATER
	library.add_model(_make_cube(Color(0.13, 0.33, 0.20)))         # 9 PINE_LEAVES
	library.add_model(_make_cube(Color(0.30, 0.22, 0.32)))         # 10 CORRUPT_SOIL
	library.add_model(_make_cube(Color(0.22, 0.18, 0.17)))         # 11 DEAD_WOOD
	library.add_model(_make_cube(Color(0.90, 0.76, 0.30)))         # 12 WHEAT
	library.bake()

	var mesher := VoxelMesherBlocky.new()
	mesher.library = library

	_generator = IslandGenerator.new()

	var terrain := VoxelTerrain.new()
	terrain.mesher = mesher
	terrain.generator = _generator
	terrain.generate_collisions = true
	# Solo se generan voxels dentro de la isla y entre el fondo marino y las cimas:
	# sin esto, generaría kilómetros de roca subterránea inútil.
	terrain.bounds = AABB(Vector3(-1100, -8, -1100), Vector3(2200, 344, 2200))
	terrain.max_view_distance = 1400  # tope del terreno (en voxels); sin esto solo carga un recuadro
	terrain.scale = Vector3.ONE * VOXEL_SIZE  # voxels más pequeños (estilo Cube World)
	terrain.add_to_group("voxel_terrain")
	add_child(terrain)
	_terrain = terrain

	# Observador FIJO en el centro de la isla: fuerza a generar/cargar TODO el mapa a la vez
	# y lo mantiene cargado aunque el jugador se aleje.
	var loader := VoxelViewer.new()
	loader.view_distance = 1300  # en voxels; cubre toda la isla
	loader.position = Vector3(0, 40, 0)
	add_child(loader)

	_build_sea()


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
	material.albedo_color = Color(0.25, 0.62, 0.80, 0.62)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.08
	cube.set_material_override(0, material)
	cube.transparency_index = 1
	cube.set_mesh_collision_enabled(0, false)
	return cube


func _build_player() -> void:
	var ground := _generator.get_ground_height(SPAWN_VOXEL.x, SPAWN_VOXEL.y)
	_player = Player.new()
	_player.position = Vector3(SPAWN_VOXEL.x, ground + 4, SPAWN_VOXEL.y) * VOXEL_SIZE
	add_child(_player)


func _build_loading_overlay() -> void:
	_loading_overlay = CanvasLayer.new()
	_loading_overlay.layer = 100  # por encima de todo
	add_child(_loading_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(bg)

	_loading_label = Label.new()
	_loading_label.text = "Generando la isla..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_label.add_theme_font_size_override("font_size", 28)
	_loading_overlay.add_child(_loading_label)


func _update_loading() -> void:
	_elapsed += get_process_delta_time()

	var remaining := -1
	var stats: Dictionary = _terrain.get_statistics()
	if stats.has("remaining_main_thread_blocks"):
		remaining = int(stats["remaining_main_thread_blocks"])

	# Consideramos "asentado" cuando no quedan bloques pendientes varios frames seguidos.
	if remaining == 0:
		_settled_frames += 1
	else:
		_settled_frames = 0

	var meshed := false
	if _terrain.has_method("is_area_meshed"):
		meshed = _terrain.is_area_meshed(LOAD_AREA)

	_loading_label.text = "Generando la isla...\n%.1f s\nBloques pendientes: %s" % [_elapsed, remaining]

	# Listo cuando lleva un rato sin trabajo pendiente (o la zona central está mallada),
	# con un tope de seguridad para no quedarse colgado.
	var ready_by_settle := _settled_frames > 60 and _elapsed > 2.0
	var ready_by_mesh := meshed and _settled_frames > 10 and _elapsed > 2.0
	var ready_by_timeout := _elapsed > MAX_LOAD_SECONDS
	if ready_by_settle or ready_by_mesh or ready_by_timeout:
		_finish_loading()


func _finish_loading() -> void:
	_loading = false
	if _loading_overlay != null:
		_loading_overlay.queue_free()
		_loading_overlay = null
	_build_player()
	print("[main] Isla cargada en %.1f s. ¡A jugar!" % _elapsed)


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
	# Bruma suave para dar profundidad al horizonte (perspectiva aérea).
	env.fog_enabled = true
	env.fog_light_color = Color(0.70, 0.82, 0.95)
	env.fog_density = 0.0012
	env.fog_aerial_perspective = 0.6
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

	# Punto de mira en el centro.
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE  # no robar clics del juego
	crosshair.add_theme_color_override("font_color", Color.WHITE)
	crosshair.add_theme_color_override("font_outline_color", Color.BLACK)
	crosshair.add_theme_constant_override("outline_size", 3)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	canvas.add_child(crosshair)


func _process(_delta: float) -> void:
	if _loading:
		_update_loading()
		return
	if _hud == null or _player == null:
		return
	var block_name: String = BLOCK_NAMES.get(_player.get_current_block(), "?")
	_hud.text = "FPS: %d\nBloque: %s  (1 hierba · 2 tierra · 3 piedra · 4 arena · 5 nieve · 6 madera · 7 hoja · 8 agua · 9 trigo)\nClic izq. romper · Clic der. colocar · WASD mover · Espacio saltar · F volar · Esc ratón" \
		% [Engine.get_frames_per_second(), block_name]
