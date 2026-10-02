extends StaticBody3D
class_name PlacedItem
## Un objeto dejado en el suelo a mano (tecla G o clic derecho): se queda quieto, tumbado, en
## el punto exacto y con el giro con que se dejó. Se puede apilar encima de otro (G apuntando
## a su cara de arriba). No es un bloque ni se recoge solo: se coge con clic izquierdo.
## Sirve para fabricar por formas (ver GroundCrafting).

const LAYER := 2  # capa de física propia: el rayo del jugador lo ve, el cuerpo no choca

var item_id := ""
var support := Vector3i.ZERO  # bloque sobre el que está apoyada su columna
var column := Vector2i.ZERO   # celda invisible (x, z) de su columna
var level := 0                # 0 = en el suelo; 1, 2... = apilado encima de otros
var base_y := 0.0             # altura del suelo de su columna
var _material: StandardMaterial3D
var _glow := false
var _glow_strength := 1.0
var _time := 0.0
var _box := AABB()  # caja que ocupa, relativa a su posición (para el recuadro al apuntarlo)


## Alto que ocupa (lo que sube el siguiente que se apile encima).
static func height_of(id: String) -> float:
	return 0.18 if ItemDB.block_of(id) >= 0 else 0.3 / ItemPainter.S * 2.6


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	var is_block := ItemDB.block_of(item_id) >= 0
	var size := 0.18 if is_block else (0.42 if item_id == "captain_journal" else 0.3)
	var mesh := MeshInstance3D.new()
	mesh.mesh = ItemMesh.make(item_id, size)
	_material = ItemMesh.make_material(item_id)
	mesh.material_override = _material
	var height := height_of(item_id)
	if is_block:
		mesh.position.y = size * 0.5
	else:
		mesh.rotation.x = -PI / 2.0  # tumbado en el suelo
		mesh.position.y = height * 0.5 + 0.004
	add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, maxf(height, 0.06), size)
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	add_child(shape)
	_box = AABB(Vector3(-size * 0.5, 0.0, -size * 0.5), box.size).grow(0.01)
	set_process(false)


func height() -> float:
	return height_of(item_id)


## Caja que ocupa (relativa a su posición, sin girar), un pelín más grande.
func get_box() -> AABB:
	return _box


## Brillo suave cuando forma parte de una receta que el personaje sabe hacer.
func set_glow(on: bool, strength := 1.0) -> void:
	_glow_strength = strength
	if on == _glow:
		return
	_glow = on
	_material.emission_enabled = on
	_material.emission = Color(1.0, 0.8, 0.4)
	set_process(on)


func _process(delta: float) -> void:
	_time += delta
	_material.emission_energy_multiplier = (0.45 + 0.3 * sin(_time * 4.0)) * _glow_strength


func to_data() -> Dictionary:
	return {"id": item_id, "pos": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y, "support": [support.x, support.y, support.z],
		"column": [column.x, column.y], "level": level, "base_y": base_y}
