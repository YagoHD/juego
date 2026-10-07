extends Node3D
## Usa el esqueleto y los pesos originales de las manos de docs/mano.
const DIR := "res://assets/models/hands/"
const CHAINS := {
	"hombre": [["Bone_027", "Bone_026", "Bone_025"], ["Bone_022", "Bone_021", "Bone_020"], ["Bone_017", "Bone_016", "Bone_015"], ["Bone_012", "Bone_011", "Bone_010"]],
	"mujer": [["Bone_026", "Bone_025", "Bone_024"], ["Bone_021", "Bone_020", "Bone_019"], ["Bone_016", "Bone_015", "Bone_014"], ["Bone_007", "Bone_006", "Bone_005"]],
}
const THUMBS := {"hombre": ["Bone_008", "Bone_007", "Bone_006"], "mujer": ["Bone_011", "Bone_010", "Bone_009"]}
var _skeleton: Skeleton3D
var _model: Node3D
var _joints: Array[int] = []
var _rest: Array[Quaternion] = []
var _axes: Array[Vector3] = []
var _angles: Array[float] = []
var _target := Vector3.ZERO
var _thumb_target := Vector3.ZERO
var body := ""

func build(_skin: Color, layer: int) -> void:
	body = Settings.body
	_model = load(DIR + body + ".scn").instantiate()
	add_child(_model)
	_setup(_model, layer)
	assert(_skeleton != null)
	var knuckles: Array[Vector3] = []
	for chain in CHAINS[body]:
		knuckles.append(_skeleton.get_bone_global_rest(_skeleton.find_bone(chain[0])).origin)
	var wrist := _skeleton.get_bone_global_rest(_skeleton.find_bone("Bone_003" if body == "hombre" else "Bone_002")).origin
	var center := Vector3.ZERO
	for p in knuckles:
		center += p / 4.0
	var forward := (center - wrist).normalized()
	var across := (knuckles[0] - knuckles[3]).normalized()
	across = (across - forward * across.dot(forward)).normalized()
	var front := across.cross(forward).normalized()
	var orientation := Basis(-forward, across, front).transposed()
	var scale_factor := (0.092 if body == "hombre" else 0.085) / wrist.distance_to(center)
	var grip := center - forward * 0.08 + front * 0.15
	var basis := orientation.scaled(Vector3.ONE * scale_factor)
	_model.transform = Transform3D(basis, -(basis * grip))
	for chain in CHAINS[body]:
		for name in chain:
			_register(name, across)
	for name in THUMBS[body]:
		_register(name, across)
	pose("relaxed", true)

func _setup(node: Node, layer: int) -> void:
	if node is Skeleton3D:
		_skeleton = node
		_skeleton.reset_bone_poses()
	if node is AnimationPlayer:
		node.stop()
		node.active = false
	if node is MeshInstance3D:
		node.layers = layer
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in node.mesh.get_surface_count():
			var material := node.mesh.surface_get_material(i).duplicate() as BaseMaterial3D
			material.no_depth_test = false
			material.disable_receive_shadows = true
			node.set_surface_override_material(i, material)
	for child in node.get_children():
		_setup(child, layer)

func _register(name: String, axis: Vector3) -> void:
	var bone := _skeleton.find_bone(name)
	assert(bone >= 0)
	_joints.append(bone)
	_rest.append(_skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
	_axes.append((_skeleton.get_bone_global_rest(bone).basis.inverse() * axis).normalized())
	_angles.append(0.0)

func pose(mode: String, instant := false) -> void:
	match mode:
		"handle":
			_target = Vector3(28, 38, 26)
			_thumb_target = Vector3(20, 20, 12)
		"pinch":
			_target = Vector3(18, 23, 15)
			_thumb_target = Vector3(15, 12, 8)
		"cup":
			_target = Vector3(10, 18, 12)
			_thumb_target = Vector3(8, 10, 5)
		"open":
			_target = Vector3(-8, -8, -5)
			_thumb_target = Vector3.ZERO
		_:
			_target = Vector3.ZERO
			_thumb_target = Vector3.ZERO
	if instant:
		_animate(1.0)

func _process(delta: float) -> void:
	_animate(1.0 - exp(-16.0 * delta))

func _animate(t: float) -> void:
	for i in _joints.size():
		var target := _target[i % 3] if i < 12 else _thumb_target[i % 3]
		_angles[i] = lerpf(_angles[i], deg_to_rad(target), t)
		_skeleton.set_bone_pose_rotation(_joints[i], _rest[i] * Quaternion(_axes[i], _angles[i]))
