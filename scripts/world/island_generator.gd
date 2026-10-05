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
const ORE := 29          # mineral verde de las montañas (brilla un poco)
# Agua que corre (ver WaterFlow): cayendo, y de lado con nivel 1 (casi nada) a 7.
const WATER_FALL := 30
const WATER_FLOW_1 := 31   # ... hasta 37 (nivel 7)
# Orillas y fondos (hoja 2 del arte conceptual).
const WET_SAND := 38     # arena mojada: la franja junto al mar
const GRAVEL := 39       # grava: fondo de ríos y lagos
const CLAY := 40         # arcilla: manchas en el fondo de ríos y lagos
const MUD := 41          # barro: orillas de ríos y lagos
const STUMP := 42        # tocón de un árbol talado (rebrota con el tiempo, ver TreeRegrowth)
# Medios bloques de tablones (losas): abajo, arriba, y de pie pegados a un lado (N = -Z, S = +Z,
# O = -X, E = +X). Un solo objeto, "plank_slab": la forma depende de dónde se coloque.
const SLAB_DOWN := 43
const SLAB_UP := 44
const SLAB_N := 45
const SLAB_S := 46
const SLAB_W := 47
const SLAB_E := 48
const ROPE_HANGING := 49 # cuerda que cuelga (de un mástil, de un techo...)
const SAIL_X := 50       # vela o tela de pie: una lámina fina (X: de cara al eje X)
const SAIL_Z := 51
const CHEST_OPEN := 52   # cofre abierto mientras se mira dentro (la tapa la anima ChestVisual)
const GRASS_FLOWERS := 53 # hierba con florecitas (1 de cada 10 bloques de hierba: rompe el patrón)

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
			# Orillas y fondos: arena mojada junto al mar; en ríos y lagos, fondo de grava con
			# manchas de arcilla, y barro donde el agua toca la hierba.
			if top == SAND and height >= SEA_LEVEL and height <= SEA_LEVEL + 1:
				top = WET_SAND
			elif height > SEA_LEVEL and water_top > height:
				top = CLAY if _hash01(floori(wx / 4.0) * 3 + 1, floori(wz / 4.0) * 5 + 2) < 0.3 else GRAVEL
			elif height > SEA_LEVEL and water_top == height and (top == GRASS or top == DIRT):
				top = MUD
			if top == GRASS and _hash01(wx * 3 + 7, wz * 5 + 1) < 0.1:
				top = GRASS_FLOWERS  # de vez en cuando, con florecitas
			var sub_start := height - 1 - DIRT_DEPTH
			_fill_run(out_buffer, origin_in_voxels, size, x, z, STONE, origin_in_voxels.y, sub_start)
			_fill_run(out_buffer, origin_in_voxels, size, x, z, sub, sub_start, height - 1)
			_fill_run(out_buffer, origin_in_voxels, size, x, z, top, height - 1, height)
			_fill_run(out_buffer, origin_in_voxels, size, x, z, WATER, height, water_top)
			# Vetas de mineral verde en la roca de las montañas (algunas asoman a la superficie).
			if top == STONE and height > SEA_LEVEL + 16:
				var vein := _hash01(wx * 5 + 1, wz * 7 + 11)
				if vein < 0.03:
					var depth := int(vein * 1000.0) % 3
					for k in 2:
						var oy := height - 1 - depth - k - origin_in_voxels.y
						if oy >= 0 and oy < size.y:
							out_buffer.set_voxel(ORE, x, oy, z, VoxelBuffer.CHANNEL_TYPE)
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
			_stamp_column(out_buffer, origin_in_voxels, size, wx, wz)

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
			if h < 0.0068:
				return PrefabLibrary.index_of("t_log_1" if pick < 0.5 else "t_log_2")  # tronco caído (hueco)
		GRASS:
			if h < 0.0010:
				return _rocks[int(pick * _rocks.size()) % _rocks.size()]
			if h < 0.0035:
				return PrefabLibrary.index_of("t_bush_1" if pick < 0.5 else "t_bush_2")
			if h < 0.0045:
				return PrefabLibrary.index_of("stump_block")  # tocón viejo (no rebrota)
			if h < 0.0075:
				return PrefabLibrary.index_of("mushrooms_red" if pick < 0.5 else "mushrooms_tan")
			if h < 0.0085:
				return PrefabLibrary.index_of("t_berry_1" if pick < 0.5 else "t_berry_2")
			if h < 0.009:
				return PrefabLibrary.index_of("t_log_1" if pick < 0.5 else "t_log_2")  # tronco caído (hueco)
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


## Árboles de la hoja del concepto (prefabs de TreeBuilder): versiones de cada tipo.
const TREE_PREFABS := {
	"oak": ["t_oak_1", "t_oak_2", "t_oak_3"], "lean": ["t_lean_1", "t_lean_2"], "giant": ["t_giant_1"],
	"pine": ["t_pine_1", "t_pine_2"], "pine_small": ["t_pine_small_1", "t_pine_small_2"],
	"pine_tier": ["t_pine_tier_1", "t_pine_tier_2"], "dead": ["t_dead_1", "t_dead_2"],
	"bush": ["t_bush_1", "t_bush_2"], "berry": ["t_berry_1", "t_berry_2"],
}


## Qué árbol nace en esta columna (un prefab de TREE_PREFABS): cada sitio, siempre el mismo
## (así un tocón rebrota igual).
func _tree_prefab(wx: int, wz: int, kind: int) -> int:
	var r := _hash01(wx * 7 + 1, wz * 7 + 3)
	var r2 := _hash01(wx * 13 + 5, wz * 11 + 9)
	var group := "dead"
	match kind:
		1:
			if r < 0.1:
				group = "bush"
			elif r < 0.18:
				group = "berry"
			elif r < 0.6:
				group = "oak"
			elif r < 0.88:
				group = "lean"
			else:
				group = "giant"
		2:
			group = "pine_small" if r < 0.25 else ("pine_tier" if r < 0.45 else "pine")
	var names: Array = TREE_PREFABS[group]
	return PrefabLibrary.index_of(names[int(r2 * names.size()) % names.size()])


func _stamp_tree(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, wx: int, wz: int, base: int, kind: int) -> void:
	for piece in PrefabLibrary.pieces(_tree_prefab(wx, wz, kind)):
		var c: Vector3i = piece[0]
		_set_if_air(buffer, origin, size, wx + c.x, base + c.y, wz + c.z, piece[1])


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


# ------------------------------------------------------------------ corriente de los ríos

var _flow := PackedVector2Array()   # por píxel del mapa: hacia dónde corre el agua (y cuánto)


## Calcula la corriente de ríos y lagos (no del mar): el agua baja hacia donde su superficie
## está más baja. Se suaviza para que corra seguida entre escalón y escalón del río; en los
## lagos, planos, queda casi quieta. Devuelve una imagen (RG = dirección, B = fuerza) para el
## dibujo del agua.
func build_flow() -> Image:
	_flow.resize(_n * _n)
	_flow.fill(Vector2.ZERO)
	var wet := PackedInt32Array()
	var is_wet := PackedByteArray()
	is_wet.resize(_n * _n)
	for i in _n * _n:
		if _w[i] > SEA_LEVEL + 0.5 and _w[i] > _h[i] + 0.25:
			wet.append(i)
			is_wet[i] = 1
	for i in wet:
		var x := i % _n
		var z := i / _n
		var g := Vector2.ZERO
		if x > 0 and x < _n - 1:
			var l := _w[i - 1] if is_wet[i - 1] else _w[i]
			var r := _w[i + 1] if is_wet[i + 1] else _w[i]
			g.x = l - r
		if z > 0 and z < _n - 1:
			var u := _w[i - _n] if is_wet[i - _n] else _w[i]
			var d := _w[i + _n] if is_wet[i + _n] else _w[i]
			g.y = u - d
		_flow[i] = g
	# Suavizado: cada píxel mojado toma la media de sus vecinos mojados, varias veces.
	for pass_i in 10:
		var next := _flow.duplicate()
		for i in wet:
			var sum := _flow[i]
			var count := 1
			for o in [-1, 1, -_n, _n]:
				var j: int = i + o
				if j >= 0 and j < _n * _n and is_wet[j]:
					sum += _flow[j]
					count += 1
			next[i] = sum / count
		_flow = next
	var img := Image.create(_n, _n, false, Image.FORMAT_RGB8)
	img.fill(Color(0.5, 0.5, 0.0))
	for i in wet:
		var v := _flow[i]
		var strength := clampf(v.length() * 6.0, 0.0, 1.0)
		var dir := v.normalized() if v.length() > 0.0001 else Vector2.ZERO
		_flow[i] = dir * strength
		img.set_pixel(i % _n, i / _n, Color(dir.x * 0.5 + 0.5, dir.y * 0.5 + 0.5, strength))
	return img


## Corriente del agua en esta columna (dirección x/z por fuerza 0..1); cero fuera de ríos.
func water_current(wx: int, wz: int) -> Vector2:
	var i := _index(wx, wz)
	if i < 0 or _flow.is_empty():
		return Vector2.ZERO
	return _flow[i]


## Lado del mapa en píxeles y voxels por píxel (para dibujar la corriente).
func map_pixels() -> int:
	return _n


# ------------------------------------------------------------------ árbol (o prefab) de una columna

## Planta lo que nace en la columna (wx, wz): un árbol nuestro, uno de Kenney o un prefab (palmera,
## roca...). 'base' es la altura del pie (por defecto, el suelo del mapa).
func _stamp_column(buffer: VoxelBuffer, origin: Vector3i, size: Vector3i, wx: int, wz: int, base := -1) -> void:
	var kind := _tree_kind(wx, wz)
	if kind == 0:
		var prefab := _prefab_at(wx, wz)
		if prefab >= 0:
			var pbase := _height_at(wx, wz) if base < 0 else base
			if pbase + MAX_TREE_HEIGHT >= origin.y and pbase <= origin.y + size.y:
				for piece in PrefabLibrary.pieces(prefab):
					var pc: Vector3i = piece[0]
					_set_if_air(buffer, origin, size, wx + pc.x, pbase + pc.y, wz + pc.z, piece[1])
		return
	if base < 0:
		base = _height_at(wx, wz)
	if base + MAX_TREE_HEIGHT < origin.y or base > origin.y + size.y:
		return  # el árbol no toca este bloque
	_stamp_tree(buffer, origin, size, wx, wz, base, kind)


## ¿Nace un árbol (o una palmera) en esta columna? (para saber si un tocón puede rebrotar)
func has_tree(wx: int, wz: int) -> bool:
	if _tree_kind(wx, wz) != 0:
		return true
	var prefab := _prefab_at(wx, wz)
	return prefab >= 0 and String(PrefabLibrary.NAMES[prefab]).begins_with("palm")


## Vuelve a crecer el árbol de la columna del tocón 'cell' (el tocón pasa a ser su pie). Solo
## ocupa huecos: lo que haya construido el jugador alrededor se respeta.
func regrow(tool: VoxelTool, cell: Vector3i) -> void:
	var r := _margin + 1
	var origin := cell - Vector3i(r, 0, r)
	var buffer := VoxelBuffer.new()
	buffer.create(2 * r + 1, MAX_TREE_HEIGHT + 4, 2 * r + 1)
	tool.copy(origin, buffer, 1 << VoxelBuffer.CHANNEL_TYPE)
	buffer.set_voxel(AIR, r, 0, r, VoxelBuffer.CHANNEL_TYPE)  # quitar el tocón
	_stamp_column(buffer, origin, buffer.get_size(), cell.x, cell.z, cell.y)
	tool.paste(origin, buffer, 1 << VoxelBuffer.CHANNEL_TYPE)
