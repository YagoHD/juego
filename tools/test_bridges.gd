extends SceneTree
## Prueba de los puentes (sin ventana): en cada puente del mapa (assets/island/lugares.json) se
## genera el terreno de alrededor y se camina por el centro del tablero de una orilla a la otra:
## cada paso tiene suelo firme, dos bloques libres encima y no sube ni baja más de un bloque, y
## por debajo del tablero, en medio, corre el agua del río.
## Uso: godot --headless --path . --script res://tools/test_bridges.gd

var _fails := 0


func _init() -> void:
	var gen := IslandGenerator.new()
	gen.skip_trees = true  # en el juego los árboles van en otro terreno (WorldVoxels)
	var bridges: Array = Structures.places().get("bridges", [])
	_check("Hay puentes en el mapa (%d)" % bridges.size(), bridges.size() >= 5)
	for bridge: Dictionary in bridges:
		var center := Vector2(float(bridge["x"]), float(bridge["z"])) * 2.0
		var river := Vector2(float(bridge["river"][0]), float(bridge["river"][1])).normalized()
		var across := river.orthogonal()
		var half := float(bridge["half_width"]) * 2.0 + 6.0
		# El generador estampa las estructuras por bloques de 16 alineados: se genera así.
		var base_y := gen.get_ground_height(int(center.x), int(center.y)) - 24
		var origin := Vector3i(floori(center.x / 16.0) * 16 - 32, floori(base_y / 16.0) * 16, floori(center.y / 16.0) * 16 - 32)
		var blocks := {}
		for bx in 5:
			for by in 4:
				for bz in 5:
					var o := origin + Vector3i(bx, by, bz) * 16
					var b := VoxelBuffer.new()
					b.create(16, 16, 16)
					gen.generate_block(b, o, 0)
					blocks[o] = b
		var get := func(x: int, y: int, z: int) -> int:
			var o := Vector3i(floori(x / 16.0) * 16, floori(y / 16.0) * 16, floori(z / 16.0) * 16)
			if not blocks.has(o):
				return IslandGenerator.AIR
			return (blocks[o] as VoxelBuffer).get_voxel(x - o.x, y - o.y, z - o.z, VoxelBuffer.CHANNEL_TYPE)
		var solid := func(id: int) -> bool:
			return id != IslandGenerator.AIR and id != IslandGenerator.WATER and id != IslandGenerator.WATER_FALL
		# Caminar por el centro, desde fuera del puente por un lado hasta fuera por el otro.
		var last := -1000
		var ok := true
		var crossed_water := false
		var why := ""
		var steps := int(half) + 1  # el tablero y su entrada (las cuestas del valle son del terreno)
		for k in range(-steps, steps + 1):
			var p := center + across * float(k)
			var x := floori(p.x)
			var z := floori(p.y)
			var top := -1000
			for y in range(origin.y + 62, origin.y, -1):  # de arriba abajo, el primer bloque firme
				if solid.call(get.call(x, y, z)):
					top = y
					break
			if top == -1000:
				ok = false
				why = "sin suelo en %d" % k
				break
			if OS.get_cmdline_user_args().has("--perfil"):
				printraw("%d:%d(%d) " % [k, top, get.call(x, top, z)])
			if last != -1000 and absi(top - last) > 1:
				ok = false
				why = "escalón de %d en %d" % [top - last, k]
				break
			last = top
			for y in range(top - 1, top - 10, -1):
				if get.call(x, y, z) == IslandGenerator.WATER:
					crossed_water = true
		_check("Puente en (%.0f, %.0f): se cruza andando%s" % [bridge["x"], bridge["z"], "" if ok else " (" + why + ")"], ok)
		_check("  ... y por debajo pasa el río", crossed_water)
	print("RESULTADO: ", "TODO OK" if _fails == 0 else "%d FALLOS" % _fails)
	quit()


func _check(what: String, ok: bool) -> void:
	print(what, " -> ", "OK" if ok else "FALLO")
	if not ok:
		_fails += 1
