class_name MeshyCastaway
## El náufrago hecho con Meshy (assets/models/character/naufrago_tex.glb), ya pasado a cubitos con
## sus colores (tools/voxelize_character.gd -> naufrago_cubitos.res) y troceado por las
## articulaciones para que se anime como siempre: cabeza, torso, brazos (con antebrazo) y piernas
## (con espinilla). Las manos del modelo se cambian por manos de 5 dedos (VoxelHand) y la ropa
## (CastawayModel.outfit) es una capa de un cubito por encima de su cuerpo.
##
## Coordenadas en cubitos del modelo: 113 de alto, pies en y = 0, mira hacia -Z, derecha = +X.

const DATA := "res://assets/models/character/naufrago_cubitos.res"
const HEIGHT := 113.0
const D := SkinModel.BODY_HEIGHT / HEIGHT   # metros por cubito

## Articulaciones medidas sobre los cubitos del modelo.
const NECK := 83
const SHOULDER := Vector2(19, 68)   # x (a cada lado), y
const ELBOW_Y := 56
const WRIST_Y := 45
const HIP_Y := 44
const LEG_X := 7.5
const KNEE_Y := 22
const ARM_X := 15.5                 # más allá de esto (en |x|), por debajo de los hombros, es brazo

static var _parts := {}             # nombre de trozo -> {Vector3i: Color}, ya repartido


static func make_part(part: String, layer: int, on_top: bool) -> Node3D:
	if _parts.is_empty():
		_split()
	var material := SkinModel.make_voxel_material(on_top)
	var pivot := Node3D.new()
	pivot.name = part
	match part:
		"head":
			pivot.position = Vector3(0, NECK, 0) * D
			_add(pivot, _parts["head"], Vector3(0, NECK, 0), material, layer, on_top)
			var lids := Node3D.new()  # el modelo no parpadea (sus ojos están pintados)
			lids.name = "lids"
			lids.visible = false
			pivot.add_child(lids)
		"body":
			pivot.position = Vector3(0, HIP_Y, 0) * D
			_add(pivot, _dress(_parts["body"], "body"), Vector3(0, HIP_Y, 0), material, layer, on_top)
		"arm_right", "arm_left":
			var s := 1.0 if part == "arm_right" else -1.0
			var shoulder := Vector3(SHOULDER.x * s, SHOULDER.y, 0)
			pivot.position = shoulder * D
			_add(pivot, _dress(_parts[part + "_upper"], "arm"), shoulder, material, layer, on_top)
			var elbow := Vector3(_center_x(_parts[part + "_lower"], s), ELBOW_Y, 0)
			var lower := Node3D.new()
			lower.name = "lower"
			lower.position = (elbow - shoulder) * D
			pivot.add_child(lower)
			_add(lower, _parts[part + "_lower"], elbow, material, layer, on_top)
			var hand_cells: Dictionary = _parts[part + "_hand"]
			var wrist := Vector3(_center_x(hand_cells, s, WRIST_Y - 2), WRIST_Y - 1, 0)
			var hand := ModelHand.new()
			hand.name = "hand"
			hand.position = (wrist - elbow) * D
			lower.add_child(hand)
			hand.build_from(hand_cells, wrist, s > 0.0, D, material, layer, on_top)
		"leg_right", "leg_left":
			var s := 1.0 if part == "leg_right" else -1.0
			var hip := Vector3(LEG_X * s, HIP_Y, 0)
			pivot.position = hip * D
			_add(pivot, _dress(_parts[part + "_upper"], "leg"), hip, material, layer, on_top)
			var knee := Vector3(LEG_X * s, KNEE_Y, 0)
			var lower := Node3D.new()
			lower.name = "lower"
			lower.position = (knee - hip) * D
			pivot.add_child(lower)
			_add(lower, _dress(_parts[part + "_lower"], "shin"), knee, material, layer, on_top)
	return pivot


## Reparte los cubitos del modelo en trozos (girado para mirar a -Z y centrado).
static func _split() -> void:
	var data: VoxelModelData = load(DATA)
	for name: String in ["head", "body", "arm_right_upper", "arm_right_lower", "arm_left_upper",
			"arm_left_lower", "arm_right_hand", "arm_left_hand", "leg_right_upper", "leg_right_lower", "leg_left_upper", "leg_left_lower"]:
		_parts[name] = {}
	for c: Vector3i in data.cells:
		var p := Vector3i(-c.x - 1, c.y, -c.z)  # el modelo miraba a +Z
		var col: Color = data.cells[c]
		var name := "body"
		if p.y >= NECK:
			name = "head"
		elif p.y < SHOULDER.y + 4 and absi(p.x) > ARM_X and p.y >= WRIST_Y:
			name = ("arm_right" if p.x > 0 else "arm_left") + ("_upper" if p.y >= ELBOW_Y else "_lower")
		elif p.y < WRIST_Y and absi(p.x) > ARM_X:
			name = "arm_right_hand" if p.x > 0 else "arm_left_hand"  # su mano (ModelHand la articula)
		elif p.y < HIP_Y:
			name = ("leg_right" if p.x > 0 else "leg_left") + ("_upper" if p.y >= KNEE_Y else "_lower")
		(_parts[name] as Dictionary)[p] = col
	for name: String in _parts:
		if not name.ends_with("_hand"):  # la mano no se rellena: sus dedos se separan
			_fill(_parts[name])
	# Juntas: el segmento de abajo sube un poco dentro del de arriba (sin rajas al doblar).
	for limb: String in ["arm_right", "arm_left", "leg_right", "leg_left"]:
		var upper: Dictionary = _parts[limb + "_upper"]
		var lower: Dictionary = _parts[limb + "_lower"]
		var joint := ELBOW_Y if limb.begins_with("arm") else KNEE_Y
		for p: Vector3i in upper.keys():
			if p.y < joint + 3:
				lower[p] = upper[p]


## Rellena por dentro cada fila (para que al doblar no se vea el interior hueco).
static func _fill(cells: Dictionary) -> void:
	var rows := {}
	for p: Vector3i in cells:
		var key := Vector2i(p.y, p.z)
		var r: Vector2i = rows.get(key, Vector2i(p.x, p.x))
		rows[key] = Vector2i(mini(r.x, p.x), maxi(r.y, p.x))
	for key: Vector2i in rows:
		var r: Vector2i = rows[key]
		for x in range(r.x + 1, r.y):
			var p := Vector3i(x, key.x, key.y)
			if not cells.has(p):
				cells[p] = _skin().darkened(0.2)


static func _center_x(cells: Dictionary, s: float, at_y := ELBOW_Y) -> float:
	var sum := 0.0
	var n := 0
	for p: Vector3i in cells:
		if p.y > at_y - 3 and p.y < at_y + 3:
			sum += p.x
			n += 1
	return sum / n if n > 0 else SHOULDER.x * s


static var _skin_cache := Color(-1, 0, 0)


## Color de la piel: el del pecho del modelo.
static func _skin() -> Color:
	if _skin_cache.r >= 0.0:
		return _skin_cache
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for p: Vector3i in _parts.get("body", {}):
		if p.y > 60 and p.y < 70 and absi(p.x) < 6 and p.z < -6:
			sum += _parts["body"][p]
			n += 1
	_skin_cache = (sum / n) if n > 0 else CastawayModel.SKIN
	_skin_cache.a = 1.0
	return _skin_cache


## Ropa encima del cuerpo: un cubito por fuera en las zonas que cubre cada prenda puesta.
static func _dress(cells: Dictionary, kind: String) -> Dictionary:
	var o: Dictionary = CastawayModel.outfit
	var out := cells.duplicate()
	var add := func(p: Vector3i, c: Color) -> void:
		for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var q := p + d
			if not cells.has(q):
				out[q] = c
	for p: Vector3i in cells:
		var hem := int(MicroVoxels.hash01(Vector3i(p.x, 0, p.z)) * 3.0)
		match kind:
			"body":
				var v_neck := p.z < 0 and p.y > 72 and absi(p.x) < (p.y - 72) * 0.55 + 0.5
				if o["shirt"] and p.y >= 41 + hem and p.y < NECK - 1 and not v_neck:
					add.call(p, CastawayModel._shirt(p))
				elif o["pants"] and p.y < 50:
					add.call(p, CastawayModel._pants(p))
				if o["belt"] and p.y >= 47 and p.y < 50:
					add.call(p, CastawayModel.ROPE.darkened(0.25 if (p.x + p.y) % 3 == 0 else 0.0))
			"arm":
				if o["shirt"] and p.y >= 61 + hem:
					add.call(p, CastawayModel._shirt(p))
			"leg":
				if o["pants"] and MicroVoxels.hash01(Vector3i(p.x / 2, p.y / 2, p.z / 2)) < 0.93:
					add.call(p, CastawayModel._pants(p))
			"shin":
				if o["pants"] and p.y >= 14 + int(MicroVoxels.hash01(Vector3i(p.x, 2, p.z)) * 5.0):
					add.call(p, CastawayModel._pants(p))
	return out


static func _add(parent: Node3D, cells: Dictionary, origin: Vector3, material: Material, layer: int, on_top: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = VoxelBody._mesh(cells, -origin * D, Vector3.ONE * D)
	mi.material_override = material
	mi.layers = layer
	if on_top:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
