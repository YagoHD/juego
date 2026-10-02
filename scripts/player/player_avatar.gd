extends Node3D
class_name PlayerAvatar
## Muñeco provisional del jugador hecho de bloques (hasta que haya un modelo de verdad).
## Mide lo mismo que el jugador (1,4 m), mira hacia -Z y anima brazos, piernas y cabeza.
## Todas sus mallas están en la capa visual 2: la cámara en primera persona no las dibuja,
## pero siguen proyectando sombra.

const LAYER := 1 << 1

const SKIN := Color(0.86, 0.66, 0.52)
const SHIRT := Color(0.26, 0.40, 0.62)
const PANTS := Color(0.30, 0.24, 0.20)
const HAIR := Color(0.24, 0.16, 0.10)
const SHOES := Color(0.16, 0.13, 0.11)
const EYES := Color(0.08, 0.08, 0.10)

var _head: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _leg_left: Node3D
var _leg_right: Node3D
var _held: MeshInstance3D
var _walk_phase := 0.0
var _walk_amount := 0.0
var _swing := 0.0


func _ready() -> void:
	# Piernas (pivote en la cadera).
	_leg_left = _make_limb(Vector3(-0.095, 0.60, 0.0))
	_add_box(_leg_left, Vector3(0, -0.24, 0), Vector3(0.17, 0.48, 0.19), PANTS)
	_add_box(_leg_left, Vector3(0, -0.54, -0.02), Vector3(0.18, 0.12, 0.23), SHOES)
	_leg_right = _make_limb(Vector3(0.095, 0.60, 0.0))
	_add_box(_leg_right, Vector3(0, -0.24, 0), Vector3(0.17, 0.48, 0.19), PANTS)
	_add_box(_leg_right, Vector3(0, -0.54, -0.02), Vector3(0.18, 0.12, 0.23), SHOES)

	# Tronco.
	_add_box(self, Vector3(0, 0.83, 0), Vector3(0.38, 0.46, 0.22), SHIRT)

	# Brazos (pivote en el hombro): manga arriba, piel abajo.
	_arm_left = _make_limb(Vector3(-0.255, 1.03, 0.0))
	_add_box(_arm_left, Vector3(0, -0.10, 0), Vector3(0.13, 0.20, 0.15), SHIRT)
	_add_box(_arm_left, Vector3(0, -0.32, 0), Vector3(0.12, 0.24, 0.14), SKIN)
	_arm_right = _make_limb(Vector3(0.255, 1.03, 0.0))
	_add_box(_arm_right, Vector3(0, -0.10, 0), Vector3(0.13, 0.20, 0.15), SHIRT)
	_add_box(_arm_right, Vector3(0, -0.32, 0), Vector3(0.12, 0.24, 0.14), SKIN)

	# Bloque en la mano derecha.
	_held = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.15
	_held.mesh = box
	_held.position = Vector3(0, -0.47, -0.08)
	_held.layers = LAYER
	_arm_right.add_child(_held)

	# Cabeza (pivote en el cuello): cara, pelo y ojos mirando a -Z.
	_head = _make_limb(Vector3(0, 1.06, 0.0))
	_add_box(_head, Vector3(0, 0.15, 0), Vector3(0.30, 0.30, 0.30), SKIN)
	_add_box(_head, Vector3(0, 0.29, 0.02), Vector3(0.32, 0.06, 0.32), HAIR)
	_add_box(_head, Vector3(0, 0.20, 0.13), Vector3(0.32, 0.20, 0.08), HAIR)
	_add_box(_head, Vector3(-0.07, 0.17, -0.151), Vector3(0.05, 0.05, 0.01), EYES)
	_add_box(_head, Vector3(0.07, 0.17, -0.151), Vector3(0.05, 0.05, 0.01), EYES)


func _make_limb(pivot: Vector3) -> Node3D:
	var limb := Node3D.new()
	limb.position = pivot
	add_child(limb)
	return limb


func _add_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	part.material_override = material
	part.layers = LAYER
	parent.add_child(part)


func set_block(id: int) -> void:
	_held.material_override = Blocks.make_material(id)


## Hacia dónde mira (arriba/abajo), en radianes.
func set_look_pitch(pitch: float) -> void:
	_head.rotation.x = clampf(pitch, -0.9, 0.7)


func swing() -> void:
	_swing = 1.0


## speed01 = 0 quieto, 1 andando a velocidad normal. on_floor = false en el aire.
func update_walk(speed01: float, on_floor: bool, delta: float) -> void:
	var target := clampf(speed01, 0.0, 1.0) if on_floor else 0.0
	_walk_amount = lerpf(_walk_amount, target, 1.0 - exp(-10.0 * delta))
	_walk_phase += delta * 9.0 * _walk_amount


func _process(delta: float) -> void:
	_swing = maxf(_swing - delta * 4.5, 0.0)
	var stride := sin(_walk_phase) * 0.75 * _walk_amount
	_leg_left.rotation.x = stride
	_leg_right.rotation.x = -stride
	_arm_left.rotation.x = -stride * 0.8
	# El brazo derecho sostiene el bloque un poco adelantado y da el golpe al romper/colocar.
	# (ángulo positivo en X = brazo hacia delante, porque el muñeco mira a -Z).
	_arm_right.rotation.x = stride * 0.8 + 0.35 + sin(_swing * PI) * 1.4
