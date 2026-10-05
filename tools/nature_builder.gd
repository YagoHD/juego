extends TreeBuilder
class_name NatureBuilder
## Lo de la hoja 4 del arte conceptual (docs/concept/hoja4_palmeras_rocas.png), en cubitos como los
## árboles (TreeBuilder): palmeras (alta, curvada y baja), el tocón grande con raíces y musgo, las
## tres rocas con musgo, los grupos de setas (rojas y marrones) y el trigo (verde y maduro).
## Lo usa tools/bake_prefabs.gd, que luego los trocea en bloques.

const FROND := [Color(0.20, 0.45, 0.09), Color(0.33, 0.62, 0.12), Color(0.52, 0.78, 0.18)]
const PALM_BARK := [Color(0.36, 0.22, 0.10), Color(0.52, 0.33, 0.15), Color(0.66, 0.45, 0.22)]
const COCONUT := [Color(0.34, 0.20, 0.09), Color(0.48, 0.30, 0.14)]
const STONE := [Color(0.36, 0.39, 0.42), Color(0.48, 0.51, 0.54), Color(0.60, 0.63, 0.65)]
const MOSS := [Color(0.27, 0.48, 0.10), Color(0.40, 0.62, 0.14), Color(0.55, 0.75, 0.20)]


func _init(seed_value: int) -> void:
	super(seed_value)


# ------------------------------------------------------------------ palmeras

## Tronco de palmera: fino, con anillos (los segmentos que se ven en el concepto) y que se curva
## hasta 'bend' arriba. Devuelve la punta.
func palm_trunk(height: int, r0: float, r1: float, bend: Vector3) -> Vector3:
	var top := _center
	for y in height:
		var t := float(y) / height
		var c := _center + bend * t * t
		var r := lerpf(r0, r1, sqrt(t))
		var ring := (y / 4) % 2 == 0
		for x in range(int(c.x - r) - 1, int(c.x + r) + 2):
			for z in range(int(c.z - r) - 1, int(c.z + r) + 2):
				var d := Vector2(x + 0.5 - c.x, z + 0.5 - c.z)
				if d.length() <= r:
					var col: Color = PALM_BARK[1] if ring else PALM_BARK[2]
					if y % 4 == 3:
						col = PALM_BARK[0]  # la junta entre segmentos
					_put(Vector3i(x, y, z), col, "wood")
		top = Vector3(c.x, y, c.z)
	return top


## Hoja de palmera: un nervio que sale de 'from' hacia 'angle', sube un poco y cae, con hojitas a
## los dos lados en dientes de sierra (como en el concepto).
func frond(from: Vector3, angle: float, length: float, lift: float, droop: float, width: float) -> void:
	var dir := Vector3(cos(angle), 0, sin(angle))
	var side := Vector3(-dir.z, 0, dir.x)
	var steps := int(length)
	for s in steps:
		var t := float(s) / steps
		var p := from + dir * s + Vector3(0, lift * sin(t * PI * 0.7) - droop * t * t, 0)
		_put(Vector3i(p.floor()), FROND[0], "leaf", false)  # nervio
		var w := width * sin(minf(t * 1.6, 1.0) * PI * 0.5) * (1.0 - t * 0.75)
		if s % 3 == 2:
			w *= 0.75  # muesca entre hojitas
		for k in range(1, int(w) + 1):
			var fall := float(k) * 0.35  # las hojitas cuelgan hacia fuera
			var tone: Color = FROND[2] if k <= 1 else (FROND[1] if k < w * 0.75 else FROND[0])
			for sgn in [-1.0, 1.0]:
				var q := Vector3i((p + side * k * sgn + Vector3(0, -fall, 0)).floor())
				_put(q, tone, "leaf", false)
				_put(q + Vector3i.DOWN, tone.darkened(0.15), "leaf", false)  # hojitas gruesas, como en el concepto


func coconuts(at: Vector3, count: int) -> void:
	for k in count:
		var a := TAU * k / count + rng.randf_range(-0.3, 0.3)
		var c := at + Vector3(cos(a) * 4.2, -2.0 - rng.randf() * 1.5, sin(a) * 4.2)
		_ball(c, 2.0, func(q: Vector3i, d: Vector3) -> void: _put(q, COCONUT[0] if d.y < 0 else COCONUT[1], "leaf"))


func crown(top: Vector3, count: int, length: float, lift: float, droop: float) -> void:
	var a0 := rng.randf() * TAU
	for k in count:
		var a := a0 + TAU * k / count + rng.randf_range(-0.2, 0.2)
		var l := length * rng.randf_range(0.85, 1.1)
		frond(top + Vector3(0, 1, 0), a, l, lift * rng.randf_range(0.8, 1.2), droop * rng.randf_range(0.8, 1.2), 8.5)
	# Hojas que salen hacia arriba en el centro.
	for k in 3:
		var a := a0 + TAU * k / 3.0 + 0.5
		frond(top + Vector3(0, 2, 0), a, length * 0.45, lift * 1.6, 0.0, 4.0)
	_ball(top + Vector3(0, 1, 0), 3.0, func(q: Vector3i, _d: Vector3) -> void: _put(q, FROND[0], "leaf", false))
	coconuts(top, 4)


static func palm_tall(seed_value: int) -> NatureBuilder:
	var b := NatureBuilder.new(seed_value)
	var top := b.palm_trunk(b.rng.randi_range(84, 96), 4.8, 3.2, Vector3(b.rng.randf_range(-3, 3), 0, b.rng.randf_range(-3, 3)))
	b.roots(6, 7, 2.2, 4.0, PALM_BARK)
	b.crown(top, 9, 36, 6, 20)
	return b


static func palm_bend(seed_value: int) -> NatureBuilder:
	var b := NatureBuilder.new(seed_value)
	var a := b.rng.randf() * TAU
	var top := b.palm_trunk(70, 5.0, 3.2, Vector3(cos(a), 0, sin(a)) * 30.0)
	b.roots(5, 8, 2.4, 4.6, PALM_BARK)
	b.crown(top, 9, 34, 6, 18)
	return b


static func palm_short(seed_value: int) -> NatureBuilder:
	var b := NatureBuilder.new(seed_value)
	var top := b.palm_trunk(30, 5.0, 3.6, Vector3.ZERO)
	b.roots(6, 8, 2.6, 5.0, PALM_BARK)
	b.crown(top, 11, 28, 10, 16)
	return b


# ------------------------------------------------------------------ tocón

## Tocón grande: corteza en surcos, anillos arriba, raíces largas y musgo con brotes.
static func big_stump(seed_value: int) -> NatureBuilder:
	var b := NatureBuilder.new(seed_value)
	var h := 20
	for y in h:
		var r := 9.0 - y * 0.12 + (2.5 if y < 4 else 0.0) * (1.0 - y / 4.0)
		for x in range(-12, 13):
			for z in range(-12, 13):
				var d := Vector2(x + 0.5, z + 0.5)
				if d.length() > r:
					continue
				var p := Vector3i(int(b._center.x) + x, y, int(b._center.z) + z)
				var col := b._bark(BARK, d.angle(), y)
				if y == h - 1:
					col = Color(0.84, 0.66, 0.40) if int(d.length() * 0.9) % 2 == 0 else Color(0.72, 0.52, 0.28)
					if d.length() > r - 1.2:
						col = BARK[0]
				elif (y < 8 and b.rng.randf() < 0.18 * (1.0 - y / 8.0)) or (x + y * 3) % 13 == 0 and y < 12 and b.rng.randf() < 0.4:
					col = MOSS[b.rng.randi_range(0, 2)]
				b._put(p, col, "wood")
	b.roots(7, 18, 3.6, 9.0, BARK)
	b._moss_tops(0.35)
	for k in 2:  # brotes verdes junto al tocón
		var a := b.rng.randf() * TAU
		var at := b._center + Vector3(cos(a) * 16, 0, sin(a) * 16)
		for y in 4:
			b._put(Vector3i(at.floor()) + Vector3i(0, y, 0), MOSS[1], "leaf")
		b._put(Vector3i(at.floor()) + Vector3i(1, 3, 0), MOSS[2], "leaf")
		b._put(Vector3i(at.floor()) + Vector3i(-1, 2, 0), MOSS[2], "leaf")
	return b


## Musgo por encima: las caras de arriba de la madera y la piedra, a manchas.
func _moss_tops(chance: float) -> void:
	for p: Vector3i in cells.keys():
		if types[p] == "leaf" or cells.has(p + Vector3i.UP):
			continue
		var n := sin(p.x * 0.9) + sin(p.z * 0.7 + p.y * 0.3) + rng.randf() * 0.8
		if n > 2.0 - chance * 4.0:
			cells[p] = MOSS[rng.randi_range(0, 2)]


# ------------------------------------------------------------------ rocas

## Roca de bloques: cajas de piedra apiladas (cada una de un tono, con bordes más oscuros) y musgo
## por arriba que cae un poco por los lados.
func stone_box(at: Vector3i, size: Vector3i) -> void:
	var tone: Color = STONE[rng.randi_range(0, 2)].lerp(STONE[1], 0.4)
	for x in size.x:
		for y in size.y:
			for z in size.z:
				var edge := int(x == 0 or x == size.x - 1) + int(y == 0 or y == size.y - 1) + int(z == 0 or z == size.z - 1)
				var col := tone.darkened(0.14) if edge >= 2 else tone
				if (x * 5 + y * 3 + z * 7) % 17 == 0:
					col = col.lightened(0.08)
				_put(at + Vector3i(x, y, z), col, "rock")


func _rock_moss(chance: float) -> void:
	_moss_tops(chance)
	for p: Vector3i in cells.keys():  # el musgo cae un poco por los lados
		if cells[p] in MOSS:
			for k in rng.randi_range(0, 3):
				var q := p + Vector3i(0, -1 - k, 0)
				if cells.has(q):
					var side := not cells.has(q + Vector3i.LEFT) or not cells.has(q + Vector3i.RIGHT) or not cells.has(q + Vector3i.FORWARD) or not cells.has(q + Vector3i.BACK)
					if side:
						cells[q] = MOSS[0]


## Peñasco redondeado (6).
static func boulder(seed_value: int) -> NatureBuilder:
	var b := NatureBuilder.new(seed_value)
	var c := Vector3i(int(b._center.x), 0, int(b._center.z))
	for k in 16:
		var a := b.rng.randf() * TAU
		var r := b.rng.randf_range(0, 9)
		var size := Vector3i(b.rng.randi_range(8, 13), b.rng.randi_range(7, 12), b.rng.randi_range(8, 13))
		var y := int(maxf(0, 16 - r * 1.4 - size.y * 0.5 + b.rng.randf_range(-3, 3)))
		b.stone_box(c + Vector3i(int(cos(a) * r) - size.x / 2, y, int(sin(a) * r) - size.z / 2), size)
	b._rock_moss(0.3)
	return b


## Roca alta en columna (7).
static func pillar(seed_value: int) -> NatureBuilder:
	var b := NatureBuilder.new(seed_value)
	var c := Vector3i(int(b._center.x), 0, int(b._center.z))
	var y := 0
	while y < 44:
		var w := int(lerpf(16, 7, y / 44.0))
		for k in 3:
			var size := Vector3i(b.rng.randi_range(w - 3, w), b.rng.randi_range(7, 11), b.rng.randi_range(w - 3, w))
			var off := Vector3i(b.rng.randi_range(-3, 3), 0, b.rng.randi_range(-3, 3))
			b.stone_box(c + off + Vector3i(-size.x / 2, y, -size.z / 2), size)
		y += 8
	b._rock_moss(0.25)
	return b


## Montón de rocas con mucho musgo (8).
static func rock_pile(seed_value: int) -> NatureBuilder:
	var b := NatureBuilder.new(seed_value)
	var c := Vector3i(int(b._center.x), 0, int(b._center.z))
	b.stone_box(c + Vector3i(-8, 0, -6), Vector3i(14, 18, 12))
	b.stone_box(c + Vector3i(-12, 0, 2), Vector3i(10, 11, 9))
	b.stone_box(c + Vector3i(3, 0, -2), Vector3i(11, 13, 11))
	b.stone_box(c + Vector3i(9, 0, 6), Vector3i(6, 5, 6))
	b.stone_box(c + Vector3i(14, 0, 1), Vector3i(4, 4, 4))
	b.stone_box(c + Vector3i(-4, 0, 9), Vector3i(5, 4, 5))
	b._rock_moss(0.55)
	return b


# ------------------------------------------------------------------ setas y trigo

## Una seta: pie claro y sombrero de cúpula.
func mushroom(at: Vector3, stem_h: int, cap_r: float, cap: Color, dots: bool) -> void:
	for y in stem_h:
		for x in range(-1, 1):
			for z in range(-1, 1):
				_put(Vector3i(at.floor()) + Vector3i(x, y, z), Color(0.90, 0.84, 0.72) if y > 0 else Color(0.78, 0.70, 0.56), "mushroom")
	var top := at + Vector3(0, stem_h, 0)
	var r := int(ceilf(cap_r))
	for x in range(-r, r + 1):
		for z in range(-r, r + 1):
			for y in range(0, r):
				var d := Vector3(x, y * 1.5, z)
				if d.length() > cap_r:
					continue
				var col := cap.darkened(0.12) if y == 0 else cap
				if not dots and y >= r - 2:
					col = cap.lightened(0.12)
				if dots and (x * 3 + z * 5 + y * 7) % 11 == 0 and y > 0:
					col = Color(0.97, 0.95, 0.90)
				_put(Vector3i(top.floor()) + Vector3i(x, y, z), col, "mushroom", false)


static func mushrooms(seed_value: int, red: bool) -> NatureBuilder:
	var b := NatureBuilder.new(seed_value)
	var cap := Color(0.80, 0.12, 0.10) if red else Color(0.52, 0.33, 0.18)
	var spots := [[Vector2(0, 0), 7, 4.4], [Vector2(-4, 3), 4, 3.2], [Vector2(4, 2), 5, 3.2], [Vector2(2, -4), 3, 2.6], [Vector2(-3, -3), 2, 2.2]]
	for s in spots:
		var p: Vector2 = s[0]
		b.mushroom(b._center + Vector3(p.x, 0, p.y), s[1], s[2], cap, red)
	return b


## Trigo en un solo bloque (los cultivos se cambian de uno en uno): tallos con espigas. Verde
## (recién crecido) o dorado (maduro).
static func wheat(seed_value: int, ripe: bool) -> NatureBuilder:
	var b := NatureBuilder.new(seed_value)
	var stalk := Color(0.62, 0.62, 0.20) if ripe else Color(0.33, 0.58, 0.14)
	var ear := Color(0.92, 0.74, 0.22) if ripe else Color(0.50, 0.74, 0.20)
	var spots := [Vector2i(1, 1), Vector2i(5, 2), Vector2i(3, 4), Vector2i(1, 6), Vector2i(6, 6), Vector2i(4, 1)]
	for s in spots:
		var h := b.rng.randi_range(4, 7) if ripe else b.rng.randi_range(3, 7)
		for y in h:
			b._put(Vector3i(s.x, y, s.y), stalk, "crop")
		if ripe:
			for y in range(h - 2, mini(h + 1, 8)):
				b._put(Vector3i(s.x, y, s.y), ear, "crop")
				b._put(Vector3i(mini(s.x + 1, 7), y, s.y), ear.darkened(0.1), "crop")
		# una hoja al lado
		b._put(Vector3i(clampi(s.x - 1, 0, 7), 1, s.y), stalk.lightened(0.1), "crop")
	return b
