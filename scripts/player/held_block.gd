extends Node3D
class_name HeldBlock
## El bloque seleccionado en la mano (vista en primera persona), con un trozo de brazo.
## Va pegado a la cámara y se dibuja siempre por encima del mundo (sin prueba de profundidad),
## así no se mete dentro de las paredes al acercarse a ellas.
## Animaciones: balanceo al andar, golpe al romper/colocar y "sacar" al cambiar de bloque.

const REST_POSITION := Vector3(0.40, -0.33, -0.72)  # abajo a la derecha de la vista
const REST_ROTATION := Vector3(-0.14, -0.66, 0.07)  # radianes (~ -8°, -38°, 4°)
const BLOCK_SIZE := 0.15
const SKIN := Color(0.86, 0.66, 0.52)
const SLEEVE := Color(0.26, 0.40, 0.62)

var _block_mesh: MeshInstance3D
var _block_id := -1
var _swing := 0.0   # 1 al empezar un golpe, baja a 0
var _equip := 0.0   # 1 al cambiar de bloque (el bloque viene desde abajo), baja a 0
var _bob_phase := 0.0
var _bob_amount := 0.0


func _ready() -> void:
	position = REST_POSITION
	rotation = REST_ROTATION

	_block_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * BLOCK_SIZE
	_block_mesh.mesh = box
	_block_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_block_mesh)

	# Antebrazo con manga, saliendo de la esquina de la pantalla hacia el bloque.
	_add_box(Vector3(0.06, -0.09, 0.13), Vector3(0.08, 0.08, 0.22), SKIN)
	_add_box(Vector3(0.08, -0.11, 0.28), Vector3(0.095, 0.095, 0.12), SLEEVE)


func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.position = pos
	part.material_override = _overlay_material(color)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)


func _overlay_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.no_depth_test = true  # siempre por encima del mundo
	material.render_priority = 10
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func set_block(id: int) -> void:
	if id == _block_id:
		return
	var first_time := _block_id == -1
	_block_id = id
	_block_mesh.material_override = _overlay_material(Blocks.color_of(id))
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
	_swing = maxf(_swing - delta * 4.5, 0.0)
	_equip = maxf(_equip - delta * 5.0, 0.0)

	# Golpe: el bloque baja y gira hacia delante, rápido y con vuelta suave.
	var s := sin(_swing * PI)
	var bob := Vector3(sin(_bob_phase) * 0.018, -absf(cos(_bob_phase)) * 0.022, 0.0) * _bob_amount
	position = REST_POSITION + bob + Vector3(-0.06 * s, -0.08 * s - 0.35 * _equip, -0.05 * s)
	rotation = REST_ROTATION + Vector3(-0.9 * s, 0.25 * s, 0.0)
