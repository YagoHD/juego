extends SceneTree
## Captura de QA; usa --arena-no-save para aislar la población y no guardar las pruebas.
func _init() -> void:
	Engine.max_fps = 30
	_run.call_deferred()

func _run() -> void:
	var arena: Node3D = load("res://scenes/combat_arena.tscn").instantiate()
	root.add_child(arena)
	for i in 20:
		await process_frame
	var player: Player = arena.player
	player._held.hide()
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(0, 35, 49)
	camera.look_at(Vector3(0, 0, -8))
	camera.make_current()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/combat_arena_overview.png")
	arena._toggle_panel()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/combat_arena_panel.png")
	print("Capturas: .godot/combat_arena_overview.png y combat_arena_panel.png")
	quit()
