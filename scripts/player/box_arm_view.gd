extends Node3D
## Brazo de primera persona de CAJAS (estilo nuevo, docs/estilo/guia_23_brazo.png): el brazo
## derecho de la skin del jugador (con la manga rota y la muñequera de su capa exterior), como en
## Minecraft. Es rígido: la mano está en el punto de agarre (el origen de HeldBlock, su padre) y el
## brazo apunta siempre al hombro, fijo junto a la cámara; así los golpes, el paso y el cambio de
## objeto de HeldBlock mueven la mano y el brazo la sigue.
## Mismo uso que el brazo de Meshy (real_arm_view.gd): build(color, capa) y pose(nombre).

## Hombro respecto a los ojos (metros, ejes de la cámara: x derecha, y arriba, z hacia atrás).
const SHOULDER := Vector3(0.50, -0.38, 0.02)
## Tamaño del brazo respecto al del personaje (en primera persona se ve más grande, como en Minecraft).
const SCALE := 1.35
## Píxeles de skin desde el final de la mano hasta el punto de agarre (el objeto va en el puño).
const GRIP_FROM_END := 1.5

var skin: Texture2D        # la skin del jugador (la pone HeldBlock antes de build)
var slim := false
var _pivot: Node3D


func build(_color: Color, layer: int) -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
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
	_pivot.scale = Vector3.ONE * SCALE


## Las cajas no tienen dedos: las posturas de la mano no cambian nada.
func pose(_mode: String, _instant := false) -> void:
	pass


func _process(_delta: float) -> void:
	var hand := get_parent() as Node3D
	if hand == null or _pivot == null:
		return
	# Hombro y "hacia la cámara" en el espacio de la mano (HeldBlock, hijo de la cámara).
	var to_shoulder := hand.transform.affine_inverse() * SHOULDER
	var back := (hand.basis.inverse() * Vector3.BACK).normalized()
	var y := to_shoulder.normalized()
	var x := y.cross(back).normalized()
	if not x.is_finite() or x.length_squared() < 0.5:
		return
	var z := x.cross(y)
	_pivot.basis = Basis(x, y, z).scaled(Vector3.ONE * SCALE)
