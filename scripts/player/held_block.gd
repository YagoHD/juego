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
var _block_id := -1
var _swing := 0.0   # 1 al empezar un golpe, baja a 0
var _equip := 0.0   # 1 al cambiar de bloque (el brazo viene desde abajo), baja a 0
var _bob_phase := 0.0
var _bob_amount := 0.0


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
	if _block_id != -1:
		_show_block(_block_id)


func _show_block(id: int) -> void:
	# Cubo con las texturas del bloque, dibujado siempre por encima del mundo y del brazo.
	# id < 0 = mano vacía.
	_block_mesh.visible = id >= 0
	if id < 0:
		return
	_block_mesh.mesh = BlockTextures.make_block_mesh(id, BLOCK_SIZE)
	var material := BlockTextures.make_material(id == IslandGenerator.WATER)
	material.no_depth_test = true
	material.render_priority = 11
	# Sin sombras: el cuerpo del propio personaje proyectaba la suya sobre el bloque y lo volvía
	# azulado (solo le llegaba la luz del cielo).
	material.disable_receive_shadows = true
	_block_mesh.material_override = material


func set_block(id: int) -> void:
	if id == _block_id:
		return
	var first_time := _block_id == -1
	_block_id = id
	if _block_mesh != null:
		_show_block(id)
	if not first_time:
		_equip = 1.0


## Golpe de brazo al romper o colocar.
func swing() -> void:
	_swing = 1.0


## Balanceo al andar: speed01 = 0 quieto, 1 andando a velocidad normal.
func update_walk(speed01: float, delta: float) -> void:
	_bob_amount = lerpf(_bob_amount, clampf(speed01, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	_bob_phase += delta * 9.0 * _bob_amount


func _process(delta: float) -> void:
	_swing = maxf(_swing - delta * 4.0, 0.0)
	_equip = maxf(_equip - delta * 5.0, 0.0)

	# Golpe: el brazo baja y gira hacia el centro en un arco desde el hombro, y vuelve.
	var s := sin(_swing * PI)
	var s2 := sin(_swing * _swing * PI)  # algo adelantada respecto a s: el arco no es simétrico
	var bob := Vector3(sin(_bob_phase) * 0.012, -absf(cos(_bob_phase)) * 0.016, 0.0) * _bob_amount
	# El arco va hacia el centro de la pantalla y hacia delante (como en Minecraft), sin bajar
	# hasta salirse de la vista.
	position = REST_POSITION + bob + Vector3(-0.10 * s2, 0.02 * s - 0.30 * _equip, -0.07 * s)
	rotation = REST_ROTATION + Vector3(0.22 * s, 0.45 * s2, -0.18 * s)
	# Codo algo doblado sosteniendo el bloque; al golpear se estira hacia él.
	if _forearm != null:
		_forearm.rotation.x = ELBOW_REST - 0.3 * s
