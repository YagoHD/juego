extends SceneTree

func _init() -> void:
	var rig := preload("res://scripts/player/first_person_hand.gd").new()
	rig.build(CastawayModel.SKIN, HeldBlock.VIEW_LAYER)
	var nodes: Array[Node3D] = []
	_collect(rig, nodes)
	var positions := []
	var scales := []
	for node in nodes:
		positions.append(node.position)
		scales.append(node.scale)
	for pose in ["handle", "cup", "pinch", "open", "relaxed"]:
		rig.pose(pose, true)
		for i in nodes.size():
			assert(nodes[i].position.is_equal_approx(positions[i]), "El agarre no debe estirar huesos")
			assert(nodes[i].scale.is_equal_approx(scales[i]), "El agarre no debe escalar dedos")
	rig.free()
	for body in ["hombre", "mujer"]:
		Settings.body = body
		var original_hand := preload("res://scripts/player/meshy_view_hand.gd").new()
		original_hand.build(CastawayModel.SKIN, HeldBlock.VIEW_LAYER)
		var skeleton: Skeleton3D = original_hand._skeleton
		var meshes := original_hand.find_children("*", "MeshInstance3D", true, false)
		assert(meshes.size() == 1)
		var mesh_instance := meshes[0] as MeshInstance3D
		assert(mesh_instance.skin != null)
		assert(mesh_instance.skin.get_bind_count() == skeleton.get_bone_count())
		assert(mesh_instance.mesh.surface_get_array_index_len(0) / 3 == (125672 if body == "hombre" else 121114))
		var bind_positions := []
		var bind_scales := []
		for bone in skeleton.get_bone_count():
			bind_positions.append(skeleton.get_bone_pose_position(bone))
			bind_scales.append(skeleton.get_bone_pose_scale(bone))
		for pose in ["handle", "cup", "pinch", "open", "relaxed"]:
			original_hand.pose(pose, true)
			if pose == "handle":
				assert(not skeleton.get_bone_pose_rotation(original_hand._joints[0]).is_equal_approx(original_hand._rest[0]))
			for bone in skeleton.get_bone_count():
				assert(skeleton.get_bone_pose_position(bone).is_equal_approx(bind_positions[bone]))
				assert(skeleton.get_bone_pose_scale(bone).is_equal_approx(bind_scales[bone]))
		print(body, ": ", skeleton.get_bone_count(), " huesos, cinco poses sin estirar")
		original_hand.free()
	var profiles := preload("res://scripts/player/first_person_items.gd")
	for id in profiles.PROFILES:
		if not ItemMesh.has_model(id):
			continue
		var profile: Dictionary = profiles.PROFILES[id]
		var held := ItemMesh.make_held(id, profile["length"], profile["grip"])
		var original: ArrayMesh = load(ItemMesh.MODELS_DIR + id + ".res")
		assert(held.surface_get_array_index_len(0) == original.surface_get_array_index_len(0))
		var bounds := held.get_aabb().size
		assert(is_equal_approx(maxf(bounds.x, maxf(bounds.y, bounds.z)), profile["length"]))
		var held_vertices: PackedVector3Array = held.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var original_vertices: PackedVector3Array = original.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		# Una traslación o rotación no altera las distancias: detectar cualquier escalado desigual.
		for i in range(1, mini(original_vertices.size(), 100), 7):
			assert(is_equal_approx(held_vertices[0].distance_to(held_vertices[i]), original_vertices[0].distance_to(original_vertices[i]) * profile["length"]))
		print(id, " length=", profile["length"], " grip=", profile["grip"])
	print("PASS: cinco poses sin estirar la mano; escala uniforme y triángulos intactos")
	quit()

func _collect(parent: Node3D, nodes: Array[Node3D]) -> void:
	nodes.append(parent)
	for child in parent.get_children():
		if child is Node3D:
			_collect(child, nodes)
