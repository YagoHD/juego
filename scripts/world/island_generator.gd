extends VoxelGeneratorScript
class_name IslandGenerator
## Genera la isla a partir de los mapas horneados por tools/island_baker:
##   height.png  -> altura del suelo (16 bits)
##   water.png   -> nivel de ríos/lagos (16 bits, 0 = sin agua)
##   surface.png -> bloque de superficie (R), de subsuelo (G) y árbol (B)
## Todas las decisiones caras (bioma, pendiente, nieve, densidad de árboles) ya vienen hechas
## en los mapas: aquí solo se consultan, para que la isla se genere rápido.
## Coordenadas de voxel centradas en (0,0).

# IDs de bloque (el índice debe coincidir con la librería en main.gd y con IslandBaker.cs).
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const SNOW := 5
const WOOD := 6
const LEAVES := 7
const WATER := 8
const PINE_LEAVES := 9
const CORRUPT_SOIL := 10
const DEAD_WOOD := 11
const WHEAT := 12
const CHEST := 13
const PLANKS := 14
const CLOTH := 15
const MOSSY_STONE := 16
const DRIFTWOOD := 17
const WORKBENCH := 18
const LOG_X := 19        # tronco tumbado a lo largo de X (árbol talado)
const LOG_Z := 20        # tronco tumbado a lo largo de Z
const DEAD_LOG_X := 21
const DEAD_LOG_Z := 22
# Decoración pequeña (no cubos, sin choque): se recoge con la mano.
const TALL_GRASS := 23
const FLOWER_RED := 24
const FLOWER_YELLOW := 25
const PEBBLES := 26
const GROUND_STICKS := 27
const SHELL := 28

const MAP_DIR := "res://assets/island/"
const MAP_HALF := 512.0       # los mapas cubren [-MAP_HALF, MAP_HALF] voxels en X y Z (la isla a la mitad
                              # de ancho que el horneado original; las alturas, iguales)
const OCEAN_FLOOR := 4.0
const SEA_LEVEL := 24         # coincide con el plano de mar en main.gd y con el horneador
const DIRT_DEPTH := 3
const TREE_MARGIN := 5        # columnas extra alrededor del chunk para no cortar copas
const MAX_TREE_HEIGHT := 20
const MAX_TREE_DENSITY := 0.063  # la densidad del mapa va en milésimas (máx. 63)

var _n := 0
var _h := PackedFloat32Array()
var _w := PackedFloat32Array()
var _surface := PackedByteArray()  # RGB por píxel: superficie, subsuelo, árbol
var _voxels_per_px := 2.0
var _hasher := HashingContext.new()
var _fingerprint := ""


var _margin := TREE_MARGIN     # columnas de margen: lo que más se aleja un árbol o un prefab de su pie
var _palms: Array[int] = []
var _rocks: Array[int] = []


func _init() -> void:
	PrefabLibrary.load_all()  # palmeras, rocas... (en el hilo principal, antes de generar)
	_margin = maxi(TREE_MARGIN, PrefabLibrary.reach() + 1)
	for n in ["palm_tall", "palm_bend", "palm_short"]:
		_palms.append(PrefabLibrary.index_of(n))
	for n in ["rock_a", "rock_d", "rock_tall"]:
		_rocks.append(PrefabLibrary.index_of(n))
	_hasher.start(HashingContext.HASH_MD5)
	_h = _load_16bit(MAP_DIR + "height.png")
	_w = _load_16bit(MAP_DIR + "water.png")
	var surface_img := _load_image(MAP_DIR + "surface.png")
	if surface_img != null:
		_surface = surface_img.get_data()
		_hasher_update(_surface)
	_fingerprint = _hasher.finish().hex_encode()
	# Las estructuras se colocan con las alturas de los mapas, así que van después de cargarlos.
	if _n > 1:
		_voxels_per_px = 2.0 * MAP_HALF / float(_n - 1)
	Structures.build(self)


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


# ------------------------------------------------------------------ carga de mapas

func _load_image(path: String) -> Image:
	# Los mapas se importan como "Image" (sin compresión, ver sus .import): así se leen
	# igual en el editor que en el juego exportado, con los valores exactos.
	var img := load(path) as Image
	if img == null:
		push_error("No se pudo cargar el mapa: " + path)
		return null
	img = img.duplicate() as Image  # el recurso importado es compartido: no lo modificamos
	img.convert(Image.FORMAT_RGB8)
	if _n == 0:
		_n = img.get_width()
	return img


func _load_16bit(path: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var img := _load_image(path)
	if img == null:
		return out
	var data := img.get_data()
	_hasher_update(data)
	var count := img.get_width() * img.get_height()
	out.resize(count)
	for i in count:
		out[i] = float(data[i * 3] * 256 + data[i * 3 + 1]) / 64.0
	return out


# ------------------------------------------------------------------ muestreo

func _to_px(w: int) -> float:
	return (float(w) + MAP_HALF) / _voxels_per_px


func _index(wx: int, wz: int) -> int:
	# Índice del píxel más cercano, o -1 si está fuera del mapa.
	var px := int(roundf(_to_px(wx)))
	var pz := int(roundf(_to_px(wz)))
	if px < 0 or pz < 0 or px >= _n or pz >= _n:
		return -1
	return pz * _n + px


func _height_at(wx: int, wz: int) -> int:
	if _h.is_empty():
		return int(OCEAN_FLOOR)
	var fx := _to_px(wx)
	var fz := _to_px(wz)
	if fx < 0.0 or fz < 0.0 or fx > float(_n - 1) or fz > float(_n - 1):
		return int(OCEAN_FLOOR)
	var x0 := floori(fx)
	var z0 := floori(fz)
	var x1 := mini(x0 + 1, _n - 1)
	var z1 := mini(z0 + 1, _n - 1)
	var tx := fx - x0
	var tz := fz - z0
	var a := lerpf(_h[z0 * _n + x0], _h[z0 * _n + x1], tx)
	var b := lerpf(_h[z1 * _n + x0], _h[z1 * _n + x1], tx)
	return int(roundf(lerpf(a, b, tz)))


func _chunk_height_range(origin: Vector3i, size: Vector3i) -> Vector2i:
	# Altura mínima del suelo y máxima (suelo o agua) bajo el bloque, leyendo el mapa en bruto.
	# Incluye el margen de los árboles vecinos. Mucho más barato que muestrear cada columna.
	var p0x := floori(_to_px(origin.x - _margin)) - 1
	var p1x := ceili(_to_px(origin.x + size.x + _margin)) + 1
	var p0z := floori(_to_px(origin.z - _margin)) - 1
	var p1z := ceili(_to_px(origin.z + size.z + _margin)) + 1
	var lo := INF
	var hi := -INF
	if _h.is_empty() or p0x < 0 or p0z < 0 or p1x >= _n or p1z >= _n:
		lo = OCEAN_FLOOR  # toca el borde del mapa: allí es fondo marino
		hi = OCEAN_FLOOR
	for pz in range(maxi(p0z, 0), mini(p1z, _n - 1) + 1):
		for px in range(maxi(p0x, 0), mini(p1x, _n - 1) + 1):
			var i := pz * _n + px
			lo = minf(lo, _h[i])
			hi = maxf(hi, maxf(_h[i], _w[i]))
	return Vector2i(floori(lo), ceili(hi))


# ------------------------------------------------------------------ generación

func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	if lod != 0:
		return
	var size: Vector3i = out_buffer.get_size()

	# --- 1. Salidas rápidas: la mayoría de bloques son aire puro o roca maciza.
	var span := _chunk_height_range(origin_in_voxels, size)
	if origin_in_voxels.y > span.y + MAX_TREE_HEIGHT + 4:
		Structures.stamp(out_buffer, origin_in_voxels)  # el mástil del naufragio puede caer aquí
		return  # todo aire (el buffer ya viene vacío)
	if origin_in_voxels.y + size.y <= span.x - DIRT_DEPTH - 2:
		out_buffer.fill(STONE, VoxelBuffer.CHANNEL_TYPE)  # todo roca, de una vez
		Structures.stamp(out_buffer, origin_in_voxels)
		return

	var decor: Array[Vector4i] = []  # (x, y local, z, id): se pone al final, donde quede aire
	# --- 2. Terreno y agua: cada columna se rellena por tramos, no voxel a voxel.
	for x in size.x:
		for z in size.z:
			var wx: int = origin_in_voxels.x + x
			var wz: int = origin_in_voxels.z + z
			var height := _height_at(wx, wz)
			var i := _index(wx, wz)
			var top := SAND
			var sub := SAND
			var water_top := 0
			if i >= 0:
				top = _surface[i * 3]
				sub = _surface[i * 3 + 1]
				water_top = int(roundf(_w[i]))
			var sub_start := height - 1 - DIRT_DEPTH
			_fill_run(out_buffer, origin_in_voxels, size, x, z, STONE, origin_in_voxels.y, sub_start)
			_fill_run(out_buffer, origin_in_voxels, size, x, z, sub, sub_start, height - 1)
			_fill_run(out_buffer, origin_in_voxels, size, x, z, top, height - 1, height)
			_fill_run(out_buffer, origin_in_voxels, size, x, z, WATER, height, water_top)
			if water_top <= height and height > SEA_LEVEL:
				var d := _decor_at(wx, wz, top)
				var ly := height - origin_in_voxels.y
				if d != AIR and ly >= 0 and ly < size.y:
					decor.append(Vector4i(x, ly, z, d))

	# --- 3. Árboles (con margen para no cortar copas entre chunks).
	for lx in range(-_margin, size.x + _margin):
		for lz in range(-_margin, size.z + _margin):
			var wx: int = origin_in_voxels.x + lx
			var wz: int = origin_in_voxels.z + lz
			var kind := _tree_kind(wx, wz)
			if kind == 0:
				var prefab := _prefab_at(wx, wz)
				if prefab >= 0:
					var pbase := _height_at(wx, wz)
					if pbase + MAX_TREE_HEIGHT >= origin_in_voxels.y and pbase <= origin_in_voxels.y + size.y:
						for piece in PrefabLibrary.pieces(prefab):
							var pc: Vector3i = piece[0]
							_set_if_air(out_buffer, origin_in_voxels, size, wx + pc.x, pbase + pc.y, wz + pc.z, piece[1])
				continue
			var base := _height_at(wx, wz)
			if base + MAX_TREE_HEIGHT < origin_in_voxels.y or base > origin_in_voxels.y + size.y:
				continue  # el árbol no toca este bloque
			_stamp_tree(out_buffer, origin_in_voxels, size, wx, wz, base, kind)

	# --- 3b. Decoración del suelo (después de los árboles, para no ocupar el pie de un tronco).
	for d in decor:
		if out_buffer.get_voxel(d.x, d.y, d.z, VoxelBuffer.CHANNEL_TYPE) == AIR:
			out_buffer.set_voxel(d.w, d.x, d.y, d.z, VoxelBuffer.CHANNEL_TYPE)

	# --- 4. Estructuras fabricadas a mano (el naufragio...), por encima de todo lo anterior.
	Structures.stamp(out_buffer, origin_in_voxels)


func _fill_run(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, x: int, z: int, id: int, from_y: int, to_y: int) -> void:
	# Rellena la columna (x, z) con 'id' entre las alturas [from_y, to_y) del mundo.
	if id == AIR:
		return
	var a := maxi(from_y - origin.y, 0)
	var b := mini(to_y - origin.y, size.y)
	if b > a:
		buffer.fill_area(id, Vector3i(x, a, z), Vector3i(x + 1, b, z + 1), VoxelBuffer.CHANNEL_TYPE)


## Prefab (palmera, roca, arbusto...) que nace en esta columna, o -1. Las palmeras, en la arena
## junto al mar; las rocas grandes, arbustos, tocones y setas, en la hierba y la montaña.
func _prefab_at(wx: int, wz: int) -> int:
	var h := _hash01(wx * 29 + 3, wz * 31 + 17)
	if h > 0.009:
		return -1  # descarte barato
	if Vector2(wx, wz).distance_to(Vector2(Structures.spawn_voxel())) < 12.0:
		return -1  # el sitio donde aparece el jugador, despejado
	var i := _index(wx, wz)
	if i < 0:
		return -1
	var top: int = _surface[i * 3]
	var height := _height_at(wx, wz)
	if height <= SEA_LEVEL or _w[i] > height:
		return -1  # bajo el agua
	var pick := _hash01(wx * 7 - 5, wz * 13 + 1)
	match top:
		SAND:
			if h < 0.006 and height <= SEA_LEVEL + 6:
				return _palms[int(pick * _palms.size()) % _palms.size()]
		GRASS:
			if h < 0.0010:
				return _rocks[int(pick * _rocks.size()) % _rocks.size()]
			if h < 0.0035:
				return PrefabLibrary.index_of("bush")
			if h < 0.0045:
				return PrefabLibrary.index_of("stump")
			if h < 0.0075:
				return PrefabLibrary.index_of("mushrooms_red" if pick < 0.5 else "mushrooms_tan")
		STONE, MOSSY_STONE, DIRT:
			if h < 0.004:
				return _rocks[int(pick * _rocks.size()) % _rocks.size()]
	return -1


## Qué cosa pequeña hay en el suelo de esta columna (AIR si nada), según el suelo.
func _decor_at(wx: int, wz: int, top: int) -> int:
	var h := _hash01(wx * 3 + 11, wz * 5 + 7)
	if h > 0.14:
		return AIR  # descarte barato: casi todas las columnas están vacías
	if _tree_kind(wx, wz) != 0:
		return AIR  # aquí nace un árbol
	match top:
		GRASS:
			if h < 0.10: return TALL_GRASS
			if h < 0.112: return FLOWER_RED
			if h < 0.124: return FLOWER_YELLOW
			if h < 0.13: return PEBBLES
			if h < 0.137: return GROUND_STICKS
		SAND:
			if h < 0.012: return SHELL
			if h < 0.018: return PEBBLES
			if h < 0.023: return GROUND_STICKS
		STONE, MOSSY_STONE, DIRT:
			if h < 0.03: return PEBBLES
			if h < 0.034: return GROUND_STICKS
	return AIR


# Tipos de árbol: 0 ninguno, 1 frondoso, 2 pino, 3 muerto.
func _tree_kind(wx: int, wz: int) -> int:
	var roll := _hash01(wx, wz)
	if roll >= MAX_TREE_DENSITY:
		return 0  # descarte barato antes de mirar el mapa
	var i := _index(wx, wz)
	if i < 0:
		return 0
	var code: int = _surface[i * 3 + 2]
	if roll >= float(code & 63) / 1000.0:
		return 0
	return code >> 6


func _stamp_tree(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, wx: int, wz: int, base: int, kind: int) -> void:
	# Cada árbol sale distinto: tres números al azar (fijos para esa posición) eligen variante,
	# altura, inclinación y forma de la copa. Nada pasa de TREE_MARGIN columnas del tronco.
	var r := _hash01(wx * 7 + 1, wz * 7 + 3)
	var r2 := _hash01(wx * 13 + 5, wz * 11 + 9)
	var r3 := _hash01(wx * 17 + 2, wz * 19 + 7)
	var b := [buffer, origin, size]
	match kind:
		1:
			if r < 0.16:
				_bush(b, wx, wz, base, r2)
			elif r < 0.55:
				_oak(b, wx, wz, base, r2, r3)
			elif r < 0.82:
				_leaning_oak(b, wx, wz, base, r2, r3)
			else:
				_giant(b, wx, wz, base, r2, r3)
		2:
			_pine(b, wx, wz, base, r, r2, r3)
		3:
			_dead_tree(b, wx, wz, base, r2, r3)


# ------------------------------------------------------------------ formas de árbol
# "b" es [buffer, origin, size] para no repetir tres parámetros en cada llamada.

func _put(b: Array, x: int, y: int, z: int, id: int) -> void:
	_set_if_air(b[0], b[1], b[2], x, y, z, id)


## Bola de hojas con el borde irregular (cada celda del borde entra o no según su azar).
func _blob(b: Array, cx: float, cy: float, cz: float, radius: float, id: int) -> void:
	var reach := int(ceilf(radius))
	var x0 := int(floorf(cx))
	var y0 := int(floorf(cy))
	var z0 := int(floorf(cz))
	# Solo la parte de la bola que cae dentro de este trozo de mundo (lo demás lo pinta el trozo
	# vecino): así cada copa cuesta poco aunque se mire desde varios trozos.
	var origin: Vector3i = b[1]
	var size: Vector3i = b[2]
	var xa := maxi(x0 - reach, origin.x)
	var xb := mini(x0 + reach + 1, origin.x + size.x - 1)
	var ya := maxi(y0 - reach, origin.y)
	var yb := mini(y0 + reach + 1, origin.y + size.y - 1)
	var za := maxi(z0 - reach, origin.z)
	var zb := mini(z0 + reach + 1, origin.z + size.z - 1)
	for x in range(xa, xb + 1):
		for y in range(ya, yb + 1):
			for z in range(za, zb + 1):
				var d2 := (x + 0.5 - cx) * (x + 0.5 - cx) + (y + 0.5 - cy) * (y + 0.5 - cy) * 1.3 + (z + 0.5 - cz) * (z + 0.5 - cz)
				if d2 > radius * radius * 1.1:
					continue  # lejos del borde: fuera seguro, sin calcular el azar
				var edge := 0.6 + 0.5 * _hash01(x * 31 + y * 7, z * 17 - y * 3)
				if d2 <= radius * radius * edge:
					_put(b, x, y, z, id)


## Tronco vertical de una columna.
func _trunk(b: Array, x: int, z: int, from_y: int, height: int, id: int) -> void:
	for i in height:
		_put(b, x, from_y + i, z, id)


func _bush(b: Array, wx: int, wz: int, base: int, r2: float) -> void:
	# Arbusto: casi sin tronco, una mata de hojas pegada al suelo.
	_put(b, wx, base, wz, WOOD)
	_blob(b, wx + 0.5, base + 1.2, wz + 0.5, 1.4 + r2 * 0.6, LEAVES)


func _oak(b: Array, wx: int, wz: int, base: int, r2: float, r3: float) -> void:
	# Roble: tronco de 4-6, copa principal y una o dos bolas de lado; a veces una rama.
	var h := 4 + int(r2 * 3.0)
	_trunk(b, wx, wz, base, h, WOOD)
	var top := base + h
	_blob(b, wx + 0.5, top + 0.3, wz + 0.5, 2.2 + r3 * 0.9, LEAVES)
	var sides := 1 + int(r3 * 2.0)
	for k in sides:
		var a := TAU * _hash01(wx + k * 5, wz - k * 3)
		var ox := cos(a) * 1.8
		var oz := sin(a) * 1.8
		_blob(b, wx + 0.5 + ox, top - 0.8, wz + 0.5 + oz, 1.5 + r2 * 0.5, LEAVES)
	if r3 > 0.6:  # rama que sale del tronco hacia una de las bolas
		var dx := 1 if r2 > 0.5 else -1
		_put(b, wx + dx, top - 2, wz, WOOD)


func _leaning_oak(b: Array, wx: int, wz: int, base: int, r2: float, r3: float) -> void:
	# Alto e inclinado: el tronco se desplaza una columna a media altura (y a veces dos).
	var h := 6 + int(r2 * 3.0)
	var leans: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var lean: Vector2i = leans[int(r3 * 4.0) % 4]
	var x := wx
	var z := wz
	for i in h:
		if i == h / 2 or (i == h - 2 and r2 > 0.6):
			x += lean.x
			z += lean.y
			_put(b, x, base + i - 1, z, WOOD)  # el codo, para que el tronco no quede suelto
		_put(b, x, base + i, z, WOOD)
	var top := base + h
	_blob(b, x + 0.5, top + 0.2, z + 0.5, 2.4 + r3 * 0.7, LEAVES)
	_blob(b, x + 0.5 - lean.x * 1.5, top - 1.0, z + 0.5 - lean.y * 1.5, 1.6, LEAVES)


func _giant(b: Array, wx: int, wz: int, base: int, r2: float, r3: float) -> void:
	# Gigante: tronco de 2x2, raíces que asoman, ramas en diagonal y una copa de varias bolas.
	var h := 8 + int(r2 * 4.0)
	for ox in 2:
		for oz in 2:
			_trunk(b, wx + ox, wz + oz, base, h, WOOD)
	for k in 4:  # raíces
		if _hash01(wx + k, wz * 3 + k) > 0.45:
			var d := [Vector2i(-1, 0), Vector2i(2, 1), Vector2i(1, -1), Vector2i(0, 2)][k] as Vector2i
			_put(b, wx + d.x, base, wz + d.y, WOOD)
	var cx := wx + 1.0
	var cz := wz + 1.0
	var top := base + h
	_blob(b, cx, top + 0.5, cz, 3.0 + r3 * 0.4, LEAVES)
	var branches := 2 + int(r3 * 2.0)
	for k in branches:
		var a := TAU * (float(k) / branches + r2)
		var dir := Vector2(cos(a), sin(a))
		var start := top - 3 - (k % 2)
		var end := Vector2(cx, cz)
		for s in range(1, 4):  # la rama sube en diagonal
			end = Vector2(cx, cz) + dir * (0.8 + s * 0.8)
			_put(b, int(floorf(end.x)), start + s, int(floorf(end.y)), WOOD)
		_blob(b, end.x, start + 3.6, end.y, 2.0 + r2 * 0.6, LEAVES)


func _pine(b: Array, wx: int, wz: int, base: int, r: float, r2: float, r3: float) -> void:
	# Pino: de 5 a 12 de alto; copa cónica, ancha o estrecha; a veces por pisos con huecos.
	var small := r < 0.2
	var h := (4 + int(r2 * 2.0)) if small else (7 + int(r2 * 6.0))
	var max_radius := 2 if small or r3 < 0.4 else 3
	var tiered := r3 > 0.65
	_trunk(b, wx, wz, base, h, WOOD)
	var top := base + h + 1
	var start := base + 2 + int(r3 * 2.0)
	for y in range(start, top + 1):
		if tiered and (top - y) % 3 == 2 and y < top - 1:
			continue  # hueco entre pisos
		var radius := mini(int(roundf(float(top - y) * (0.34 + r2 * 0.12))), max_radius)
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var d2 := dx * dx + dz * dz
				if d2 <= radius * radius + 1 and (d2 < radius * radius or _hash01(wx + dx * 7 + y, wz + dz * 5) > 0.3):
					_put(b, wx + dx, y, wz + dz, PINE_LEAVES)
	_put(b, wx, top + 1, wz, PINE_LEAVES)  # la punta


func _dead_tree(b: Array, wx: int, wz: int, base: int, r2: float, r3: float) -> void:
	# Árbol muerto: tronco seco de 3 a 8, de 0 a 3 ramas al azar; a veces la punta rota.
	var h := 3 + int(r2 * 6.0)
	_trunk(b, wx, wz, base, h, DEAD_WOOD)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var branches := int(r3 * 4.0)
	for k in branches:
		var d: Vector2i = dirs[(k + int(r2 * 4.0)) % 4]
		var y := base + 2 + int(_hash01(wx + k, wz - k) * maxf(h - 3, 1))
		_put(b, wx + d.x, y, wz + d.y, DEAD_WOOD)
		if _hash01(wx - k, wz + k * 7) > 0.5:
			_put(b, wx + d.x * 2, y + 1, wz + d.y * 2, DEAD_WOOD)


func _set_if_air(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, wx: int, wy: int, wz: int, id: int) -> void:
	var lx: int = wx - origin.x
	var ly: int = wy - origin.y
	var lz: int = wz - origin.z
	if lx < 0 or ly < 0 or lz < 0 or lx >= size.x or ly >= size.y or lz >= size.z:
		return
	if buffer.get_voxel(lx, ly, lz, VoxelBuffer.CHANNEL_TYPE) == AIR:
		buffer.set_voxel(id, lx, ly, lz, VoxelBuffer.CHANNEL_TYPE)


func _hash01(x: int, z: int) -> float:
	var h: int = (x * 73856093) ^ (z * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0x7fffffff) / float(0x7fffffff)


func _hasher_update(data: PackedByteArray) -> void:
	_hasher.update(data)


## Huella (MD5) de los datos de los mapas tal como los carga el juego. Si cambia, el mundo
## guardado ya no corresponde a la isla actual.
func get_maps_fingerprint() -> String:
	return _fingerprint


## Acceso de solo lectura a los mapas (lo usa la malla lejana, FarTerrain).
func get_map_size() -> int:
	return _n

func get_voxels_per_px() -> float:
	return _voxels_per_px

func get_height_map() -> PackedFloat32Array:
	return _h

func get_water_map() -> PackedFloat32Array:
	return _w

func get_surface_map() -> PackedByteArray:
	return _surface


## Altura del suelo en coordenadas de voxel (para colocar al jugador al aparecer).
func get_ground_height(wx: int, wz: int) -> int:
	var i := _index(wx, wz)
	var water_top := int(roundf(_w[i])) if i >= 0 else 0
	return maxi(_height_at(wx, wz), water_top)
