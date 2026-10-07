extends SceneTree

func _init() -> void:
	Engine.max_fps = 60
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--body="):
			Settings.body = arg.trim_prefix("--body=")
	var output := "res://.godot/grip_previews/" + Settings.body + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
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
	light.light_cull_mask = 0xFFFFF
	light.layers = 0xFFFFF
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.current = true
	scene.add_child(camera)
	var hand := HeldBlock.new()
	camera.add_child(hand)
	hand.set_skin(null, false)
	camera.cull_mask = 0
	for id in ["stone_axe", "stone_pick", "stone_knife", "spear", "torch", "rock", "flint", "", "stone"]:
		hand.set_item(id)
		for frame in 40:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + "grip_%s.png" % (id if id != "" else "empty"))
		print("grip ", id)
	quit()
