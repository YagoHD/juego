extends StaticBody3D
class_name Raft
## Balsa de tablas: flota en el mar. Clic derecho para subir; W A S D para navegar (solo por
## agua); Espacio para bajar. Se balancea con las olas.

const SPEED := 3.2
const TURN := 1.6
const LAYER := 2   # la ve el rayo del jugador (para subir), el cuerpo no choca con ella

var generator: IslandGenerator
var voxel_size := 0.5
var _time := 0.0
var _model: Node3D


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	_model = Node3D.new()
	add_child(_model)
	var wood := Color(0.6, 0.43, 0.25)
	for k in 5:  # tablas
		_box(Vector3(-0.6 + k * 0.3, 0.0, 0), Vector3(0.27, 0.08, 1.6), wood.darkened(0.06 * (k % 2)))
	for z in [-0.6, 0.6]:  # travesaños atados
		_box(Vector3(0, 0.07, z), Vector3(1.55, 0.06, 0.12), wood.darkened(0.25))
		_box(Vector3(0, 0.1, z), Vector3(0.1, 0.04, 0.14), Color(0.8, 0.66, 0.42))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.25, 1.7)
	shape.shape = box
	add_child(shape)


func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	part.material_override = material
	part.position = pos
	_model.add_child(part)


## Altura de la superficie del mar (metros).
func sea_y() -> float:
	return IslandGenerator.SEA_LEVEL * voxel_size - 0.05


## ¿Se puede navegar por aquí? (mar con al menos un bloque de fondo)
func is_water(p: Vector3) -> bool:
	if generator == null:
		return false
	return generator.get_ground_height(int(floorf(p.x / voxel_size)), int(floorf(p.z / voxel_size))) <= IslandGenerator.SEA_LEVEL - 1


func _process(delta: float) -> void:
	_time += delta
	# Mecerse con las olas.
	global_position.y = sea_y() + sin(_time * 1.3) * 0.04
	_model.rotation = Vector3(sin(_time * 1.1) * 0.03, 0.0, sin(_time * 0.9 + 1.0) * 0.04)


## Navegar: forward/turn de -1 a 1. No entra en tierra.
func steer(forward: float, turn: float, delta: float) -> void:
	rotation.y += turn * TURN * delta
	if absf(forward) < 0.01:
		return
	var dir := -global_basis.z * forward
	var next := global_position + dir * SPEED * delta
	if is_water(next):
		global_position.x = next.x
		global_position.z = next.z


func to_data() -> Dictionary:
	return {"pos": [global_position.x, global_position.z], "yaw": rotation.y}
