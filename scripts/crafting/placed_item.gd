extends StaticBody3D
class_name PlacedItem
## Un objeto dejado en el suelo a mano (tecla G o clic derecho): se queda quieto, tumbado, en
## el punto exacto y con el giro con que se dejó. No es un bloque ni se recoge solo: se coge
## con clic izquierdo. Sirve para fabricar por formas (ver GroundCrafting).

const LAYER := 2  # capa de física propia: el rayo del jugador lo ve, el cuerpo no choca

var item_id := ""
var support := Vector3i.ZERO  # bloque sobre el que está apoyado
var _material: StandardMaterial3D
var _glow := false
var _time := 0.0


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	var is_block := ItemDB.block_of(item_id) >= 0
	var size := 0.18 if is_block else 0.3
	var mesh := MeshInstance3D.new()
	mesh.mesh = ItemMesh.make(item_id, size)
	_material = ItemMesh.make_material(item_id)
	mesh.material_override = _material
	var height := size
	if is_block:
		mesh.position.y = size * 0.5
	else:
		height = size / ItemPainter.S  # un píxel de grosor
		mesh.rotation.x = -PI / 2.0  # tumbado en el suelo
		mesh.position.y = height * 0.5 + 0.004
	add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, maxf(height, 0.06), size)
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	add_child(shape)
	set_process(false)


## Brillo suave cuando forma parte de una receta que el personaje sabe hacer.
func set_glow(on: bool) -> void:
	if on == _glow:
		return
	_glow = on
	_material.emission_enabled = on
	_material.emission = Color(1.0, 0.82, 0.45)
	set_process(on)


func _process(delta: float) -> void:
	_time += delta
	_material.emission_energy_multiplier = 0.25 + 0.2 * sin(_time * 4.0)


func to_data() -> Dictionary:
	return {"id": item_id, "pos": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y, "support": [support.x, support.y, support.z]}
