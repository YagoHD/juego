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
var _light: OmniLight3D       # solo las antorchas
var _flame: MeshInstance3D


## Alto que ocupa (lo que sube el siguiente que se apile encima).
static func height_of(id: String) -> float:
	if id == "torch":
		return 0.6
	return 0.18 if ItemDB.block_of(id) >= 0 else 0.3 / ItemPainter.S * 2.6


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	if item_id == "torch":
		_build_torch()
		return
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
	set_process(on or _light != null)


func _process(delta: float) -> void:
	_time += delta
	if _light != null:
		TorchLight.flicker(_light, _flame, _time)
	if _glow:
		_material.emission_energy_multiplier = (0.45 + 0.3 * sin(_time * 4.0)) * _glow_strength


func to_data() -> Dictionary:
	return {"id": item_id, "pos": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y, "support": [support.x, support.y, support.z],
		"column": [column.x, column.y], "level": level, "base_y": base_y}


## Antorcha clavada de pie: palo, tela enrollada, llama y una luz cálida que parpadea.
func _build_torch() -> void:
	var stick := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.42, 0.05)
	stick.mesh = box
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.45, 0.3, 0.16)
	stick.material_override = _material
	stick.position.y = 0.21
	add_child(stick)
	var rag := MeshInstance3D.new()
	var rag_box := BoxMesh.new()
	rag_box.size = Vector3(0.08, 0.08, 0.08)
	rag.mesh = rag_box
	var rag_material := StandardMaterial3D.new()
	rag_material.albedo_color = Color(0.35, 0.3, 0.25)
	rag.material_override = rag_material
	rag.position.y = 0.44
	add_child(rag)
	_flame = TorchLight.make_flame()
	_flame.position.y = 0.53
	add_child(_flame)
	_light = TorchLight.make_light()
	_light.position.y = 0.6
	add_child(_light)
	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = Vector3(0.14, 0.6, 0.14)
	shape.shape = col
	shape.position.y = 0.3
	add_child(shape)
	_box = AABB(Vector3(-0.07, 0.0, -0.07), col.size).grow(0.01)
	set_process(true)
