extends VoxelHand
class_name ModelHand
## La mano del propio modelo de Meshy (sus cubitos), troceada para que sea funcional: palma,
## pulgar y cuatro dedos de dos falanges (el modelo trae los dedos juntos: se separan en franjas
## de delante a atrás). Mismos agarres que VoxelHand.
##
## En el modelo la mano cuelga con la palma hacia el cuerpo (-X en la derecha) y los dedos en fila
## de delante (-Z) a atrás; doblar un dedo es girarlo en Z hacia la palma.

const PALM_END := 5      # cubitos de palma por debajo de la muñeca
const KNUCKLE := 2       # largo de la primera falange

var _d := 0.0            # metros por cubito
var _wrist := Vector3.ZERO


## cells: los cubitos de la mano (coordenadas del modelo); wrist: la muñeca (en cubitos).
func build_from(cells: Dictionary, wrist: Vector3, right: bool, d: float, material: Material, layer: int,
		on_top: bool) -> void:
	side = 1.0 if right else -1.0
	_d = d
	_wrist = wrist
	var palm := {}
	var thumb := {}
	var fingers := [{}, {}, {}, {}]
	var tips := [{}, {}, {}, {}]
	var zmin := 999
	var zmax := -999
	for p: Vector3i in cells:
		if p.y < wrist.y - PALM_END:
			zmin = mini(zmin, p.z)
			zmax = maxi(zmax, p.z)
	var finger_top := int(wrist.y) - PALM_END  # primera fila de dedos (por debajo)
	for p: Vector3i in cells:
		var inner := absf(p.x) <= absf(wrist.x) - 1.5  # del lado del cuerpo
		if (inner and p.z <= -2 and p.y >= finger_top) or (p.z <= zmin + 1 and p.y < finger_top and inner):
			thumb[p] = cells[p]
		elif p.y >= finger_top:
			palm[p] = cells[p]
		else:
			var f := clampi(int(float(p.z - zmin) / maxf(zmax - zmin + 1, 1) * 4.0), 0, 3)
			if p.y >= finger_top - KNUCKLE:
				fingers[f][p] = cells[p]
			else:
				tips[f][p] = cells[p]
	_piece(self, palm, wrist, material, layer, on_top)
	# Dedos: cada uno gira desde el nudillo (lado de la palma, arriba de la franja).
	for f in 4:
		var root := Node3D.new()
		var knuckle := Vector3(_mid_x(fingers[f], wrist.x), finger_top + 0.5, _mid_z(fingers[f], zmin + f * 3 + 1))
		root.position = (knuckle - wrist) * d
		add_child(root)
		_piece(root, fingers[f], knuckle, material, layer, on_top)
		var tip := Node3D.new()
		tip.name = "tip"
		var joint := knuckle - Vector3(0, KNUCKLE, 0)
		tip.position = Vector3(0, -KNUCKLE, 0) * d
		root.add_child(tip)
		_piece(tip, tips[f], joint, material, layer, on_top)
		_fingers.append(root)
	_thumb = Node3D.new()
	var thumb_root := Vector3(_mid_x(thumb, wrist.x), wrist.y - 1, _mid_z(thumb, -3))
	_thumb.position = (thumb_root - wrist) * d
	add_child(_thumb)
	_piece(_thumb, thumb, thumb_root, material, layer, on_top)
	_thumb_tip = Node3D.new()  # el pulgar va de una pieza
	_thumb.add_child(_thumb_tip)
	set_grip("relajada", true)


func _apply(t: float) -> void:
	var fingers: Vector2 = _target[0]
	var thumb: Vector2 = _target[1]
	var turn: float = _target[2]
	for i in _fingers.size():
		var root := _fingers[i]
		var extra := float(i) * 4.0
		root.rotation.z = lerp_angle(root.rotation.z, deg_to_rad(-side * (fingers.x + extra)), t)
		var tip := root.get_node("tip") as Node3D
		tip.rotation.z = lerp_angle(tip.rotation.z, deg_to_rad(-side * fingers.y), t)
	_thumb.rotation.z = lerp_angle(_thumb.rotation.z, deg_to_rad(-side * thumb.y * 0.5), t)
	_thumb.rotation.x = lerp_angle(_thumb.rotation.x, deg_to_rad(-thumb.x * 0.6), t)
	# Relajada: palma hacia el cuerpo (como en el modelo); al agarrar, palma hacia delante.
	rotation.y = lerp_angle(rotation.y, deg_to_rad(-90.0 * side * (1.0 - turn)), t)


func item_point(item_id: String) -> Vector3:
	if item_id in HANDLED:
		return position + Vector3(0, -(PALM_END + 1.5), -2.5) * _d
	return position + Vector3(0, -(PALM_END + 1.0), -4.5) * _d


func _mid_x(cells: Dictionary, fallback: float) -> float:
	if cells.is_empty():
		return fallback
	var s := 0.0
	for p: Vector3i in cells:
		s += p.x
	return s / cells.size() + 0.5


func _mid_z(cells: Dictionary, fallback: float) -> float:
	if cells.is_empty():
		return fallback
	var s := 0.0
	for p: Vector3i in cells:
		s += p.z
	return s / cells.size() + 0.5


func _piece(parent: Node3D, cells: Dictionary, origin: Vector3, material: Material, layer: int, on_top: bool) -> void:
	if cells.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = VoxelBody._mesh(cells, -origin * _d, Vector3.ONE * _d)
	mi.material_override = material
	mi.layers = layer
	if on_top:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
