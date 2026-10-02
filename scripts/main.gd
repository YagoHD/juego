extends Node3D
## Fase 2 — Mundo de cubos jugable: terreno blocky, jugador en primera persona,
## romper (clic izq.) y colocar (clic der.) bloques. Teclas 1/2/3 eligen bloque.

# Tamaño de cada voxel en metros. 1.0 = estilo Minecraft; 0.5 = cada cubo se parte en 8
# (estilo Cube World, personaje de ~4 cubos de alto). Baja este valor para más detalle.
const VOXEL_SIZE := 0.5

var _player: Player
var _hud: Label

const BLOCK_NAMES := {
	IslandGenerator.GRASS: "Hierba",
	IslandGenerator.DIRT: "Tierra",
	IslandGenerator.STONE: "Piedra",
	IslandGenerator.SAND: "Arena",
	IslandGenerator.SNOW: "Nieve",
	IslandGenerator.WOOD: "Madera",
	IslandGenerator.LEAVES: "Hoja",
}


func _ready() -> void:
	_build_world()
	_build_player()
	_build_environment()
	_build_hud()
	print("[main] Mundo de cubos listo.")


func _build_world() -> void:
	var library := VoxelBlockyLibrary.new()
	library.add_model(VoxelBlockyModelEmpty.new())                 # 0 AIR
	library.add_model(_make_cube(Color(0.37, 0.65, 0.33)))         # 1 GRASS
	library.add_model(_make_cube(Color(0.55, 0.40, 0.26)))         # 2 DIRT
	library.add_model(_make_cube(Color(0.50, 0.50, 0.52)))         # 3 STONE
	library.add_model(_make_cube(Color(0.85, 0.78, 0.55)))         # 4 SAND
	library.add_model(_make_cube(Color(0.95, 0.96, 0.98)))         # 5 SNOW
	library.add_model(_make_cube(Color(0.45, 0.30, 0.17)))         # 6 WOOD
	library.add_model(_make_cube(Color(0.20, 0.47, 0.22)))         # 7 LEAVES
	library.bake()

	var mesher := VoxelMesherBlocky.new()
	mesher.library = library

	var terrain := VoxelTerrain.new()
	terrain.mesher = mesher
	terrain.generator = IslandGenerator.new()
	terrain.generate_collisions = true
	terrain.scale = Vector3.ONE * VOXEL_SIZE  # voxels más pequeños (estilo Cube World)
	terrain.add_to_group("voxel_terrain")
	add_child(terrain)

	_build_sea()


func _build_sea() -> void:
	# Plano de agua translúcido al nivel del mar (mundo = SEA_LEVEL * VOXEL_SIZE).
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	water.mesh = plane
	# Un pelín por debajo del tope del bloque de arena para evitar z-fighting con el terreno.
	water.position = Vector3(0, IslandGenerator.SEA_LEVEL * VOXEL_SIZE - 0.08, 0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.40, 0.62, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.2
	mat.roughness = 0.1
	water.material_override = mat
	add_child(water)


func _make_cube(color: Color) -> VoxelBlockyModelCube:
	var cube := VoxelBlockyModelCube.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	cube.set_material_override(0, material)
	return cube


func _build_player() -> void:
	_player = Player.new()
	_player.position = Vector3(0, 60, 0)
	add_child(_player)


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
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
	if _hud == null or _player == null:
		return
	var block_name: String = BLOCK_NAMES.get(_player.get_current_block(), "?")
	_hud.text = "FPS: %d\nBloque: %s  (teclas 1 hierba · 2 tierra · 3 piedra)\nClic izq. romper · Clic der. colocar · WASD mover · Espacio saltar · Esc ratón" \
		% [Engine.get_frames_per_second(), block_name]
