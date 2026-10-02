extends SceneTree
## Banco de pruebas del generador de la isla: mide cuánto cuesta cada tipo de bloque.
## Uso: godot --headless --path . --script res://tools/bench_generator.gd

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var gen := IslandGenerator.new()
	print("Carga de mapas: %d ms" % (Time.get_ticks_msec() - t0))

	var buffer := VoxelBuffer.new()
	buffer.create(16, 16, 16)
	var cases := {
		"aire (cielo)": Vector3i(0, 240, 0),
		"roca enterrada": Vector3i(0, 0, 0),
		"superficie bosque": _surface_origin(gen, -200, 0),
		"superficie montaña": _surface_origin(gen, 300, -150),
		"superficie pueblo": _surface_origin(gen, -560, 607),
		"mar abierto": Vector3i(-1050, 16, -1050),
	}
	for name in cases:
		var origin: Vector3i = cases[name]
		var runs := 40
		var start := Time.get_ticks_usec()
		for i in runs:
			buffer.fill(0, VoxelBuffer.CHANNEL_TYPE)
			gen.generate_block(buffer, origin + Vector3i(16 * (i % 5), 0, 16 * (i / 5)), 0)
		var per_block := float(Time.get_ticks_usec() - start) / runs / 1000.0
		print("%-20s %.3f ms/bloque  (origen %s)" % [name, per_block, origin])

	# Cuántos bloques hay de cada tipo en toda la isla (con los límites del terreno).
	var counts := {"aire": 0, "roca": 0, "superficie": 0}
	for cx in range(-1100, 1100, 16):
		for cz in range(-1100, 1100, 16):
			var span: Vector2i = gen._chunk_height_range(Vector3i(cx, 0, cz), Vector3i(16, 16, 16))
			for cy in range(-8, 336, 16):
				if cy > span.y + IslandGenerator.MAX_TREE_HEIGHT + 4:
					counts["aire"] += 1
				elif cy + 16 <= span.x - IslandGenerator.DIRT_DEPTH - 2:
					counts["roca"] += 1
				else:
					counts["superficie"] += 1
	print("Bloques en la isla: %s" % counts)
	quit()


func _surface_origin(gen: IslandGenerator, wx: int, wz: int) -> Vector3i:
	var ground := gen.get_ground_height(wx, wz)
	return Vector3i(wx, floori(ground / 16.0) * 16, wz)
