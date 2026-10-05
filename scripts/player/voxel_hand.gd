extends Node3D
class_name VoxelHand
## Mano de cubitos con 5 dedos articulados (palma, 4 dedos de 2 falanges y pulgar), al final del
## antebrazo. Cambia de agarre según lo que lleve: cerrada alrededor de un mango (herramientas,
## palos, antorcha), en pinza (objetos pequeños), abierta (bloques) o relajada (vacía).
##
## Medidas en píxeles de skin (SkinModel.PIXEL); cubitos de un tercio de píxel. La palma mira hacia
## delante (-Z) y los dedos cuelgan hacia abajo (-Y); doblar un dedo es girarlo en X (positivo =
## hacia la palma). Relajada, la mano gira para que la palma mire al cuerpo.

const CUBE := 1.0 / 3.0          # cubito, en píxeles de skin
const PALM := Vector3i(11, 7, 5)  # en cubitos
const FINGER := [4, 3]           # largo de las dos falanges (cubitos)

## Agarres: [dedos (falange 1, falange 2) en grados, pulgar (giro hacia dentro, doblez), giro de
## la mano en Y (0 = palma delante; 1 = palma hacia el cuerpo)].
const GRIPS := {
	"relajada": [Vector2(18, 22), Vector2(20, 15), 1.0],
	"empuñar": [Vector2(88, 100), Vector2(55, 60), 0.0],
	"pinza": [Vector2(55, 60), Vector2(45, 40), 0.0],
	"abierta": [Vector2(12, 8), Vector2(10, 5), 0.0],
}

## Objetos que se empuñan (tienen mango) y objetos que van en la palma abierta.
const HANDLED := ["stone_knife", "stone_axe", "stone_pick", "spear", "torch", "sticks", "board",
	"fishing_rod", "flint", "sharp_rock"]

var side := 1.0                   # 1 = mano derecha, -1 = izquierda
var _fingers: Array[Node3D] = []  # falanges 1 (cada una con su falange 2 de hija)
var _thumb: Node3D
var _thumb_tip: Node3D
var _grip := ""
var _target := []                 # agarre al que va (se anima hacia él)


## Construye la mano. skin: color de la piel; layer/on_top como las piezas de SkinModel.
func build(skin: Color, right: bool, material: Material, layer: int, on_top: bool) -> void:
	side = 1.0 if right else -1.0
	var px := SkinModel.PIXEL
	var c := CUBE * px
	# Palma: de la muñeca (y = 0) hacia abajo, centrada.
	var palm := _box(PALM, skin, skin.darkened(0.08))
	var palm_node := _node(palm, material, layer, on_top)
	palm_node.position = Vector3(-PALM.x * 0.5, -PALM.y, -PALM.z * 0.5) * c
	add_child(palm_node)
	# Cuatro dedos en fila (de dentro a fuera), algo por delante del centro de la palma.
	for i in 4:
		var root := Node3D.new()
		var x := (-PALM.x * 0.5 + 1.0 + i * 3.0) * c * side
		root.position = Vector3(x, -PALM.y * c, -0.5 * c)
		add_child(root)
		var length := FINGER[0] - (1 if i == 3 else 0)  # el meñique, más corto
		var seg1 := _node(_box(Vector3i(2, length, 2), skin, skin.darkened(0.12)), material, layer, on_top)
		seg1.position = Vector3(-1, -length, -1) * c
		root.add_child(seg1)
		var tip := Node3D.new()
		tip.position = Vector3(0, -length, 0) * c
		root.add_child(tip)
		var tip_len: int = FINGER[1] - (1 if i == 3 else 0)
		var seg2 := _node(_box(Vector3i(2, tip_len, 2), skin.lightened(0.03), skin.lightened(0.12)), material, layer, on_top)
		seg2.position = Vector3(-1, -tip_len, -1) * c
		tip.add_child(seg2)
		_fingers.append(root)
	# Pulgar: en el lado de dentro (hacia el cuerpo) y por delante.
	_thumb = Node3D.new()
	_thumb.position = Vector3(-side * (PALM.x * 0.5 - 0.5), -2.0, -PALM.z * 0.5 + 0.5) * c
	add_child(_thumb)
	var t1 := _node(_box(Vector3i(2, 3, 2), skin, skin.darkened(0.1)), material, layer, on_top)
	t1.position = Vector3(-1, -3, -1) * c
	_thumb.add_child(t1)
	_thumb_tip = Node3D.new()
	_thumb_tip.position = Vector3(0, -3, 0) * c
	_thumb.add_child(_thumb_tip)
	var t2 := _node(_box(Vector3i(2, 3, 2), skin.lightened(0.03), skin.lightened(0.12)), material, layer, on_top)
	t2.position = Vector3(-1, -3, -1) * c
	_thumb_tip.add_child(t2)
	set_grip("relajada", true)


## Agarre según el objeto de la mano ("" = vacía).
func grip_for(item_id: String) -> void:
	if item_id == "":
		set_grip("relajada")
	elif item_id in HANDLED:
		set_grip("empuñar")
	elif ItemDB.block_of(item_id) >= 0:
		set_grip("abierta")
	else:
		set_grip("pinza")


func set_grip(grip: String, instant := false) -> void:
	if grip == _grip or not GRIPS.has(grip):
		return
	_grip = grip
	_target = GRIPS[grip]
	if instant:
		_apply(1.0)


func _process(delta: float) -> void:
	if not _target.is_empty():
		_apply(minf(delta * 12.0, 1.0))


## Acerca la pose actual a la del agarre (t = 1: de golpe).
func _apply(t: float) -> void:
	var fingers: Vector2 = _target[0]
	var thumb: Vector2 = _target[1]
	var turn: float = _target[2]
	for i in _fingers.size():
		var root := _fingers[i]
		var extra := float(i) * 4.0  # el meñique se cierra un poco más
		root.rotation.x = lerp_angle(root.rotation.x, deg_to_rad(fingers.x + extra), t)
		var tip := root.get_child(1) as Node3D
		tip.rotation.x = lerp_angle(tip.rotation.x, deg_to_rad(fingers.y), t)
	_thumb.rotation.y = lerp_angle(_thumb.rotation.y, deg_to_rad(-side * thumb.x), t)
	_thumb.rotation.x = lerp_angle(_thumb.rotation.x, deg_to_rad(thumb.y * 0.6), t)
	_thumb_tip.rotation.x = lerp_angle(_thumb_tip.rotation.x, deg_to_rad(thumb.y), t)
	rotation.y = lerp_angle(rotation.y, deg_to_rad(90.0 * side * turn), t)


## Caja de cubitos (la punta de abajo con otro color: uñas y yemas).
func _box(size: Vector3i, color: Color, tip_color: Color) -> Dictionary:
	var cells := {}
	for x in size.x:
		for y in size.y:
			for z in size.z:
				var col := tip_color if y == 0 else color
				cells[Vector3i(x, y, z)] = MicroVoxels.jitter(col, Vector3i(x, y, z), 0.04)
	return cells


func _node(cells: Dictionary, material: Material, layer: int, on_top: bool) -> MeshInstance3D:
	var c := CUBE * SkinModel.PIXEL
	var mi := MeshInstance3D.new()
	mi.mesh = VoxelBody._mesh(cells, Vector3.ZERO, Vector3.ONE * c)
	mi.material_override = material
	mi.layers = layer
	if on_top:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
