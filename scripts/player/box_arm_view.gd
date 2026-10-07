extends Node3D
## Brazo de primera persona de CAJAS (estilo nuevo, docs/estilo/guia_23_brazo.png): el brazo
## derecho de la skin del jugador (con la manga rota y la muñequera de su capa exterior), como en
## Minecraft. Es rígido: la mano está en el punto de agarre (el origen de HeldBlock, su padre) y el
## brazo apunta siempre al hombro, fijo junto a la cámara; así los golpes, el paso y el cambio de
## objeto de HeldBlock mueven la mano y el brazo la sigue.
## Mismo uso que el brazo de Meshy (real_arm_view.gd): build(color, capa) y pose(nombre).

## Hombro respecto a los ojos (metros, ejes de la cámara: x derecha, y arriba, z hacia atrás).
const SHOULDER := Vector3(0.55, -0.45, -0.15)
## Tamaño del brazo respecto al del personaje (en primera persona se ve más grande, como en Minecraft).
const SCALE := 1.35
## Píxeles de skin desde el final de la mano hasta el punto de agarre (el objeto va en el puño).
const GRIP_FROM_END := 1.5

var skin: Texture2D        # la skin del jugador (la pone HeldBlock antes de build)
var slim := false
var _pivot: Node3D
var _wrist: Node3D        # mano del modelo de cajas (con sus falanges)
var _hand_pose := "relaxed"


func build(_color: Color, layer: int) -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	if BoxModel.available() and not FileAccess.file_exists(SkinComposer.USER_SKIN_PATH):
		_build_box_model(layer)
	else:
		_build_skin_arm(layer)
	_pivot.scale = Vector3.ONE * SCALE


## El brazo del modelo de cajas (BoxModel): el mismo que se ve en tercera persona, con mano,
## pulgar, pulseras y manga. Se coloca con su punto de agarre en el origen y el hombro en +Y.
func _build_box_model(layer: int) -> void:
	var arm := BoxModel.make_part("arm_right", layer)
	var lower := arm.get_node("lower") as Node3D
	var grip := lower.get_node("grip") as Node3D
	var grip_pos := lower.position + grip.position  # respecto al hombro
	_wrist = lower.get_node_or_null("wrist") as Node3D
	BoxModel.pose_hand(_wrist, _hand_pose, true)
	var align := Node3D.new()
	align.basis = Basis(Quaternion((-grip_pos).normalized(), Vector3.UP))
	_pivot.add_child(align)
	arm.position = -grip_pos
	align.add_child(arm)
	for mesh in arm.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := (mesh as MeshInstance3D).material_override as StandardMaterial3D
		if material != null:
			material.disable_receive_shadows = true


## Brazo de una skin de Minecraft (si el jugador tiene la suya): una caja con su textura.
func _build_skin_arm(layer: int) -> void:
	if skin == null:
		skin = SkinComposer.load_player_skin()
	var material := SkinModel.make_material(skin)
	material.disable_receive_shadows = true
	var info: Dictionary = SkinModel.PARTS["arm_right"]
	var bottom: float = Vector3(info["min"]).y  # final de la mano, en px desde el hombro
	# El brazo sube por +Y desde el punto de agarre (y = 0) hasta el hombro.
	var origin := Vector3(0, bottom + GRIP_FROM_END, 0)
	for overlay in [false, true]:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = SkinModel.part_mesh("arm_right", slim, overlay, Vector2i(0, -1), origin)
		mesh_instance.material_override = material
		mesh_instance.layers = layer
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pivot.add_child(mesh_instance)


## Postura de la mano (BoxModel.HAND_POSES): "relaxed", "handle" (puño sobre un mango), "cup",
## "pinch", "open" o "float" (palma arriba, el bloque levita encima). Los dedos van llegando poco a poco.
func pose(mode: String, instant := false) -> void:
	_hand_pose = mode
	if instant:
		BoxModel.pose_hand(_wrist, mode, true)


func _process(delta: float) -> void:
	BoxModel.pose_hand(_wrist, _hand_pose, true, 1.0 - exp(-14.0 * delta))
	var hand := get_parent() as Node3D
	if hand == null or _pivot == null:
		return
	# Hombro y "arriba" de la cámara en el espacio de la mano (HeldBlock, hijo de la cámara).
	var to_shoulder := hand.transform.affine_inverse() * SHOULDER
	var up := (hand.basis.inverse() * Vector3.UP).normalized()
	var y := to_shoulder.normalized()
	# La mano de lado, como en la guía: el índice arriba (los dedos en fila de arriba abajo), así un
	# mango vertical pasa por dentro del puño.
	var z := -(up - y * up.dot(y))
	if z.length_squared() < 0.01:
		return
	z = z.normalized()
	var x := y.cross(z)
	_pivot.basis = Basis(x, y, z).scaled(Vector3.ONE * SCALE)
