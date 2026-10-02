extends SceneTree
## Comprueba que todos los sonidos se generan, cuánto duran y su volumen máximo (sin saturar).
## Uso: godot --headless --path . --script res://tools/test_sounds.gd

const SOUNDS := ["paso_hierba", "paso_arena", "paso_piedra", "paso_madera", "paso_tela", "paso_agua",
	"romper_hierba", "romper_arena", "romper_piedra", "romper_madera", "romper_tela", "romper_agua",
	"colocar", "golpe", "recoger", "tirar", "fabricado", "aprender", "pagina", "cofre", "clic",
	"pajaro", "grillos", "olas"]


func _init() -> void:
	var fails := 0
	var t0 := Time.get_ticks_msec()
	for s in SOUNDS:
		var data := Sfx._limit(Sfx._synth(s))
		var peak := 0.0
		var rms := 0.0
		for v in data:
			peak = maxf(peak, absf(v))
			rms += v * v
		rms = sqrt(rms / maxf(data.size(), 1))
		var ok := data.size() > 100 and peak > 0.03 and peak <= 1.0
		if not ok:
			fails += 1
		print("%-14s %.2f s  pico %.2f  rms %.3f  %s" % [s, data.size() / float(Sfx.RATE), peak, rms, "OK" if ok else "FALLO"])
	print("Generados en %d ms" % (Time.get_ticks_msec() - t0))
	print("RESULTADO: ", "TODO OK" if fails == 0 else "%d FALLOS" % fails)
	quit()
