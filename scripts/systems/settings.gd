class_name Settings
## Ajustes del jugador (menú de pausa > Opciones), guardados en user://ajustes.cfg.
## Se leen desde cualquier sitio: Settings.sensitivity, Settings.fov...

const PATH := "user://ajustes.cfg"
const DEFAULT_SENSITIVITY := 0.0025

static var sensitivity := DEFAULT_SENSITIVITY  # radianes por píxel de ratón
static var fov := 75.0                          # grados
static var volume := 0.8                        # 0..1, volumen general
static var show_fps := false
static var invert_y := false
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
	apply_volume()


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("control", "sensibilidad", sensitivity)
	cfg.set_value("control", "invertir_y", invert_y)
	cfg.set_value("video", "campo_de_vision", fov)
	cfg.set_value("video", "mostrar_fps", show_fps)
	cfg.set_value("sonido", "volumen", volume)
	cfg.save(PATH)
	apply_volume()


static func apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.001)
