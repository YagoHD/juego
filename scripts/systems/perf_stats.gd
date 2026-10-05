class_name PerfStats
## Medidas de rendimiento para el texto del F3: cuánto tarda la tarjeta gráfica en dibujar cada
## imagen, cuánto el procesador (el código del juego y la física), y cuánto hay que dibujar
## (triángulos, llamadas de dibujo, objetos). Sirve para saber qué frena los FPS.


## Activa (o no) la medida de tiempos de dibujo de la ventana.
static func enable(viewport: Viewport, on: bool) -> void:
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), on)


static func text(viewport: Viewport) -> String:
	var rid := viewport.get_viewport_rid()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var render_cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var process := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var tris := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	return "%d FPS\nGráfica %.1f ms · Procesador: juego %.1f ms, física %.1f ms, preparar dibujo %.1f ms\nTriángulos %d mil · Llamadas de dibujo %d · Objetos %d" % [
		Engine.get_frames_per_second(), gpu, process, physics, render_cpu, int(tris / 1000.0), int(calls), int(objects)]
