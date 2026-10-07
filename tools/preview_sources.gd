extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/grip_previews"))
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.24, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	environment.environment = env
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 1.3)
	camera.current = true
	scene.add_child(camera)
	var item := MeshInstance3D.new()
	scene.add_child(item)
	for id in ["stone_knife", "torch", "hammer", "battle_axe", "bow", "arrow", "rock", "flint"]:
		item.mesh = load(ItemMesh.MODELS_DIR + id + ".res")
		item.material_override = ItemMesh.make_material(id)
		for frame in 15:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/grip_previews/source_%s.png" % id)
	quit()

