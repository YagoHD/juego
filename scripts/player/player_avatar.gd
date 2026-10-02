extends Node3D
class_name PlayerAvatar
## Cuerpo del jugador, construido a partir de su skin (formato Minecraft, ver Skin y
## docs/SKINS.md). Mide lo mismo que el jugador (1,4 m), mira hacia -Z y anima brazos,
## piernas y cabeza. Todas sus mallas están en la capa visual 2: la cámara en primera persona
## no las dibuja, pero siguen proyectando sombra.

const LAYER := 1 << 1

var _head: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _leg_left: Node3D
var _leg_right: Node3D
var _held: MeshInstance3D
var _walk_phase := 0.0
var _walk_amount := 0.0
var _swing := 0.0


## Construye el cuerpo con una skin (textura de 64x64). Se puede volver a llamar para cambiarla.
func build(texture: Texture2D, slim: bool) -> void:
	for child in get_children():
		child.queue_free()
	add_child(SkinModel.make_part("body", texture, slim, LAYER))
	_head = SkinModel.make_part("head", texture, slim, LAYER)
	_arm_right = SkinModel.make_part("arm_right", texture, slim, LAYER)
	_arm_left = SkinModel.make_part("arm_left", texture, slim, LAYER)
	_leg_right = SkinModel.make_part("leg_right", texture, slim, LAYER)
	_leg_left = SkinModel.make_part("leg_left", texture, slim, LAYER)
	for part in [_head, _arm_right, _arm_left, _leg_right, _leg_left]:
		add_child(part)

	# Bloque en la mano derecha (al final del brazo, un poco por delante).
	_held = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.15
	_held.mesh = box
	_held.position = Vector3(0, -11.0, -1.5) * SkinModel.PIXEL
	_held.layers = LAYER
	_arm_right.add_child(_held)


func set_block(id: int) -> void:
	if _held != null:
		_held.material_override = Blocks.make_material(id)


## Hacia dónde mira (arriba/abajo), en radianes.
func set_look_pitch(pitch: float) -> void:
	if _head != null:
		_head.rotation.x = clampf(pitch, -0.9, 0.7)


func swing() -> void:
	_swing = 1.0


## speed01 = 0 quieto, 1 andando a velocidad normal. on_floor = false en el aire.
func update_walk(speed01: float, on_floor: bool, delta: float) -> void:
	var target := clampf(speed01, 0.0, 1.0) if on_floor else 0.0
	_walk_amount = lerpf(_walk_amount, target, 1.0 - exp(-10.0 * delta))
	_walk_phase += delta * 9.0 * _walk_amount


func _process(delta: float) -> void:
	if _head == null:
		return
	_swing = maxf(_swing - delta * 4.5, 0.0)
	var stride := sin(_walk_phase) * 0.75 * _walk_amount
	_leg_left.rotation.x = stride
	_leg_right.rotation.x = -stride
	_arm_left.rotation.x = -stride * 0.8
	# El brazo derecho sostiene el bloque un poco adelantado y da el golpe al romper/colocar
	# (ángulo positivo en X = brazo hacia delante, porque el cuerpo mira a -Z).
	var s := sin(_swing * PI)
	_arm_right.rotation = Vector3(stride * 0.8 + 0.35 + s * 1.3, s * 0.3, -s * 0.15)
