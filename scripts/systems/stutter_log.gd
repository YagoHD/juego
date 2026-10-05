extends Node
class_name StutterLog
## Registro de tirones: cada fotograma que tarda más de LIMIT_MS se apunta (en user://tirones.txt
## y en memoria) con lo que estaba pasando: cuánto tardó el código del juego, la física, la
## gráfica, lo que los terrenos estaban cargando o subiendo y los avisos de este fotograma
## (guardado automático, talar un árbol...). Sirve para saber qué provoca cada tirón.

const LIMIT_MS := 25.0
const PATH := "user://tirones.txt"

static var _instance: StutterLog
var count := 0
var worst_ms := 0.0
var _marks: Array[String] = []
var _file: FileAccess
var _skip := 3   # los primeros fotogramas tras cargar no cuentan


func _ready() -> void:
	_instance = self
	process_priority = 1000  # al final del fotograma: ya se sabe todo lo que ha pasado
	_file = FileAccess.open(PATH, FileAccess.WRITE)
	if _file != null:
		_file.store_line("Tirones (fotogramas de más de %d ms) — %s" % [LIMIT_MS, Time.get_datetime_string_from_system()])


## Avisa de algo que acaba de pasar (aparecerá junto al tirón si lo hay en este fotograma).
static func mark(what: String) -> void:
	if _instance != null:
		_instance._marks.append(what)


func _process(delta: float) -> void:
	var ms := delta * 1000.0
	if _skip > 0:
		_skip -= 1
		_marks.clear()
		return
	if ms > LIMIT_MS:
		count += 1
		worst_ms = maxf(worst_ms, ms)
		var line := "%.1f s  %.0f ms  juego %.1f  física %.1f  gráfica %.1f%s%s" % [
			Time.get_ticks_msec() / 1000.0, ms,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),
			_terrain_text(), ("  [" + ", ".join(_marks) + "]") if not _marks.is_empty() else ""]
		if _file != null:
			_file.store_line(line)
			_file.flush()
	_marks.clear()


## Lo que tienen pendiente los terrenos (cargar, mallar, subir): si un tirón coincide con mucho de
## esto, es la carga del mundo.
func _terrain_text() -> String:
	var out := ""
	var w := WorldVoxels.tool()
	if w == null:
		return out
	for pair in [["suelo", w.ground], ["árboles", w.trees]]:
		var t := pair[1] as VoxelTerrain
		if t == null:
			continue
		var s := t.get_statistics()
		out += "  %s: %s" % [pair[0], ", ".join(s.keys().filter(func(k: String) -> bool: return s[k] is int and int(s[k]) > 0).map(func(k: String) -> String: return "%s=%d" % [k, s[k]]))]
	return out


## Resumen (para el F3 y las pruebas).
static func summary() -> String:
	if _instance == null:
		return ""
	return "Tirones: %d (peor %.0f ms)" % [_instance.count, _instance.worst_ms]
