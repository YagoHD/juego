extends RefCounted
class_name TreeBuilder
## Construye árboles de cubitos como los de la hoja de árboles del arte conceptual
## (docs/concept/hoja3_arboles.png): tronco que se ensancha abajo con raíces abiertas, corteza
## con surcos, ramas, y copas redondas hechas de racimos de hojas con la cara de arriba al sol.
## Cada cubito mide 1/RES de bloque. Lo usa tools/bake_prefabs.gd, que luego los trocea.
## El pie del tronco está en el centro del bloque (0, 0, 0): cubitos (RES/2, 0, RES/2).

const RES := 8
const LEAF := [Color(0.16, 0.40, 0.12), Color(0.30, 0.58, 0.14), Color(0.50, 0.74, 0.18)]
const PINE := [Color(0.07, 0.27, 0.15), Color(0.13, 0.40, 0.19), Color(0.26, 0.54, 0.22)]
const BARK := [Color(0.30, 0.18, 0.09), Color(0.50, 0.31, 0.15), Color(0.64, 0.42, 0.22)]
const DEAD := [Color(0.38, 0.34, 0.38), Color(0.56, 0.52, 0.56), Color(0.72, 0.69, 0.72)]
const BERRY := Color(0.78, 0.12, 0.10)

var cells := {}   # Vector3i -> Color
var types := {}   # Vector3i -> "leaf" / "wood" / "root"
var rng := RandomNumberGenerator.new()
var _center := Vector3(RES * 0.5, 0.0, RES * 0.5)


func _init(seed_value: int) -> void:
	rng.seed = seed_value


func _put(p: Vector3i, col: Color, type: String, over_leaves := true) -> void:
	if p.y < 0:
		return
	if cells.has(p) and (types[p] != "leaf" or not over_leaves):
		return  # la madera manda sobre las hojas
	cells[p] = col
	types[p] = type


## Corteza: surcos oscuros alrededor del tronco, con vetas claras.
func _bark(tones: Array, angle: float, y: float) -> Color:
	var groove := int(floorf((angle + PI) / TAU * 11.0 + y * 0.04)) % 3
	if groove == 0:
		return tones[0]
	if int(y * 0.5 + angle * 3.0) % 7 == 0:
		return tones[2]
	return tones[1]


## Tronco de 'height' cubitos que se estrecha de r0 a r1 y se curva hasta 'bend' arriba.
func trunk(height: int, r0: float, r1: float, bend: Vector3, tones: Array) -> Vector3:
	var top := _center
	for y in height:
		var t := float(y) / height
		var c := _center + bend * t * t
		var r := lerpf(r0, r1, t)
		for x in range(int(c.x - r) - 1, int(c.x + r) + 2):
			for z in range(int(c.z - r) - 1, int(c.z + r) + 2):
				var d := Vector2(x + 0.5 - c.x, z + 0.5 - c.z)
				if d.length() <= r:
					_put(Vector3i(x, y, z), _bark(tones, d.angle(), y), "wood")
		top = Vector3(c.x, y, c.z)
	return top


## Raíces que salen del pie hacia fuera y se hunden en el suelo.
func roots(count: int, length: float, radius: float, trunk_r: float, tones: Array) -> void:
	for k in count:
		var a := TAU * k / count + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0, sin(a))
		var steps := int(length)
		for s in steps:
			var t := float(s) / steps
			var r := lerpf(radius, 1.0, t)
			var p := _center + dir * (trunk_r * 0.6 + s) + Vector3(0, (1.0 - t) * radius * 1.4, 0)
			_ball(p, r, func(q: Vector3i, d: Vector3) -> void: _put(q, _bark(tones, atan2(d.z, d.x), q.y).darkened(0.05), "root"))


## Rama de 'from' a 'to' que adelgaza de r0 a r1.
func branch(from: Vector3, to: Vector3, r0: float, r1: float, tones: Array) -> void:
	var steps := int(from.distance_to(to)) + 1
	for s in steps + 1:
		var t := float(s) / steps
		var p := from.lerp(to, t)
		_ball(p, lerpf(r0, r1, t), func(q: Vector3i, d: Vector3) -> void: _put(q, _bark(tones, atan2(d.z, d.x), q.y), "wood"))


## Racimo de hojas (una bola de un tono).
func clump(center: Vector3, radius: float, tone: Color) -> void:
	_ball(center, radius, func(q: Vector3i, _d: Vector3) -> void: _put(q, tone, "leaf", false))


## Copa: un núcleo y muchos racimos repartidos por un elipsoide (bordes con bultos, como en el
## concepto). 'size' son los radios en X, Y, Z.
func canopy(center: Vector3, size: Vector3, count: int, tones: Array) -> void:
	_ellipsoid(center, size * 0.72, tones[1])
	for k in count * 3 / 2:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 1), rng.randf_range(-1, 1)).normalized()
		var p := center + dir * size * rng.randf_range(0.55, 0.85)
		var r := rng.randf_range(0.22, 0.34) * minf(size.x, size.y)
		clump(p, r, tones[rng.randi_range(0, 2)])


## Pino: conos de ramas con borde en estrella, uno encima de otro.
func pine_cone(base_y: float, height: float, radius: float, tones: Array, tiers: int, gap := false) -> void:
	var tier_h := height / tiers
	for i in tiers:
		var y0 := base_y + i * tier_h
		var r_tier := radius * (1.0 - float(i) / (tiers + 0.6))
		var thick := tier_h * (0.5 if gap else 1.25)
		for y in range(int(y0), int(y0 + thick)):
			var t := (y - y0) / thick
			var r := r_tier * (1.0 - t * 0.85)
			for x in range(int(_center.x - r) - 1, int(_center.x + r) + 2):
				for z in range(int(_center.z - r) - 1, int(_center.z + r) + 2):
					var d := Vector2(x + 0.5 - _center.x, z + 0.5 - _center.z)
					var star := 0.78 + 0.22 * sin(d.angle() * 7.0 + i * 1.3)
					if d.length() <= r * star:
						var tone: Color = tones[(x / 3 + y / 3 + z / 3) % 3]
						_put(Vector3i(x, y, z), tone, "leaf", false)
	# Punta.
	var top := base_y + height
	for y in range(int(top), int(top + 6)):
		_put(Vector3i(int(_center.x), y, int(_center.z)), tones[2], "leaf", false)


## Bayas: grupitos rojos sobre la superficie de las hojas.
func berries(chance: float) -> void:
	for p: Vector3i in cells.keys():
		if types[p] == "leaf" and not cells.has(p + Vector3i.UP) and rng.randf() < chance:
			for q in [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 1, 0)]:
				cells[p + q] = BERRY
				types[p + q] = "leaf"


## Las hojas en "cubos de hoja" de LEAF_CUBE cubitos (como en el concepto: la copa es un montón de
## cubitos de hojas). Cada cubo, de un solo tono: así sus caras se juntan y se dibujan muchas
## menos (con un tono por cubito, un bosque iba a 4 FPS). Luz pintada por cubos: los de arriba de
## la copa, más claros; los de debajo, más oscuros.
const LEAF_CUBE := 2


func shade() -> void:
	var cubes := {}  # cubo -> Color (el de su primer cubito)
	for p: Vector3i in cells:
		if types[p] == "leaf":
			var k := Vector3i(floori(p.x / float(LEAF_CUBE)), floori(p.y / float(LEAF_CUBE)), floori(p.z / float(LEAF_CUBE)))
			if not cubes.has(k) or cells[p] == BERRY:
				cubes[k] = cells[p]
	for k: Vector3i in cubes:
		var col: Color = cubes[k]
		if col != BERRY:
			if not cubes.has(k + Vector3i.UP):
				col = col.lightened(0.16)
			elif not cubes.has(k + Vector3i.DOWN):
				col = col.darkened(0.18)
		for x in LEAF_CUBE:
			for y in LEAF_CUBE:
				for z in LEAF_CUBE:
					var p := k * LEAF_CUBE + Vector3i(x, y, z)
					if p.y < 0 or (cells.has(p) and types[p] != "leaf"):
						continue  # la madera manda
					cells[p] = col
					types[p] = "leaf"


func _ball(center: Vector3, radius: float, put: Callable) -> void:
	var r := int(ceilf(radius))
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			for z in range(-r, r + 1):
				var d := Vector3(x, y, z)
				if d.length() <= radius:
					put.call(Vector3i((center + d).floor()), d)


func _ellipsoid(center: Vector3, size: Vector3, tone: Color) -> void:
	for x in range(-int(size.x), int(size.x) + 1):
		for y in range(-int(size.y), int(size.y) + 1):
			for z in range(-int(size.z), int(size.z) + 1):
				var q := Vector3(x / size.x, y / size.y, z / size.z)
				if q.length() <= 1.0:
					_put(Vector3i((center + Vector3(x, y, z)).floor()), tone, "leaf", false)


# ------------------------------------------------------------------ los árboles de la hoja

static func oak(seed_value: int) -> TreeBuilder:
	var b := TreeBuilder.new(seed_value)
	var h := b.rng.randi_range(26, 34)
	var top := b.trunk(h, 7.0, 4.5, Vector3.ZERO, BARK)
	b.roots(5, 13, 4.0, 7.0, BARK)
	for k in 3:  # ramas hacia la copa
		var a := TAU * k / 3.0 + b.rng.randf()
		b.branch(top + Vector3(0, -6, 0), top + Vector3(cos(a) * 14, 12, sin(a) * 14), 3.0, 2.0, BARK)
	b.canopy(top + Vector3(0, 18, 0), Vector3(28, 20, 28), 26, LEAF)
	b.shade()
	return b


static func leaning_oak(seed_value: int) -> TreeBuilder:
	var b := TreeBuilder.new(seed_value)
	var a := b.rng.randf() * TAU
	var lean := Vector3(cos(a), 0, sin(a)) * 18.0
	var top := b.trunk(40, 7.0, 4.0, lean, BARK)
	b.roots(4, 12, 4.0, 7.0, BARK)
	b.branch(top + Vector3(0, -4, 0), top + lean.normalized() * -10 + Vector3(0, 12, 0), 2.5, 1.5, BARK)
	b.canopy(top + Vector3(0, 14, 0), Vector3(24, 17, 24), 20, LEAF)
	b.shade()
	return b


static func giant(seed_value: int) -> TreeBuilder:
	var b := TreeBuilder.new(seed_value)
	var top := b.trunk(44, 17.0, 11.0, Vector3.ZERO, BARK)
	b.roots(7, 24, 8.0, 17.0, BARK)
	var sides: Array[Vector3] = []
	for k in 2:  # dos grandes ramas a los lados
		var a := PI * k + b.rng.randf_range(-0.4, 0.4)
		var end := top + Vector3(cos(a) * 40, 4, sin(a) * 40)
		b.branch(top + Vector3(0, -14, 0), end, 7.0, 4.0, BARK)
		sides.append(end)
	b.canopy(top + Vector3(0, 22, 0), Vector3(46, 24, 46), 46, LEAF)
	for end in sides:
		b.canopy(end + Vector3(0, 10, 0), Vector3(18, 13, 18), 12, LEAF)
	b.shade()
	return b


static func pine(seed_value: int, small := false, tiered := false) -> TreeBuilder:
	var b := TreeBuilder.new(seed_value)
	var h := (46 if small else (86 if tiered else 80)) + b.rng.randi_range(-8, 8)
	b.trunk(h, 4.0 if small else 5.0, 1.5, Vector3.ZERO, BARK)
	b.roots(4, 8 if small else 11, 3.0, 4.0, BARK)
	var start := 8.0 if small else 14.0
	b.pine_cone(start, h - start - 2, (17.0 if small else 26.0) * b.rng.randf_range(0.85, 1.15), PINE, 4 if small else 6, tiered)
	b.shade()
	return b


static func dead(seed_value: int) -> TreeBuilder:
	var b := TreeBuilder.new(seed_value)
	var a := b.rng.randf() * TAU
	var top := b.trunk(48, 7.0, 3.0, Vector3(cos(a), 0, sin(a)) * 6, DEAD)
	b.roots(5, 14, 4.0, 7.0, DEAD)
	for k in 4:  # ramas secas que se abren y se parten en dos
		var ang := TAU * k / 4.0 + b.rng.randf_range(-0.4, 0.4)
		var from := top + Vector3(0, -12 - k * 5, 0)
		var mid := from + Vector3(cos(ang) * 12, 10, sin(ang) * 12)
		b.branch(from, mid, 2.5, 1.8, DEAD)
		for s in [-0.6, 0.6]:
			b.branch(mid, mid + Vector3(cos(ang + s) * 8, 8, sin(ang + s) * 8), 1.6, 1.0, DEAD)
	b.shade()
	return b


static func bush(seed_value: int, with_berries := false) -> TreeBuilder:
	var b := TreeBuilder.new(seed_value)
	b.trunk(4, 2.5, 2.0, Vector3.ZERO, BARK)
	var size := Vector3(24, 14, 24) if with_berries else Vector3(17, 13, 17)
	b.canopy(Vector3(RES * 0.5, size.y, RES * 0.5), size, 18 if with_berries else 12, LEAF)
	if with_berries:
		b.berries(0.035)
	b.shade()
	return b


## Tronco caído de adorno (el de la hoja 4 del concepto): tumbado, hueco por dentro, con anillos
## en las puntas y manchas de musgo por arriba.
static func fallen_log(seed_value: int) -> TreeBuilder:
	var b := TreeBuilder.new(seed_value)
	var length := b.rng.randi_range(36, 52)
	var r := b.rng.randf_range(5.5, 7.0)
	var along_z := b.rng.randf() < 0.5
	var moss := Color(0.36, 0.56, 0.16)
	for s in length:
		for u in range(-int(r) - 1, int(r) + 2):
			for v in range(-int(r) - 1, int(r) + 2):
				var d := Vector2(u + 0.5, v + 0.5)
				var dist := d.length()
				if dist > r or dist < r * 0.55:
					continue  # fuera, o el hueco de dentro
				var y := int(r) + v
				var p := Vector3i(int(b._center.x) - length / 2 + s, y, int(b._center.z) + u)
				if along_z:
					p = Vector3i(int(b._center.x) + u, y, int(b._center.z) - length / 2 + s)
				var col := b._bark(BARK, d.angle(), s)
				if s == 0 or s == length - 1:
					col = BARK[2].lightened(0.1) if int(dist * 1.5) % 2 == 0 else BARK[1]  # anillos
				elif v > r * 0.5 and (s * 7 + u * 3) % 11 < 4:
					col = moss.lightened(0.1 * ((s + u) % 2))  # musgo por arriba
				b._put(p, col, "wood")
	return b
