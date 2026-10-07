extends SceneTree

## Modelos de Meshy para la vista en primera persona, tal cual (sin tocar la malla ni los huesos).
## Uso: godot --headless --path . --script res://tools/import_view_hands.gd -- [nombre ...]
## Sin nombres: todos.
const SOURCES := {
	"hombre": "res://docs/mano/Meshy_AI_Character_output.glb",
	"mujer": "res://docs/mano/femeninai/Meshy_AI_Character_output (1).glb",
	"brazo_real": "res://docs/mano/brazo final hombre/Meshy_AI_Character_output (2).glb",
}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/models/hands"))
	var names: Array = OS.get_cmdline_user_args()
	if names.is_empty():
		names = SOURCES.keys()
	for body in names:
		var path: String = SOURCES[body]
		var state := GLTFState.new()
		assert(GLTFDocument.new().append_from_file(path, state) == OK)
		var scene := GLTFDocument.new().generate_scene(state)
		_convert(scene)
		print("BODY ", body)
		_inspect(scene)
		var packed := PackedScene.new()
		assert(packed.pack(scene) == OK)
		assert(ResourceSaver.save(packed, "res://assets/models/hands/%s.scn" % body) == OK)
		scene.free()
	quit()

func _convert(node: Node) -> void:
	for child in node.get_children():
		_convert(child)
	if node is ImporterMeshInstance3D:
		var converted := MeshInstance3D.new()
		converted.name = node.name
		converted.transform = node.transform
		converted.mesh = node.mesh.get_mesh()
		converted.skin = node.skin
		converted.skeleton = node.skeleton_path
		var parent := node.get_parent()
		parent.remove_child(node)
		parent.add_child(converted)
		converted.owner = parent.owner if parent.owner != null else parent
		node.free()

func _inspect(node: Node) -> void:
	if node is Skeleton3D:
		for i in node.get_bone_count():
			print(i, " ", node.get_bone_name(i), " parent=", node.get_bone_parent(i), " rest=", node.get_bone_global_rest(i).origin)
	if node is MeshInstance3D:
		print("MESH ", node.get_aabb(), " transform ", node.transform)
	for child in node.get_children():
		_inspect(child)
