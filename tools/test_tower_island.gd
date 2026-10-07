extends SceneTree
var failures := 0
func _init() -> void:
	Engine.max_fps = 120
	Main.test_mode = true
	Main.test_tower_mode = true
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	print(("OK: " if ok else "FALLO: ") + message)
	if not ok:
		failures += 1
func _run() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 9000:
		await process_frame
		if not main._loading:
			break
	if main._loading or main._tower == null:
		check(false, "isla carga director de torre")
		quit(1)
		return
	check(main._tower.phase == 1, "isla real integra fase inicial")
	main._day_night.advance(48.0)
	for i in 30:
		await physics_frame
	check(main._tower.phase == 3 and main._tower._records.size() == 18, "reloj de la isla activa tercera fase")
	main._tower._records["1_0"]["dead"] = true
	main._save_player()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main._player_save_path()))
	check(data["tower"]["phase"] == 3 and data["tower"]["records"]["1_0"]["dead"], "guardado real del jugador incluye progreso y bajas de torre")
	main._day_night.advance(24.0)
	for i in 30:
		await physics_frame
	check(main._tower.phase == 4 and main._tower._records.size() == 34, "cuarto día de isla añade jefe y mega campamento")
	main._save_player()
	print("TOTAL: %d fallos" % failures)
	quit(1 if failures else 0)
