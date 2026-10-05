extends Node3D
class_name HeldBlock
## Brazo derecho en primera persona (el mismo de la skin) sosteniendo el bloque seleccionado.
## Va pegado a la cámara, con el hombro fuera de la pantalla abajo a la derecha, y se dibuja
## siempre por encima del mundo (no se mete dentro de las paredes).
## Animaciones: balanceo al andar, golpe en arco desde el hombro al romper/colocar, y "sacar"
## el bloque al cambiar.

# Este nodo es el hombro (en coordenadas de la cámara); el brazo cuelga de él hacia -Y y
# la rotación de reposo lo apunta hacia delante y un poco hacia el centro de la pantalla.
const REST_POSITION := Vector3(0.30, -0.22, -0.10)
const REST_ROTATION := Vector3(1.32, 0.32, 0.10)
# El brazo de la skin a tamaño real queda enorme pegado a la cámara; se escala para que en
# pantalla mida siempre lo mismo, sea cual sea el tamaño del personaje.
const ARM_SCALE := 0.6 * 1.4 / SkinModel.BODY_HEIGHT
const BLOCK_SIZE := 0.13
const ELBOW_REST := 0.35  # codo un poco doblado (radianes)

var _arm: Node3D
var _forearm: Node3D       # segmento del codo hacia la mano
var _block_mesh: MeshInstance3D
var _item_id := ""
var _swing := 0.0   # 1 al empezar un golpe, baja a 0
var _equip := 0.0   # 1 al cambiar de bloque (el brazo viene desde abajo), baja a 0
var _bob_phase := 0.0
var _bob_amount := 0.0
var _in_leaves := false
var _leaves := 0.0  # 0..1: las manos suben delante de la cara apartando hojas
var _left: Node3D          # hombro izquierdo: solo sale entre hojas (se tapa los ojos)
var _left_forearm: Node3D


func _ready() -> void:
	position = REST_POSITION
	rotation = REST_ROTATION
	scale = Vector3.ONE * ARM_SCALE


## Construye el brazo con la skin del jugador (se puede volver a llamar para cambiarla).
func set_skin(texture: Texture2D, slim: bool) -> void:
	if _arm != null:
		_arm.queue_free()
	_arm = SkinModel.make_part("arm_right", texture, slim, 1, true)
	_arm.position = Vector3.ZERO  # el pivote de este nodo ya es el hombro
	add_child(_arm)

	_block_mesh = MeshInstance3D.new()
	# En la palma: al final del brazo y un poco por delante de él.
	_block_mesh.position = Vector3(0.0, -6.5, -3.6) * SkinModel.PIXEL
	_block_mesh.rotation = Vector3(-0.35, 0.6, 0.0)
	_block_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_forearm = _arm.get_node("lower") as Node3D
	_forearm.add_child(_block_mesh)
	# Brazo izquierdo: va aparte, colgado también de la cámara (este nodo es el hombro derecho).
	if _left != null:
		_left.queue_free()
	_left = Node3D.new()
	_left.scale = Vector3.ONE * ARM_SCALE
	_left.visible = false
	var arm_l := SkinModel.make_part("arm_left", texture, slim, 1, true)
	arm_l.position = Vector3.ZERO
	_left.add_child(arm_l)
	_left_forearm = arm_l.get_node("lower") as Node3D
	get_parent().add_child.call_deferred(_left)
	if _item_id != "":
		_show_item(_item_id)


func _show_item(id: String) -> void:
	# El objeto (cubo o dibujo con grosor), dibujado siempre por encima del mundo y del brazo.
	# "" = mano vacía.
	_block_mesh.visible = id != ""
	if id == "":
		return
	var held_size := BLOCK_SIZE * (1.6 if ItemDB.block_of(id) < 0 else 1.0)
	_block_mesh.mesh = ItemMesh.make(id, held_size)
	var material := ItemMesh.make_material(id)
	material.no_depth_test = true
	material.render_priority = 11
	# Sin sombras: el cuerpo del propio personaje proyectaba la suya sobre el bloque y lo volvía
	# azulado (solo le llegaba la luz del cielo).
	material.disable_receive_shadows = true
	_block_mesh.material_override = material


func set_item(id: String) -> void:
	if id == _item_id:
		return
	var first_time := _item_id == ""
	_item_id = id
	if _block_mesh != null:
		_show_item(id)
	if not first_time:
		_equip = 1.0


## Golpe de brazo al romper o colocar.
func swing() -> void:
	_swing = 1.0


## Balanceo al andar: speed01 = 0 quieto, 1 andando a velocidad normal.
## Cruzando hojas: la mano sube delante de la cara.
func set_in_leaves(on: bool) -> void:
	_in_leaves = on


func update_walk(speed01: float, delta: float) -> void:
	_bob_amount = lerpf(_bob_amount, clampf(speed01, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	_bob_phase += delta * 9.0 * _bob_amount


func _process(delta: float) -> void:
	_swing = maxf(_swing - delta * 4.0, 0.0)
	_equip = maxf(_equip - delta * 5.0, 0.0)
	_leaves = move_toward(_leaves, 1.0 if _in_leaves else 0.0, delta * 5.0)

	# Golpe: el brazo baja y gira hacia el centro en un arco desde el hombro, y vuelve.
	var s := sin(_swing * PI)
	var s2 := sin(_swing * _swing * PI)  # algo adelantada respecto a s: el arco no es simétrico
	var bob := Vector3(sin(_bob_phase) * 0.012, -absf(cos(_bob_phase)) * 0.016, 0.0) * _bob_amount
	# El arco va hacia el centro de la pantalla y hacia delante (como en Minecraft), sin bajar
	# hasta salirse de la vista.
	position = REST_POSITION + bob + Vector3(-0.10 * s2, 0.02 * s - 0.30 * _equip, -0.07 * s)
	rotation = REST_ROTATION + Vector3(0.22 * s, 0.45 * s2, -0.18 * s)
	if _leaves > 0.0:  # apartando hojas: la mano sube y cruza delante de la cara, de lado a lado
		var w := smoothstep(0.0, 1.0, _leaves)
		var a := sin(Time.get_ticks_msec() * 0.005)
		position += Vector3(-0.10 + 0.04 * a, 0.07, 0.04) * w
		rotation += Vector3(0.12, 0.35 + 0.12 * a, 0.0) * w
		_update_left(w, a)
	elif _left != null:
		_left.visible = false
	# Codo algo doblado sosteniendo el bloque; al golpear se estira hacia él.
	if _forearm != null:
		_forearm.rotation.x = ELBOW_REST - 0.3 * s


## Mano izquierda entre hojas: sube desde abajo, más alta que la derecha, delante de los ojos
## (como protegiéndose de las ramas), con un vaivén a contratiempo de la otra.
func _update_left(w: float, a: float) -> void:
	if _left == null:
		return
	_left.visible = visible and w > 0.01
	if not _left.visible:
		return
	var rest := Vector3(-REST_POSITION.x, REST_POSITION.y, REST_POSITION.z)
	_left.position = rest + Vector3(0.08 - 0.02 * a, 0.15 - 0.35 * (1.0 - w), -0.04)
	_left.rotation = Vector3(REST_ROTATION.x + 0.3, -REST_ROTATION.y - 0.2 + 0.08 * a, -REST_ROTATION.z)
	if _left_forearm != null:
		_left_forearm.rotation.x = 0.9
