class_name Settings
## Ajustes del jugador (menú de pausa > Opciones), guardados en user://ajustes.cfg.
## Se leen desde cualquier sitio: Settings.sensitivity, Settings.fov...

const PATH := "user://ajustes.cfg"
const DEFAULT_SENSITIVITY := 0.0025

static var sensitivity := DEFAULT_SENSITIVITY  # radianes por píxel de ratón
static var fov := 75.0                          # grados
static var volume := 0.8                        # 0..1, volumen general
static var music := 0.5                         # 0..1, volumen de la música
static var texture_pack := ""                    # "" = las de siempre; "16x16" = paquete CC0
static var show_fps := false
static var invert_y := false
# Gráficos (Opciones > Gráficos). La distancia de detalle se aplica al entrar en la partida; lo
# demás, al momento (los nodos del grupo "graphics" reciben apply_graphics()).
const VIEW_DISTANCES := [96.0, 128.0, 160.0]   # metros de terreno con todo el detalle
const SHADOW_NAMES := ["Sin sombras", "Bajas", "Medias", "Altas"]
const AA_NAMES := ["Sin suavizado", "FXAA (ligero)", "MSAA x2"]
static var view_distance := 128.0
static var shadows := 2                          # índice de SHADOW_NAMES
static var antialias := 1                        # índice de AA_NAMES
static var relief := true                        # relieve de las texturas de cerca
static var far_trees := true                     # árboles sencillos a lo lejos
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	sensitivity = float(cfg.get_value("control", "sensibilidad", sensitivity))
	invert_y = bool(cfg.get_value("control", "invertir_y", invert_y))
	fov = float(cfg.get_value("video", "campo_de_vision", fov))
	show_fps = bool(cfg.get_value("video", "mostrar_fps", show_fps))
	volume = float(cfg.get_value("sonido", "volumen", volume))
	music = float(cfg.get_value("sonido", "musica", music))
	texture_pack = str(cfg.get_value("video", "texturas", texture_pack))
	view_distance = float(cfg.get_value("graficos", "distancia", view_distance))
	shadows = int(cfg.get_value("graficos", "sombras", shadows))
	antialias = int(cfg.get_value("graficos", "suavizado", antialias))
	relief = bool(cfg.get_value("graficos", "relieve", relief))
	far_trees = bool(cfg.get_value("graficos", "arboles_lejanos", far_trees))
	apply_volume()


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("control", "sensibilidad", sensitivity)
	cfg.set_value("control", "invertir_y", invert_y)
	cfg.set_value("video", "campo_de_vision", fov)
	cfg.set_value("video", "mostrar_fps", show_fps)
	cfg.set_value("sonido", "volumen", volume)
	cfg.set_value("sonido", "musica", music)
	cfg.set_value("video", "texturas", texture_pack)
	cfg.set_value("graficos", "distancia", view_distance)
	cfg.set_value("graficos", "sombras", shadows)
	cfg.set_value("graficos", "suavizado", antialias)
	cfg.set_value("graficos", "relieve", relief)
	cfg.set_value("graficos", "arboles_lejanos", far_trees)
	cfg.save(PATH)
	apply_volume()


static func apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.001)


## Aplica los gráficos al momento: suavizado aquí; sombras, relieve y árboles lejanos, los nodos
## del grupo "graphics" (el día y la noche, el terreno...).
static func apply_graphics(tree: SceneTree) -> void:
	var viewport := tree.root
	viewport.msaa_3d = Viewport.MSAA_2X if antialias == 2 else Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if antialias == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	BlockTextures.set_relief(relief)
	tree.call_group("graphics", "apply_graphics")
