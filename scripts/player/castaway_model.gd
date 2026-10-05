class_name CastawayModel
## El náufrago, modelado de cero con cubitos siguiendo su hoja de personaje (docs/concept/
## personaje_voxel.webp): proporciones humanas (cabeza pequeña, piernas largas), pelo rizado con
## volumen, barba, nariz, orejas, pies con dedos, manos de 5 dedos (VoxelHand) y ropa con volumen
## y bordes rotos (camisa con cuello en pico y mangas cortas, pantalón por debajo de la rodilla con
## agujeros, cinturón de cuerda).
##
## Devuelve las mismas piezas que SkinModel.make_part (cabeza, torso, brazos y piernas con su nodo
## "lower" en el codo o la rodilla, y la mano en "lower/hand"), así las animaciones no cambian.
##
## Unidades: cubitos de un tercio de píxel de skin (C); el personaje mide 96 (los pies en y = 0,
## mira hacia -Z y su derecha es +X).

const C := SkinModel.PIXEL / 3.0

## Ropa puesta (la pone Player.update_appearance): camisa, pantalón, cinturón y correas de mochila.
static var outfit := {"shirt": false, "pants": false, "belt": false, "straps": false}

# Colores de la hoja (paleta aproximada).
const SKIN := Color(0.80, 0.50, 0.31)
const SKIN_SHADE := Color(0.70, 0.42, 0.26)
const HAIR := [Color(0.30, 0.17, 0.10), Color(0.37, 0.21, 0.12), Color(0.23, 0.13, 0.08)]
const BEARD := Color(0.27, 0.16, 0.10)
const EYE := Color(0.06, 0.05, 0.05)
const SHIRT := Color(0.86, 0.78, 0.62)
const SHIRT_DIRT := Color(0.72, 0.60, 0.44)
const PANTS := Color(0.38, 0.34, 0.29)
const PANTS_DARK := Color(0.29, 0.26, 0.22)
const UNDERWEAR := Color(0.25, 0.18, 0.13)
const ROPE := Color(0.62, 0.48, 0.30)
const STRAP := Color(0.38, 0.26, 0.15)

## Articulaciones (en cubitos).
const NECK := Vector3(0, 77, 0)
const HIP := Vector3(0, 46, 0)
const SHOULDER_X := 14.0
const SHOULDER_Y := 71.0
const ELBOW_Y := 53.0
const WRIST_Y := 38.0
const LEG_X := 5.0
const KNEE_Y := 25.0


static func make_part(part: String, layer: int, on_top: bool) -> Node3D:
	if SmoothCharacter.available(Settings.body):  # el de Meshy, liso (hombre o mujer)
		return SmoothCharacter.make_part(Settings.body, part, layer, on_top)
	if ResourceLoader.exists(MeshyCastaway.DATA):
		return MeshyCastaway.make_part(part, layer, on_top)
	var material := SkinModel.make_voxel_material(on_top)
	var pivot := Node3D.new()
	pivot.name = part
	match part:
		"head":
			pivot.position = NECK * C
			_add(pivot, _head(), NECK, material, layer, on_top)
			pivot.add_child(_lids(material, layer))
		"body":
			pivot.position = HIP * C
			_add(pivot, _torso(), HIP, material, layer, on_top)
		"arm_right", "arm_left":
			var s := 1.0 if part == "arm_right" else -1.0
			var shoulder := Vector3(SHOULDER_X * s, SHOULDER_Y, 0)
			pivot.position = shoulder * C
			_add(pivot, _arm_upper(s), shoulder, material, layer, on_top)
			var elbow := Vector3(SHOULDER_X * s, ELBOW_Y, 0)
			var lower := Node3D.new()
			lower.name = "lower"
			lower.position = (elbow - shoulder) * C
			pivot.add_child(lower)
			_add(lower, _arm_lower(s), elbow, material, layer, on_top)
			var hand := VoxelHand.new()
			hand.name = "hand"
			hand.position = Vector3(0, WRIST_Y - ELBOW_Y, 0) * C
			lower.add_child(hand)
			hand.build(SKIN, s > 0.0, material, layer, on_top)
		"leg_right", "leg_left":
			var s := 1.0 if part == "leg_right" else -1.0
			var hip := Vector3(LEG_X * s, HIP.y, 0)
			pivot.position = hip * C
			_add(pivot, _leg_upper(s), hip, material, layer, on_top)
			var knee := Vector3(LEG_X * s, KNEE_Y, 0)
			var lower := Node3D.new()
			lower.name = "lower"
			lower.position = (knee - hip) * C
			pivot.add_child(lower)
			_add(lower, _leg_lower(s), knee, material, layer, on_top)
	return pivot


static func _add(parent: Node3D, cells: Dictionary, origin: Vector3, material: Material, layer: int, on_top: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = VoxelBody._mesh(cells, -origin * C, Vector3.ONE * C)
	mi.material_override = material
	mi.layers = layer
	if on_top:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ------------------------------------------------------------------ utilidades

static func _h(p: Vector3i, salt := 0) -> float:
	return MicroVoxels.hash01(p + Vector3i(salt * 31, salt * 17, salt * 7))


static func _put(cells: Dictionary, p: Vector3i, c: Color, amount := 0.05) -> void:
	cells[p] = MicroVoxels.jitter(c, p, amount)


## Sección redondeada (superelipse) de medio ancho w (x) y medio fondo d (z), centrada en (cx, cz).
static func _inside(x: float, z: float, cx: float, cz: float, w: float, d: float) -> bool:
	var a := absf(x + 0.5 - cx) / w
	var b := absf(z + 0.5 - cz) / d
	return a * a * a * a + b * b * b * b <= 1.0


## Columna redondeada de y0 a y1 con medidas que cambian con la altura (w(y), d(y) en Callables).
static func _column(cells: Dictionary, cx: float, cz: float, y0: int, y1: int, w: Callable, d: Callable,
		color: Callable) -> void:
	for y in range(y0, y1):
		var hw: float = w.call(y)
		var hd: float = d.call(y)
		for x in range(int(floor(cx - hw - 1)), int(ceil(cx + hw + 1))):
			for z in range(int(floor(cz - hd - 1)), int(ceil(cz + hd + 1))):
				if _inside(x, z, cx, cz, hw, hd):
					var p := Vector3i(x, y, z)
					cells[p] = color.call(p)


## Ropa: una capa de un cubito por fuera de la columna, donde wear(p) diga.
static func _cloth(cells: Dictionary, cx: float, cz: float, y0: int, y1: int, w: Callable, d: Callable,
		color: Callable, wear: Callable) -> void:
	for y in range(y0, y1):
		var hw: float = w.call(y) + 1.0
		var hd: float = d.call(y) + 1.0
		for x in range(int(floor(cx - hw - 1)), int(ceil(cx + hw + 1))):
			for z in range(int(floor(cz - hd - 1)), int(ceil(cz + hd + 1))):
				if not _inside(x, z, cx, cz, hw, hd):
					continue
				var p := Vector3i(x, y, z)
				if wear.call(p):
					cells[p] = color.call(p)


static func _skin(p: Vector3i) -> Color:
	return MicroVoxels.jitter(SKIN, p, 0.035)


static func _shirt(p: Vector3i) -> Color:
	var dirt := _h(Vector3i(p.x / 2, p.y / 2, p.z / 2), 3)
	return MicroVoxels.jitter(SHIRT_DIRT if dirt > 0.78 else SHIRT, p, 0.06)


static func _pants(p: Vector3i) -> Color:
	var dark := _h(Vector3i(p.x / 2, p.y / 3, p.z / 2), 5)
	return MicroVoxels.jitter(PANTS_DARK if dark > 0.6 else PANTS, p, 0.07)


# ------------------------------------------------------------------ cabeza

static func _head() -> Dictionary:
	var cells := {}
	# Cuello.
	_column(cells, 0, 0, 72, 80, func(_y: int) -> float: return 3.4, func(_y: int) -> float: return 3.2, _skin)
	# Cráneo redondeado: de 79 a 96, algo más estrecho en la barbilla.
	var head_w := func(y: int) -> float: return 5.6 if y < 82 else (6.6 if y < 85 else 7.0)
	var head_d := func(y: int) -> float: return 6.4 if y < 82 else 7.3
	_column(cells, 0, -0.5, 79, 96, head_w, head_d, _skin)
	for x in range(-8, 8):  # tapa de arriba algo redondeada (la cubre el pelo)
		for z in range(-8, 7):
			if _inside(x, z, 0, -0.5, 5.5, 6.0):
				cells[Vector3i(x, 96, z)] = SKIN
	var front := -8
	# Ojos (2x2 negros) y cejas oscuras que sobresalen.
	for ex: int in [-5, 3]:
		for dx in 2:
			for dy in 2:
				cells[Vector3i(ex + dx, 87 + dy, front)] = EYE
		for dx in range(-1, 3):
			_put(cells, Vector3i(ex + dx, 90, front - 1), BEARD, 0.06)
	# Nariz.
	for dx in range(-1, 1):
		for dy in range(84, 88):
			_put(cells, Vector3i(dx, dy, front - 1), SKIN_SHADE if dy == 84 else SKIN, 0.03)
	# Orejas.
	for sx: int in [-1, 1]:
		for dy in range(84, 89):
			for dz in range(-1, 2):
				_put(cells, Vector3i(sx * 7 + (0 if sx > 0 else -1), dy, dz), SKIN_SHADE, 0.04)
	# Barba: cubre la mandíbula y la barbilla (sobresale un poco), el bigote y las patillas.
	for p: Vector3i in cells.keys():
		if p.y < 79 or p.y > 85:
			continue
		var on_front := p.z <= front + 1
		var on_side := absf(p.x) >= 5 and p.z < 1
		# Por delante solo la barbilla y la mandíbula (las mejillas quedan libres); por los lados, patillas.
		var chin := p.y <= 81 or (p.y <= 83 and absi(p.x) >= 3)
		if (on_front and chin) or (on_side and p.y <= 86):
			if on_front and p.y == 83 and absi(p.x) <= 1:
				cells[p] = SKIN_SHADE.darkened(0.25)  # boca
			else:
				_put(cells, p, BEARD, 0.09)
	for x in range(-4, 4):  # barbilla y bigote con volumen
		for y in range(79, 82):
			if _h(Vector3i(x, y, 0), 2) < 0.85:
				_put(cells, Vector3i(x, y, front - 1), BEARD, 0.1)
		_put(cells, Vector3i(x, 84, front - 1), BEARD, 0.1)
	for x in range(-1, 2):
		cells[Vector3i(x, 82, front)] = SKIN_SHADE.darkened(0.3)  # boca
	_hair(cells)
	return cells


## Pelo rizado: una nube de cubitos alrededor de la cabeza con bultos (rizos en grupos de 2) y
## tres tonos de marrón; deja libre la cara, con flequillo hasta las cejas.
static func _hair(cells: Dictionary) -> void:
	var center := Vector3(0, 93.0, 1.0)
	for x in range(-15, 15):
		for y in range(81, 108):
			for z in range(-15, 16):
				var curl := Vector3i(floori(x / 2.0), floori(y / 2.0), floori(z / 2.0))
				var bump := _h(curl, 9) * 2.4
				var r := Vector3((x + 0.5 - center.x) / (12.0 + bump * 0.7), (y + 0.5 - center.y) / (11.0 + bump * 0.6),
					(z + 0.5 - center.z) / (12.5 + bump * 0.7))
				if r.length() > 1.0:
					continue
				# La cara queda libre: por delante, por debajo del flequillo (que acaba en rizos).
				var fringe := 90 + int(_h(Vector3i(x / 2, 0, 0), 4) * 2.5)
				if z < -4 and y < fringe and absi(x) < 7:
					continue
				# Por los lados deja ver orejas y patillas; por detrás baja hasta la nuca.
				if absi(x) >= 5 and y < 88 and z < 3:
					continue
				if y < 84 and z < 5:
					continue
				var p := Vector3i(x, y, z)
				if cells.has(p) and _inside(x, z, 0, -0.5, 6.5, 7.0) and y < 96:
					continue  # dentro de la cabeza
				var tone: Color = HAIR[int(_h(curl, 1) * 3.0) % 3]
				cells[p] = MicroVoxels.jitter(tone, p, 0.05)


## Párpados: cubren los ojos un instante al parpadear (los enseña PlayerAvatar).
static func _lids(material: Material, layer: int) -> Node3D:
	var lids := Node3D.new()
	lids.name = "lids"
	lids.visible = false
	var cells := {}
	for ex: int in [-5, 3]:
		for dx in 2:
			for dy in 2:
				cells[Vector3i(ex + dx, 87 + dy, -9)] = SKIN
	var mi := MeshInstance3D.new()
	mi.mesh = VoxelBody._mesh(cells, -NECK * C + Vector3(0, 0, 0.8 * C), Vector3.ONE * C)
	mi.material_override = material
	mi.layers = layer
	lids.add_child(mi)
	return lids


# ------------------------------------------------------------------ torso

static func _torso_w(y: int) -> float:
	if y < 54:
		return 8.6
	if y < 64:
		return 8.6 + (y - 54) * 0.25
	if y < 72:
		return 11.0
	return 11.0 - (y - 72) * 0.9  # hombros redondeados


static func _torso_d(y: int) -> float:
	return 5.0 if y < 58 else 5.6


static func _torso() -> Dictionary:
	var cells := {}
	var w := func(y: int) -> float: return _torso_w(y)
	var d := func(y: int) -> float: return _torso_d(y)
	_column(cells, 0, 0, 42, 76, w, d, func(p: Vector3i) -> Color:
		# Un poco de sombra en el pecho y en el centro del vientre.
		if (p.y == 66 and absi(p.x) > 1 and absi(p.x) < 8) or (p.x == 0 and p.y > 50 and p.y < 64):
			return MicroVoxels.jitter(SKIN_SHADE, p, 0.03)
		return _skin(p))
	# Calzoncillos (si no lleva pantalón).
	if not outfit["pants"]:
		_cloth(cells, 0, 0, 42, 47, w, d, func(p: Vector3i) -> Color: return MicroVoxels.jitter(UNDERWEAR, p, 0.05),
			func(_p: Vector3i) -> bool: return true)
	else:
		_cloth(cells, 0, 0, 40, 48, w, d, _pants, func(_p: Vector3i) -> bool: return true)
	if outfit["shirt"]:
		_cloth(cells, 0, 0, 41, 77, w, d, _shirt, func(p: Vector3i) -> bool:
			# Bajo roto, cuello en pico por delante.
			if p.y < 42 + int(_h(Vector3i(p.x, 0, p.z), 6) * 3.0):
				return false
			if p.z < 0 and p.y > 63 and absi(p.x) < (p.y - 63) * 0.55 + 0.5:
				return false
			return true)
	if outfit["belt"]:
		_cloth(cells, 0, 0, 46, 48, w, d, func(p: Vector3i) -> Color:
			return MicroVoxels.jitter(ROPE if (p.x + p.y) % 3 != 0 else ROPE.darkened(0.25), p, 0.05),
			func(_p: Vector3i) -> bool: return true)
		for y in range(43, 49):  # nudo y bolsita
			for x in range(-7, -3):
				_put(cells, Vector3i(x, y, -8), Color(0.55, 0.45, 0.32), 0.06)
	if outfit["straps"]:
		for sx: int in [-5, 4]:
			for y in range(52, 76):
				for x in range(sx, sx + 2):
					_put(cells, Vector3i(x, y, -8), STRAP, 0.05)
					_put(cells, Vector3i(x, y, 7), STRAP, 0.05)
	return cells


# ------------------------------------------------------------------ brazos

static func _arm_upper(s: float) -> Dictionary:
	var cells := {}
	var cx := SHOULDER_X * s
	var w := func(y: int) -> float: return 3.2 if y > 60 else 2.9
	_column(cells, cx, 0, int(ELBOW_Y) - 2, 76, w, w, _skin)
	if outfit["shirt"]:  # manga corta rota
		_cloth(cells, cx, 0, 60, 77, w, w, _shirt, func(p: Vector3i) -> bool:
			return p.y >= 61 + int(_h(Vector3i(p.x, 1, p.z), 8) * 3.0))
	return cells


static func _arm_lower(s: float) -> Dictionary:
	var cells := {}
	var cx := SHOULDER_X * s
	var w := func(y: int) -> float: return 2.8 if y > 46 else 2.5
	_column(cells, cx, 0, int(WRIST_Y), int(ELBOW_Y) + 3, w, w, _skin)
	return cells


# ------------------------------------------------------------------ piernas

static func _leg_upper(s: float) -> Dictionary:
	var cells := {}
	var cx := LEG_X * s
	var w := func(y: int) -> float: return 3.6 + clampf((y - KNEE_Y) / 20.0, 0.0, 1.0) * 1.0
	_column(cells, cx, 0, int(KNEE_Y) - 2, 49, w, w, _skin)
	if outfit["pants"]:
		_cloth(cells, cx, 0, int(KNEE_Y) - 2, 49, w, w, _pants, func(p: Vector3i) -> bool:
			return _h(Vector3i(p.x / 2, p.y / 2, p.z / 2), 11) < 0.93)  # algún agujero
	else:
		_cloth(cells, cx, 0, 41, 47, w, w, func(p: Vector3i) -> Color: return MicroVoxels.jitter(UNDERWEAR, p, 0.05),
			func(_p: Vector3i) -> bool: return true)
	return cells


static func _leg_lower(s: float) -> Dictionary:
	var cells := {}
	var cx := LEG_X * s
	# Espinilla con gemelo (más ancha por detrás a media altura) y tobillo fino.
	var w := func(y: int) -> float: return 3.0 if y > 12 else 2.6
	var d := func(y: int) -> float: return 3.4 if y > 12 and y < 22 else 2.8
	_column(cells, cx, 0.4, 4, int(KNEE_Y) + 3, w, d, _skin)
	if outfit["pants"]:  # el pantalón acaba por debajo de la rodilla, deshilachado
		_cloth(cells, cx, 0.4, 14, int(KNEE_Y) + 3, w, d, _pants, func(p: Vector3i) -> bool:
			return p.y >= 15 + int(_h(Vector3i(p.x, 2, p.z), 12) * 5.0))
	# Pie: más largo hacia delante, más bajo en la punta, con cuatro dedos marcados.
	for x in range(int(cx) - 4, int(cx) + 4):
		for z in range(-10, 5):
			var top := 5 if z > -3 else 5 - int((-3 - z) * 0.45)
			for y in range(0, maxi(top, 2)):
				var p := Vector3i(x, y, z)
				if z == -10 and (x - int(cx) + 4) % 2 == 1:
					continue  # separación entre dedos
				var c := SKIN_SHADE if y == 0 or z == -10 else SKIN
				cells[p] = MicroVoxels.jitter(c, p, 0.04)
	return cells
