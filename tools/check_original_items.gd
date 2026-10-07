extends SceneTree

func _init() -> void:
	for body in ["hombre", "mujer"]:
		var mesh: ArrayMesh = load("res://assets/models/character/%s/arm_right_lower.res" % body)
		print(body, " forearm ", mesh.get_aabb())
	for file in DirAccess.get_files_at(ItemMesh.MODELS_DIR):
		if not file.ends_with(".res"):
			continue
		var mesh: ArrayMesh = load(ItemMesh.MODELS_DIR + file)
		assert(mesh.surface_get_array_index_len(0) / 3 == mesh.get_meta("original_triangles"))
		var material := ItemMesh.make_material(file.get_basename())
		assert(material.albedo_texture != null)
		print(file, " ", mesh.get_meta("original_triangles"), " triangles; texture ", material.albedo_texture.get_size())
	for file in DirAccess.get_files_at("res://assets/models_raw/meshy/items/"):
		if not file.ends_with(".glb"):
			continue
		var state := GLTFState.new()
		assert(GLTFDocument.new().append_from_file("res://assets/models_raw/meshy/items/" + file, state) == OK)
		var source: ImporterMesh = state.get_meshes()[0].mesh
		var ids := [file.get_basename()]
		if file.get_basename() in ["stone_axe", "spear", "arrow"]:
			ids.append(file.get_basename() + "_variant")
		elif file.get_basename() == "recursos_madera_piedra":
			ids = ["log_bundle", "rock", "flint"]
		var total := 0
		for id in ids:
			var mesh: ArrayMesh = load(ItemMesh.MODELS_DIR + id + ".res")
			total += mesh.surface_get_array_index_len(0)
			var material := mesh.surface_get_material(0) as BaseMaterial3D
			assert(material.albedo_texture.get_image().get_data() == source.get_surface_material(0).albedo_texture.get_image().get_data())
		assert(total == source.get_surface_arrays(0)[Mesh.ARRAY_INDEX].size())
	print("PASS: todos los triángulos y píxeles originales")
	quit()
