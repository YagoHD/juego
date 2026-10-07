extends Node3D
## Brazo de primera persona hecho con Meshy ("brazo final hombre"), con su malla, textura y huesos
## tal cual. El hombro queda fijo junto a la cámara (abajo a la derecha, como el de verdad) y el
## brazo se dobla solo (hombro, codo y muñeca) para que la mano llegue al punto de agarre, que es
## el origen de su nodo padre (HeldBlock): los movimientos de golpe, paso y cambio de objeto de
## HeldBlock mueven la mano, y el brazo la sigue. Los dedos se cierran sobre el objeto.
const SCENE := "res://assets/models/hands/brazo_real.scn"
## Dónde está el hombro respecto a los ojos (metros, ejes de la cámara: x derecha, y arriba,
## z hacia atrás). Solo se cambia desde dónde se ve: la malla no se deforma ni se estira.
const SHOULDER := Vector3(0.19, -0.27, 0.06)
## Escala uniforme (igual en los tres ejes): el modelo viene medido en otras unidades; esto solo lo
## pone a la distancia de la cámara que corresponde a un brazo, sin cambiar sus proporciones.
const MODEL_SCALE := 0.334
## Huesos del modelo: clavícula, brazo, antebrazo, muñeca y palma.
const UPPER := "Bone_004"
const FOREARM := "Bone_003"
const WRIST := "Bone_002"
const PALM := "Bone_001"
## Dedos: índice, corazón, anular y meñique (de la base a la punta; el último hueso es la punta).
const FINGERS := [["Bone_020", "Bone_019", "Bone_018"], ["Bone_024", "Bone_023", "Bone_022"],
	["Bone_016", "Bone_015", "Bone_014"], ["Bone_012", "Bone_011", "Bone_010"]]
const THUMB := ["Bone_008", "Bone_007", "Bone_006"]
## Hacia dónde se dobla el codo (abajo y hacia fuera), en ejes de la cámara.
const ELBOW_POLE := Vector3(0.8, -1.0, 0.1)

var body := "brazo_real"
var _model: Node3D
var _skeleton: Skeleton3D
var _upper := -1
var _forearm := -1
var _wrist := -1
var _len_upper := 0.0
var _len_forearm := 0.0
var _grip_rest := Transform3D.IDENTITY   # el punto de agarre, en el espacio del esqueleto en reposo
var _joints: Array[int] = []
var _rest: Array[Quaternion] = []
var _axes: Array[Vector3] = []
var _angles: Array[float] = []
var _target := Vector3.ZERO
var _thumb_target := Vector3.ZERO


func build(_skin: Color, layer: int) -> void:
	_model = load(SCENE).instantiate()
	add_child(_model)
	_setup(_model, layer)
	assert(_skeleton != null)
	_upper = _skeleton.find_bone(UPPER)
	_forearm = _skeleton.find_bone(FOREARM)
	_wrist = _skeleton.find_bone(WRIST)
	var shoulder := _rest_origin(UPPER)
	var elbow := _rest_origin(FOREARM)
	var wrist := _rest_origin(WRIST)
	_len_upper = shoulder.distance_to(elbow)
	_len_forearm = elbow.distance_to(wrist)
	# Ejes de la mano en reposo: "adelante" de la muñeca a los nudillos, "a lo ancho" del meñique
	# al índice (por ahí pasa el mango al cerrar el puño) y "palma" hacia donde se cierran los dedos.
	var knuckles := Vector3.ZERO
	for chain in FINGERS:
		knuckles += _rest_origin(chain[0]) / 4.0
	var forward := (knuckles - wrist).normalized()
	var across := _rest_origin(FINGERS[0][0]) - _rest_origin(FINGERS[3][0])
	across = (across - forward * across.dot(forward)).normalized()
	var palm := across.cross(forward).normalized()
	# Mismo convenio que el resto de manos: el mango va por +Y, los nudillos hacia -X y la palma
	# hacia +Z. El agarre queda delante de la palma, entre la palma y los nudillos.
	var grip_point := _rest_origin(PALM).lerp(knuckles, 0.45) + palm * 0.07
	_grip_rest = Transform3D(Basis(-forward, across, palm), grip_point)
	for chain in FINGERS:
		for bone in chain:
			_register(bone, across)
	for bone in THUMB:
		_register(bone, across)
	pose("relaxed", true)


func _rest_origin(bone: String) -> Vector3:
	return _skeleton.get_bone_global_rest(_skeleton.find_bone(bone)).origin


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
			material.disable_receive_shadows = true
			node.set_surface_override_material(i, material)
	for child in node.get_children():
		_setup(child, layer)


func _register(bone_name: String, axis: Vector3) -> void:
	var bone := _skeleton.find_bone(bone_name)
	assert(bone >= 0)
	_joints.append(bone)
	_rest.append(_skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
	_axes.append((_skeleton.get_bone_global_rest(bone).basis.inverse() * axis).normalized())
	_angles.append(0.0)


## Cómo se cierran los dedos según lo que se coge (grados por falange).
func pose(mode: String, instant := false) -> void:
	match mode:
		"handle":
			_target = Vector3(70, 80, 50)
			_thumb_target = Vector3(25, 30, 20)
		"pinch":
			_target = Vector3(35, 45, 30)
			_thumb_target = Vector3(20, 20, 12)
		"cup":
			_target = Vector3(25, 35, 25)
			_thumb_target = Vector3(10, 12, 8)
		"float":  # palma abierta y algo cóncava, como sosteniendo algo que levita
			_target = Vector3(10, 12, 8)
			_thumb_target = Vector3(-5, 0, 0)
		"open":
			_target = Vector3(-5, -5, -3)
			_thumb_target = Vector3.ZERO
		_:
			_target = Vector3(6, 8, 5)
			_thumb_target = Vector3.ZERO
	if instant:
		_curl(1.0)


func _process(delta: float) -> void:
	_curl(1.0 - exp(-16.0 * delta))
	_reach()


func _curl(t: float) -> void:
	for i in _joints.size():
		var target := _target[i % 3] if i < 12 else _thumb_target[i % 3]
		_angles[i] = lerpf(_angles[i], deg_to_rad(target), t)
		_skeleton.set_bone_pose_rotation(_joints[i], _rest[i] * Quaternion(_axes[i], _angles[i]))


## Coloca el hombro junto a la cámara y dobla el brazo para que el agarre de la mano coincida con
## el origen del padre (HeldBlock), que es donde está el objeto.
func _reach() -> void:
	var parent := get_parent() as Node3D
	if _skeleton == null or parent == null:
		return
	# Este nodo vive en el espacio de la cámara: deshace el movimiento del padre.
	var model_basis := Basis(Vector3.UP, PI).scaled(Vector3.ONE * MODEL_SCALE)
	var shoulder_rest := _rest_origin(UPPER)
	var placement := Transform3D(model_basis, SHOULDER - model_basis * shoulder_rest)
	transform = parent.transform.affine_inverse() * placement
	# Todo lo que sigue, en el espacio del esqueleto (el de los huesos en reposo).
	var to_skeleton := placement.affine_inverse()
	var grip := to_skeleton * Transform3D(parent.transform.basis.orthonormalized(), parent.transform.origin)
	var grip_basis := grip.basis.orthonormalized()
	# La mano entera gira para que su agarre tenga la orientación del objeto.
	var hand_rotation := grip_basis * _grip_rest.basis.inverse()
	var wrist_rest := _skeleton.get_bone_global_rest(_wrist)
	var wrist_target := grip.origin - hand_rotation * (_grip_rest.origin - wrist_rest.origin)
	# Dos huesos (brazo y antebrazo): el codo, en el plano que marca la dirección del codo.
	var shoulder := shoulder_rest
	var reach := wrist_target - shoulder
	var distance := clampf(reach.length(), absf(_len_upper - _len_forearm) + 0.001, _len_upper + _len_forearm - 0.001)
	var direction := reach.normalized()
	var pole := (model_basis.inverse() * ELBOW_POLE).normalized()
	pole = (pole - direction * pole.dot(direction)).normalized()
	var along := (_len_upper * _len_upper - _len_forearm * _len_forearm + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, _len_upper * _len_upper - along * along))
	var elbow := shoulder + direction * along + pole * height
	var wrist := shoulder + direction * distance
	_aim_bone(_upper, shoulder, elbow, FOREARM)
	_aim_bone(_forearm, elbow, wrist, WRIST)
	_skeleton.set_bone_global_pose(_wrist, Transform3D(hand_rotation * wrist_rest.basis, wrist))


## Gira un hueso (desde su postura de reposo) para que apunte de 'from' a 'to', donde está su hijo.
func _aim_bone(bone: int, from: Vector3, to: Vector3, child: String) -> void:
	var rest := _skeleton.get_bone_global_rest(bone)
	var rest_direction := (_rest_origin(child) - rest.origin).normalized()
	var turn := Quaternion(rest_direction, (to - from).normalized())
	_skeleton.set_bone_global_pose(bone, Transform3D(Basis(turn) * rest.basis, from))
